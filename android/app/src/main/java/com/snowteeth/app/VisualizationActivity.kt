package com.snowteeth.app

import android.content.*
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.snowteeth.app.model.LocationData
import com.snowteeth.app.model.VelocityBucket
import com.snowteeth.app.model.VisualizationStyle
import com.snowteeth.app.service.LocationTrackingService
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.util.VelocityCalculator
import com.snowteeth.app.view.VisualizationView
import com.snowteeth.app.view.FireShaderView
import com.snowteeth.app.view.YetiVisualizationView
import com.snowteeth.app.view.DataVisualizationView

class VisualizationActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "VisualizationActivity"
    }

    private var visualizationView: VisualizationView? = null
    private var fireShaderView: FireShaderView? = null
    private var yetiVisualizationView: YetiVisualizationView? = null
    private var dataVisualizationView: DataVisualizationView? = null
    private lateinit var prefs: AppPreferences
    private lateinit var velocityCalculator: VelocityCalculator

    private var previousLocation: LocationData? = null
    private var previousAltitude: Double? = null
    private var currentBucket: VelocityBucket = VelocityBucket.IDLE
    private var isReceiverRegistered = false

    // GPS update time tracking
    private var lastGpsUpdateTime: Long = 0
    private lateinit var gpsUpdateIndicator: TextView
    private val updateHandler = Handler(Looper.getMainLooper())
    private val updateRunnable = object : Runnable {
        override fun run() {
            updateGpsIndicator()
            updateHandler.postDelayed(this, 1000) // Update every second
        }
    }

    private val locationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let {
                handleLocationUpdate(it)
            } ?: run {
                Log.e(TAG, "Received null intent!")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_visualization)

        // Hide action bar
        supportActionBar?.hide()

        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Make fullscreen
        makeFullscreen()

        prefs = AppPreferences(this)
        velocityCalculator = VelocityCalculator(prefs)

        // Get the root layout and set up the appropriate view
        val rootLayout = findViewById<FrameLayout>(R.id.rootLayout)
        gpsUpdateIndicator = findViewById(R.id.gpsUpdateIndicator)

        // Remove the default VisualizationView from XML
        val defaultView = findViewById<View>(R.id.visualizationView)
        rootLayout.removeView(defaultView)

        // Add the appropriate view based on visualization style
        // GPS indicator is only shown for data visualization
        when (prefs.visualizationStyle) {
            VisualizationStyle.FLAME -> {
                gpsUpdateIndicator.visibility = View.GONE
                fireShaderView = FireShaderView(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                }
                rootLayout.addView(fireShaderView, 0) // Add at index 0 so GPS indicator stays on top
                // Initialize with idle preset (no location data yet)
                val idlePreset = FlamePreset.IDLE
                fireShaderView?.applyPreset(
                    speed = idlePreset.speed,
                    intensity = idlePreset.intensity,
                    height = idlePreset.height,
                    colorShift = idlePreset.colorShift,
                    baseWidth = idlePreset.baseWidth,
                    colorBlend = idlePreset.colorBlend
                )
            }
            VisualizationStyle.DATA -> {
                gpsUpdateIndicator.visibility = View.VISIBLE
                dataVisualizationView = DataVisualizationView(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                }
                rootLayout.addView(dataVisualizationView, 0) // Add at index 0 so GPS indicator stays on top
                // Initialize with default values
                val unit = if (prefs.useMetric) "kilometers per hour" else "miles per hour"
                val distanceUnit = if (prefs.useMetric) "m" else "ft"
                dataVisualizationView?.updateData(
                    "  0.0",
                    "Latitude: --",
                    "Longitude: --",
                    String.format("Altitude:   -- %s", distanceUnit),
                    String.format("Accuracy:   -- %s", distanceUnit),
                    "Satellites: --",
                    unit
                )
            }
            VisualizationStyle.YETI -> {
                gpsUpdateIndicator.visibility = View.GONE
                yetiVisualizationView = YetiVisualizationView(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                }
                rootLayout.addView(yetiVisualizationView, 0) // Add at index 0 so GPS indicator stays on top
                yetiVisualizationView?.updateBucket(VelocityBucket.IDLE)
            }
        }

        // Register location receiver BEFORE starting tracking to avoid missing initial updates
        registerLocationReceiver()

        // Always ensure tracking service is running for visualization
        prefs.isTracking = true
        startTrackingService()

        // Set up tap to exit
        rootLayout.setOnClickListener {
            finish()
        }
    }

    override fun onResume() {
        super.onResume()
        // Receiver already registered in onCreate
        // Start GPS update indicator timer
        updateHandler.post(updateRunnable)
    }

    override fun onPause() {
        super.onPause()
        // Keep receiver registered for continuous updates
        // Stop GPS update indicator timer
        updateHandler.removeCallbacks(updateRunnable)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister receiver
        if (isReceiverRegistered) {
            unregisterReceiver(locationReceiver)
            isReceiverRegistered = false
        }
        // Clean up resources
        yetiVisualizationView?.cleanup()
        // Remove keep screen on flag
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun makeFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                )
        }
    }

    private fun registerLocationReceiver() {
        if (isReceiverRegistered) {
            return  // Already registered
        }

        val filter = IntentFilter(LocationTrackingService.LOCATION_UPDATE_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(locationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(locationReceiver, filter)
        }
        isReceiverRegistered = true
    }

    private fun startTrackingService() {
        val serviceIntent = Intent(this, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_START_TRACKING
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun handleLocationUpdate(intent: Intent) {
        val latitude = intent.getDoubleExtra(LocationTrackingService.EXTRA_LATITUDE, 0.0)
        val longitude = intent.getDoubleExtra(LocationTrackingService.EXTRA_LONGITUDE, 0.0)
        val altitude = intent.getDoubleExtra(LocationTrackingService.EXTRA_ALTITUDE, 0.0)
        val speed = intent.getFloatExtra(LocationTrackingService.EXTRA_SPEED, 0f)
        val timestamp = intent.getLongExtra(LocationTrackingService.EXTRA_TIMESTAMP, 0L)
        val horizontalAccuracy = intent.getFloatExtra("horizontal_accuracy", -1f)
        val satelliteCount = intent.getIntExtra("satellite_count", 0)

        // Track GPS update time
        lastGpsUpdateTime = System.currentTimeMillis()

        val currentLocation = LocationData(latitude, longitude, altitude, timestamp, speed, horizontalAccuracy)

        // Calculate velocity bucket
        currentBucket = velocityCalculator.calculateBucket(currentLocation, previousLocation)

        // Update visualization based on style
        when (prefs.visualizationStyle) {
            VisualizationStyle.FLAME -> {
                updateFlamePreset(currentBucket, currentLocation)
            }
            VisualizationStyle.DATA -> {
                updateDataVisualization(currentLocation, satelliteCount)
            }
            VisualizationStyle.YETI -> {
                yetiVisualizationView?.updateBucket(currentBucket)
            }
        }

        previousLocation = currentLocation
    }

    private fun updateGpsIndicator() {
        if (lastGpsUpdateTime == 0L) {
            gpsUpdateIndicator.text = "GPS: --"
            gpsUpdateIndicator.setTextColor(Color.parseColor("#AAAAAA"))
            return
        }

        val elapsedSeconds = (System.currentTimeMillis() - lastGpsUpdateTime) / 1000.0

        // Format the text
        val text = if (elapsedSeconds < 1.0) {
            "GPS: now"
        } else {
            String.format("GPS: %.1fs", elapsedSeconds)
        }

        // Color code based on staleness
        val color = when {
            elapsedSeconds < 2.0 -> Color.parseColor("#00FF00")  // Green: fresh
            elapsedSeconds < 5.0 -> Color.parseColor("#FFFF00")  // Yellow: aging
            elapsedSeconds < 10.0 -> Color.parseColor("#FF8800") // Orange: stale
            else -> Color.parseColor("#FF0000")                   // Red: very stale
        }

        gpsUpdateIndicator.text = text
        gpsUpdateIndicator.setTextColor(color)
    }

    // Flame shader presets (from shared/constants/flame_presets.json)
    // Updated for new 2D fire shader algorithm
    private data class FlamePreset(
        val speed: Float,
        val intensity: Float,
        val height: Float,
        val colorShift: Float,
        val baseWidth: Float,
        val colorBlend: Float
    ) {
        companion object {
            val IDLE = FlamePreset(
                speed = 0.2f, intensity = 0.5f, height = 0.33f,
                colorShift = 0.5f, baseWidth = 0.3f, colorBlend = 1.77f
            )

            val EASY = FlamePreset(
                speed = 0.47f, intensity = 1.98f, height = 0.44f,
                colorShift = 0.72f, baseWidth = 0.3f, colorBlend = 0.67f
            )

            val MEDIUM = FlamePreset(
                speed = 0.81f, intensity = 0.67f, height = 0.74f,
                colorShift = 1.13f, baseWidth = 0.51f, colorBlend = 1.42f
            )

            val HARD = FlamePreset(
                speed = 1.36f, intensity = 2.02f, height = 0.58f,
                colorShift = 1.73f, baseWidth = 0.82f, colorBlend = 1.13f
            )

            val ALTERNATE_ASCENT = FlamePreset(
                speed = 0.88f, intensity = 0.5f, height = 0.1f,
                colorShift = 1.36f, baseWidth = 0.3f, colorBlend = 1.62f
            )

            fun forBucket(bucket: VelocityBucket): FlamePreset {
                return when (bucket) {
                    VelocityBucket.IDLE -> IDLE
                    VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY -> EASY
                    VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM -> MEDIUM
                    VelocityBucket.DOWNHILL_HARD, VelocityBucket.UPHILL_HARD -> HARD
                }
            }

            // Interpolate between two presets based on factor (0.0 to 1.0)
            fun interpolate(from: FlamePreset, to: FlamePreset, factor: Float): FlamePreset {
                val clampedFactor = factor.coerceIn(0f, 1f)

                return FlamePreset(
                    speed = from.speed + (to.speed - from.speed) * clampedFactor,
                    intensity = from.intensity + (to.intensity - from.intensity) * clampedFactor,
                    height = from.height + (to.height - from.height) * clampedFactor,
                    colorShift = from.colorShift + (to.colorShift - from.colorShift) * clampedFactor,
                    baseWidth = from.baseWidth + (to.baseWidth - from.baseWidth) * clampedFactor,
                    colorBlend = from.colorBlend + (to.colorBlend - from.colorBlend) * clampedFactor
                )
            }
        }
    }

    private fun updateFlamePreset(bucket: VelocityBucket, currentLocation: LocationData) {
        val preset = calculateInterpolatedPreset(bucket, currentLocation)
        fireShaderView?.applyPreset(
            speed = preset.speed,
            intensity = preset.intensity,
            height = preset.height,
            colorShift = preset.colorShift,
            baseWidth = preset.baseWidth,
            colorBlend = preset.colorBlend
        )
    }

    private fun updateDataVisualization(currentLocation: LocationData, satelliteCount: Int) {
        // Format velocity (speed is in m/s, convert based on prefs)
        val speedMPS = currentLocation.speed
        val velocityValue = if (prefs.useMetric) {
            speedMPS * 3.6f  // m/s to km/h
        } else {
            speedMPS * 2.23694f  // m/s to mph
        }
        // Format with fixed width (5 chars: "XXX.X") - pads with leading spaces to keep decimal fixed
        val velocity = String.format("%5.1f", velocityValue)
        val velocityUnit = if (prefs.useMetric) "kilometers per hour" else "miles per hour"

        // Format latitude and longitude on separate lines
        val latitude = String.format("Latitude: %.4f", currentLocation.latitude)
        val longitude = String.format("Longitude: %.4f", currentLocation.longitude)

        // Format altitude with fixed width (4 digits)
        val altitudeValue = if (prefs.useMetric) {
            currentLocation.altitude
        } else {
            currentLocation.altitude * 3.28084
        }
        val altitudeUnit = if (prefs.useMetric) "m" else "ft"
        val altitude = String.format("Altitude: %4.0f %s", altitudeValue, altitudeUnit)

        // Format accuracy
        val accuracyValue = if (prefs.useMetric) {
            currentLocation.horizontalAccuracy
        } else {
            currentLocation.horizontalAccuracy * 3.28084f
        }
        val accuracyUnit = if (prefs.useMetric) "m" else "ft"
        val accuracy = if (currentLocation.horizontalAccuracy < 0) {
            String.format("Accuracy:   -- %s", accuracyUnit)
        } else {
            String.format("Accuracy: %4.0f %s", accuracyValue, accuracyUnit)
        }

        // Format satellite count
        val satellites = if (satelliteCount > 0) {
            String.format("Satellites: %2d", satelliteCount)
        } else {
            "Satellites: --"
        }

        // Determine uphill/downhill direction
        val direction = if (previousAltitude != null) {
            val altitudeDiff = currentLocation.altitude - previousAltitude!!
            if (kotlin.math.abs(altitudeDiff) > 1.0) { // Only show if change is > 1 meter
                if (altitudeDiff > 0) "uphill" else "downhill"
            } else {
                ""
            }
        } else {
            ""
        }
        previousAltitude = currentLocation.altitude

        if (dataVisualizationView != null) {
            dataVisualizationView?.updateData(velocity, latitude, longitude, altitude, accuracy, satellites, velocityUnit, direction)
        } else {
            Log.e(TAG, "ERROR: dataVisualizationView is NULL! Cannot update display!")
        }
    }

    private fun calculateInterpolatedPreset(bucket: VelocityBucket, currentLocation: LocationData): FlamePreset {
        // Check if alternate ascent mode is enabled and we're in an uphill bucket
        val isUphillBucket = bucket in listOf(VelocityBucket.UPHILL_EASY, VelocityBucket.UPHILL_MEDIUM, VelocityBucket.UPHILL_HARD)
        if (prefs.useAlternateAscentVisualization && isUphillBucket) {
            return FlamePreset.ALTERNATE_ASCENT
        }

        if (previousLocation == null) {
            // Return preset for bucket if no location data
            return FlamePreset.forBucket(bucket)
        }

        // Get speed in mph
        val speedMps = currentLocation.speed
        val speedMph = speedMps / 0.44704f

        // Determine direction
        val elevationChange = currentLocation.altitude - previousLocation!!.altitude
        val isDownhill = elevationChange < 0

        // Get bucket thresholds and presets
        val lowerThreshold: Float
        val upperThreshold: Float
        val lowerPreset: FlamePreset
        val centerPreset: FlamePreset
        val upperPreset: FlamePreset

        when (bucket) {
            VelocityBucket.IDLE -> {
                return FlamePreset.IDLE
            }
            VelocityBucket.DOWNHILL_EASY, VelocityBucket.UPHILL_EASY -> {
                lowerThreshold = if (isDownhill) prefs.downhillEasyThreshold else prefs.uphillEasyThreshold
                upperThreshold = if (isDownhill) prefs.downhillMediumThreshold else prefs.uphillMediumThreshold
                lowerPreset = FlamePreset.IDLE
                centerPreset = FlamePreset.EASY
                upperPreset = FlamePreset.MEDIUM
            }
            VelocityBucket.DOWNHILL_MEDIUM, VelocityBucket.UPHILL_MEDIUM -> {
                lowerThreshold = if (isDownhill) prefs.downhillMediumThreshold else prefs.uphillMediumThreshold
                upperThreshold = if (isDownhill) prefs.downhillHardThreshold else prefs.uphillHardThreshold
                lowerPreset = FlamePreset.EASY
                centerPreset = FlamePreset.MEDIUM
                upperPreset = FlamePreset.HARD
            }
            VelocityBucket.DOWNHILL_HARD, VelocityBucket.UPHILL_HARD -> {
                return FlamePreset.HARD
            }
        }

        // Calculate bucket center (this is where the preset is most accurate)
        val center = (lowerThreshold + upperThreshold) / 2.0f

        return if (speedMph < center) {
            // Lower half of bucket: interpolate from previous preset to current preset
            // At lower boundary: 50% blend, At center: 100% current preset
            val factor = 0.5f + (speedMph - lowerThreshold) / (center - lowerThreshold) * 0.5f
            val clampedFactor = factor.coerceIn(0.5f, 1.0f)
            FlamePreset.interpolate(lowerPreset, centerPreset, clampedFactor)
        } else {
            // Upper half of bucket: interpolate from current preset to next preset
            // At center: 100% current preset, At upper boundary: 50% blend
            val factor = (speedMph - center) / (upperThreshold - center) * 0.5f
            val clampedFactor = factor.coerceIn(0.0f, 0.5f)
            FlamePreset.interpolate(centerPreset, upperPreset, clampedFactor)
        }
    }
}
