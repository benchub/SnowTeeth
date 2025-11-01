package com.snowteeth.app.service

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.*
import com.snowteeth.app.MainActivity
import com.snowteeth.app.model.LocationData
import com.snowteeth.app.model.VelocityBucket
import com.snowteeth.app.model.VisualizationStyle
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.util.DebugLog
import com.snowteeth.app.util.GpxWriter
import com.snowteeth.app.util.VelocityCalculator
import com.snowteeth.app.util.VelocitySmoother
import com.snowteeth.app.util.VelocitySmootherConfig
import com.snowteeth.app.util.ElevationSmoother
import com.snowteeth.app.util.ElevationSmootherConfig

class LocationTrackingService : Service() {

    companion object {
        private const val TAG = "LocationTrackingService"
        const val CHANNEL_ID = "LocationTrackingChannel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val EXTRA_RESET_DATA = "reset_data"

        private const val LOCATION_UPDATE_INTERVAL = 1000L // Request updates every 1 second
        private const val GPX_WRITE_INTERVAL = 1 // Write every location update received

        const val LOCATION_UPDATE_ACTION = "com.snowteeth.app.LOCATION_UPDATE"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
        const val EXTRA_ALTITUDE = "altitude"
        const val EXTRA_SPEED = "speed"
        const val EXTRA_TIMESTAMP = "timestamp"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var locationManager: LocationManager
    private lateinit var gpxWriter: GpxWriter
    private lateinit var prefs: AppPreferences
    private lateinit var velocitySmoother: VelocitySmoother
    private lateinit var elevationSmoother: ElevationSmoother
    private lateinit var velocityCalculator: VelocityCalculator

    private var locationUpdateCount = 0
    private var lastLocation: Location? = null
    private var previousLocation: Location? = null
    private var isCurrentlyTracking = false
    private var heartbeatRunnable: Runnable? = null
    private val handler = android.os.Handler(Looper.getMainLooper())
    private var lastLocationUnavailableWarning: Long = 0
    private var smoothedVelocityMPS: Float = 0f
    private var satelliteCount: Int = 0
    private var gnssStatusCallback: GnssStatus.Callback? = null
    private var gpsLocationListener: android.location.LocationListener? = null

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        gpxWriter = GpxWriter(this)
        prefs = AppPreferences(this)
        velocitySmoother = VelocitySmoother(VelocitySmootherConfig.skiing(prefs.useMetric))
        // Elevation smoother uses adaptive smoothing: conservative for noise, responsive for trends
        elevationSmoother = ElevationSmoother(ElevationSmootherConfig.standard())
        velocityCalculator = VelocityCalculator(prefs)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    handleLocationUpdate(location)
                } ?: run {
                    Log.w(TAG, "onLocationResult called but lastLocation is null")
                }
            }

            override fun onLocationAvailability(availability: LocationAvailability) {
                if (!availability.isLocationAvailable) {
                    // Throttle warning to once every 60 seconds to avoid log spam
                    val now = System.currentTimeMillis()
                    if (now - lastLocationUnavailableWarning > 60000) {
                        Log.w(TAG, "Location is not available (GPS signal may be weak or disabled)")
                        lastLocationUnavailableWarning = now
                    }
                }
            }
        }

        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_TRACKING -> {
                val resetData = intent.getBooleanExtra(EXTRA_RESET_DATA, true)
                startTracking(resetData)
            }
            ACTION_STOP_TRACKING -> {
                stopTracking()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startTracking(resetData: Boolean = true) {
        DebugLog.i(TAG, "📍 Starting GPS tracking service")

        if (isCurrentlyTracking) {
            DebugLog.w(TAG, "Already tracking, ignoring start request")
            return
        }

        // Check Google Play Services availability
        val googleApiAvailability = GoogleApiAvailability.getInstance()
        val resultCode = googleApiAvailability.isGooglePlayServicesAvailable(this)
        if (resultCode != ConnectionResult.SUCCESS) {
            Log.e(TAG, "Google Play Services not available! Error: ${googleApiAvailability.getErrorString(resultCode)}")
            if (googleApiAvailability.isUserResolvableError(resultCode)) {
                Log.e(TAG, "This is a user-resolvable error")
            }
            stopSelf()
            return
        }

        // Check if location is enabled at system level
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        if (!isGpsEnabled && !isNetworkEnabled) {
            Log.e(TAG, "No location providers are enabled!")
        }

        // Check permissions explicitly
        val hasFineLocation = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val hasCoarseLocation = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasFineLocation && !hasCoarseLocation) {
            Log.e(TAG, "No location permissions granted!")
            stopSelf()
            return
        }

        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        // Only reset the GPX file if requested
        if (resetData) {
            gpxWriter.startNewTrack()
            locationUpdateCount = 0
            lastLocation = null
        } else {
            // Continuing with existing data - ensure file exists
            if (!gpxWriter.hasTrack()) {
                gpxWriter.startNewTrack()
            }
        }

        // For ski tracking, use pure GPS_PROVIDER for unthrottled 1-second updates
        // Requires outdoor use with clear sky view, but gives true high-frequency GPS data
        try {
            // Try to get last known location immediately
            fusedLocationClient.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    handleLocationUpdate(location)
                }
            }

            // Check if GPS is available and enabled
            val isGpsAvailable = locationManager.allProviders.contains(LocationManager.GPS_PROVIDER)
            val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            DebugLog.i(TAG, "GPS Provider - Available: $isGpsAvailable, Enabled: $isGpsEnabled")

            if (!isGpsEnabled) {
                DebugLog.w(TAG, "⚠️ GPS is not enabled! Please enable location services for best results.")
            }

            // Set up pure GPS location listener
            gpsLocationListener = object : android.location.LocationListener {
                override fun onLocationChanged(location: Location) {
                    DebugLog.d(TAG, "🛰️ GPS onLocationChanged called (provider: ${location.provider})")
                    handleLocationUpdate(location)
                }
                override fun onProviderEnabled(provider: String) {
                    DebugLog.i(TAG, "✅ GPS provider enabled: $provider")
                }
                override fun onProviderDisabled(provider: String) {
                    DebugLog.w(TAG, "⚠️ GPS provider disabled: $provider")
                }
                @Deprecated("Deprecated in API 29")
                override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {
                    DebugLog.d(TAG, "GPS status changed: $provider, status: $status")
                }
            }

            // Request pure GPS updates - requires outdoor use but gives true 1-second resolution
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,  // Pure GPS (not FUSED)
                LOCATION_UPDATE_INTERVAL,      // minTimeMs: 1000ms
                0f,                             // minDistanceMeters: 0 (report all updates)
                gpsLocationListener!!,
                Looper.getMainLooper()
            )

            DebugLog.i(TAG, "✅ Pure GPS location updates requested (interval: ${LOCATION_UPDATE_INTERVAL}ms, minDistance: 0m)")
            isCurrentlyTracking = true
            gpxWriter.startNewTrack()
            // Reset velocity and elevation smoothers for new tracking session
            velocitySmoother.reset()
            velocitySmoother = VelocitySmoother(VelocitySmootherConfig.skiing(prefs.useMetric))
            elevationSmoother.reset()
            startVelocityLogging()
            startGnssStatusUpdates()
        } catch (e: SecurityException) {
            // Handle permission not granted
            Log.e(TAG, "Security exception requesting location updates", e)
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected exception requesting location updates", e)
            stopSelf()
        }
    }

    private fun stopTracking() {
        stopVelocityLogging()
        stopGnssStatusUpdates()

        // Remove GPS location listener
        gpsLocationListener?.let {
            try {
                locationManager.removeUpdates(it)
                gpsLocationListener = null
            } catch (e: Exception) {
                Log.e(TAG, "Error removing GPS location listener", e)
            }
        }

        gpxWriter.finalizeTrack()
        isCurrentlyTracking = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startVelocityLogging() {
        DebugLog.i(TAG, "🚀 Starting velocity logging (logs every 5 seconds)")
        heartbeatRunnable = object : Runnable {
            override fun run() {
                lastLocation?.let { location ->
                    val rawSpeedMPS = location.speed
                    val rawVelocityMPH = rawSpeedMPS * 2.23694f
                    val rawVelocityKPH = rawSpeedMPS * 3.6f

                    val smoothedSpeedMPS = smoothedVelocityMPS
                    val smoothedVelocityMPH = smoothedSpeedMPS * 2.23694f
                    val smoothedVelocityKPH = smoothedSpeedMPS * 3.6f

                    val useMetric = prefs.useMetric

                    // Calculate direction
                    val direction = if (previousLocation != null) {
                        val elevationChange = location.altitude - previousLocation!!.altitude
                        if (elevationChange < 0) "downhill" else "uphill"
                    } else {
                        "unknown"
                    }

                    // Calculate bucket percentage (where in the bucket range we are)
                    val bucketInfo = if (prefs.visualizationStyle == VisualizationStyle.FLAME && previousLocation != null) {
                        val currentLocationData = LocationData(
                            location.latitude, location.longitude, location.altitude,
                            location.time, smoothedVelocityMPS,
                            horizontalAccuracy = location.accuracy
                        )
                        val prevLocationData = LocationData(
                            previousLocation!!.latitude, previousLocation!!.longitude,
                            previousLocation!!.altitude, previousLocation!!.time, 0f,
                            horizontalAccuracy = previousLocation!!.accuracy
                        )

                        val bucket = velocityCalculator.calculateBucket(currentLocationData, prevLocationData)
                        val speedMph = smoothedVelocityMPS / 0.44704f

                        when (bucket) {
                            VelocityBucket.IDLE -> "IDLE (0%)"
                            VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY -> {
                                val lowerThreshold = if (direction == "downhill") prefs.downhillEasyThreshold else prefs.uphillEasyThreshold
                                val upperThreshold = if (direction == "downhill") prefs.downhillMediumThreshold else prefs.uphillMediumThreshold
                                val percentage = ((speedMph - lowerThreshold) / (upperThreshold - lowerThreshold) * 100f).coerceIn(0f, 100f)
                                String.format("EASY (%.0f%%)", percentage)
                            }
                            VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM -> {
                                val lowerThreshold = if (direction == "downhill") prefs.downhillMediumThreshold else prefs.uphillMediumThreshold
                                val upperThreshold = if (direction == "downhill") prefs.downhillHardThreshold else prefs.uphillHardThreshold
                                val percentage = ((speedMph - lowerThreshold) / (upperThreshold - lowerThreshold) * 100f).coerceIn(0f, 100f)
                                String.format("MEDIUM (%.0f%%)", percentage)
                            }
                            VelocityBucket.DOWNHILL_HARD, VelocityBucket.UPHILL_HARD -> "HARD (100%)"
                        }
                    } else {
                        "N/A"
                    }

                    if (useMetric) {
                        DebugLog.i(TAG, String.format("Velocity: raw=%.1f km/h, smoothed=%.1f km/h, direction=%s, bucket=%s", rawVelocityKPH, smoothedVelocityKPH, direction, bucketInfo))
                    } else {
                        DebugLog.i(TAG, String.format("Velocity: raw=%.1f mph, smoothed=%.1f mph, direction=%s, bucket=%s", rawVelocityMPH, smoothedVelocityMPH, direction, bucketInfo))
                    }
                }
                handler.postDelayed(this, 5000) // Log every 5 seconds
            }
        }
        handler.post(heartbeatRunnable!!)
    }

    private fun stopVelocityLogging() {
        heartbeatRunnable?.let {
            handler.removeCallbacks(it)
            heartbeatRunnable = null
        }
    }

    private fun startGnssStatusUpdates() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            gnssStatusCallback = object : GnssStatus.Callback() {
                override fun onSatelliteStatusChanged(status: GnssStatus) {
                    // Count satellites that are used in the fix
                    var usedSatellites = 0
                    for (i in 0 until status.satelliteCount) {
                        if (status.usedInFix(i)) {
                            usedSatellites++
                        }
                    }
                    satelliteCount = usedSatellites
                }
            }

            try {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    locationManager.registerGnssStatusCallback(gnssStatusCallback!!, handler)
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Security exception registering GNSS status callback", e)
            }
        }
    }

    private fun stopGnssStatusUpdates() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            gnssStatusCallback?.let {
                try {
                    locationManager.unregisterGnssStatusCallback(it)
                } catch (e: Exception) {
                    Log.e(TAG, "Error unregistering GNSS status callback", e)
                }
                gnssStatusCallback = null
            }
        }
        satelliteCount = 0
    }

    private fun handleLocationUpdate(location: Location) {
        locationUpdateCount++

        if (locationUpdateCount == 1) {
            DebugLog.i(TAG, "📍 First location received: lat=${location.latitude}, lon=${location.longitude}, alt=${location.altitude}")
        }

        // Log every location update to diagnose update frequency
        DebugLog.d(TAG, "📍 Location update #$locationUpdateCount received (time: ${location.time})")

        // Apply velocity smoothing
        val rawSpeedMPS = location.speed
        val rawSpeedInDisplayUnit = if (prefs.useMetric) rawSpeedMPS * 3.6f else rawSpeedMPS * 2.23694f
        val smoothedSpeed = velocitySmoother.addReading(rawSpeedInDisplayUnit)
        // Convert back to m/s for internal use
        smoothedVelocityMPS = if (prefs.useMetric) smoothedSpeed / 3.6f else smoothedSpeed / 2.23694f

        // Apply elevation smoothing with accuracy filtering
        val verticalAccuracy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && location.hasVerticalAccuracy()) {
            location.verticalAccuracyMeters
        } else {
            -1.0f
        }

        // Apply adaptive elevation smoothing with accuracy filtering
        // The smoother handles both accuracy filtering and adaptive EMA internally
        val smoothedElevation = elevationSmoother.addReading(
            location.altitude,
            verticalAccuracy.toDouble()
        )

        // Write to GPX file (currently writes every update received) with raw data
        if (locationUpdateCount % GPX_WRITE_INTERVAL == 0) {
            val locationData = LocationData(
                latitude = location.latitude,
                longitude = location.longitude,
                altitude = location.altitude,  // Raw altitude for GPX
                timestamp = location.time,
                speed = location.speed,
                horizontalAccuracy = location.accuracy,
                verticalAccuracy = verticalAccuracy
            )
            gpxWriter.appendPoint(locationData)
        }

        previousLocation = lastLocation
        lastLocation = location

        // Broadcast location update for visualization with smoothed velocity and elevation
        // Make it an EXPLICIT broadcast by setting the package to avoid restrictions
        val intent = Intent(LOCATION_UPDATE_ACTION).apply {
            setPackage(packageName)  // Make this an explicit broadcast
            putExtra(EXTRA_LATITUDE, location.latitude)
            putExtra(EXTRA_LONGITUDE, location.longitude)
            putExtra(EXTRA_ALTITUDE, smoothedElevation)  // Use smoothed elevation for display
            putExtra(EXTRA_SPEED, smoothedVelocityMPS)  // Use smoothed velocity
            putExtra(EXTRA_TIMESTAMP, location.time)
            putExtra("horizontal_accuracy", location.accuracy)
            putExtra("satellite_count", satelliteCount)
        }
        sendBroadcast(intent)
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SnowTeeth Tracking")
            .setContentText("Recording your activity")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification for location tracking service"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
