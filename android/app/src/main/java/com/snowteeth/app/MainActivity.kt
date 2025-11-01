package com.snowteeth.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.PointF
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.snowteeth.app.effects.SnowParticleView
import com.snowteeth.app.service.LocationTrackingService
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.util.GpxWriter
import java.io.File

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var prefs: AppPreferences
    private lateinit var btnToggleTracking: Button
    private lateinit var snowParticleView: SnowParticleView
    private lateinit var titleText: TextView
    private var pendingVisualization: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        prefs = AppPreferences(this)
        btnToggleTracking = findViewById(R.id.btnToggleTracking)
        snowParticleView = findViewById(R.id.snowParticleView)
        titleText = findViewById(R.id.titleText)

        setupButtons()
        updateTrackingStatus()
        requestLocationPermissions()

        // Capture bounds after layout is complete
        titleText.post {
            captureAllBounds()
        }
    }

    override fun onResume() {
        super.onResume()
        updateTrackingStatus()
        // Reset and resume snow when returning to home screen
        snowParticleView.reset()
        snowParticleView.resume()
    }

    override fun onPause() {
        super.onPause()
        // Pause snow animations to save battery when leaving home screen
        snowParticleView.pause()
    }

    private fun setupButtons() {
        // Configuration button - gear-wide-connected from Bootstrap Icons
        val btnConfiguration = findViewById<Button>(R.id.btnConfiguration)
        setButtonIcon(btnConfiguration, R.drawable.ic_btn_configuration, android.graphics.Color.WHITE)
        btnConfiguration.setOnClickListener {
            startActivity(Intent(this, ConfigurationActivity::class.java))
        }

        // Visualization button - emoji-heart-eyes from Bootstrap Icons
        val btnVisualization = findViewById<Button>(R.id.btnVisualization)
        setButtonIcon(btnVisualization, R.drawable.ic_btn_visualization, android.graphics.Color.WHITE)
        btnVisualization.setOnClickListener {
            if (checkLocationPermissions()) {
                // If tracking is off and there's existing data, prompt before enabling
                if (!prefs.isTracking && hasTrackingData()) {
                    pendingVisualization = true
                    showStartTrackingConfirmationDialog()
                } else {
                    val intent = Intent(this, VisualizationActivity::class.java)
                    startActivity(intent)
                }
            } else {
                Toast.makeText(this, "Location permission required", Toast.LENGTH_SHORT).show()
                requestLocationPermissions()
            }
        }

        // Stats button - bar-chart from Bootstrap Icons
        val btnStats = findViewById<Button>(R.id.btnStats)
        setButtonIcon(btnStats, R.drawable.ic_btn_stats, android.graphics.Color.WHITE)
        btnStats.setOnClickListener {
            startActivity(Intent(this, StatsActivity::class.java))
        }

        // Share GPX button - upload from Bootstrap Icons
        val btnShareGPX = findViewById<Button>(R.id.btnShareGPX)
        setButtonIcon(btnShareGPX, R.drawable.ic_btn_share, android.graphics.Color.WHITE)
        btnShareGPX.setOnClickListener {
            shareGPXFile()
        }

        // Reset GPX button - x-octagon from Bootstrap Icons
        val btnResetGPX = findViewById<Button>(R.id.btnResetGPX)
        setButtonIcon(btnResetGPX, R.drawable.ic_btn_reset, android.graphics.Color.WHITE)
        btnResetGPX.setOnClickListener {
            showResetConfirmationDialog()
        }

        // Toggle tracking button
        btnToggleTracking.compoundDrawablePadding = 16
        btnToggleTracking.setOnClickListener {
            if (checkLocationPermissions()) {
                // If trying to start tracking and there's existing data, prompt
                if (!prefs.isTracking && hasTrackingData()) {
                    pendingVisualization = false
                    showStartTrackingConfirmationDialog()
                } else {
                    toggleTracking()
                }
            } else {
                Toast.makeText(this, "Location permission required", Toast.LENGTH_SHORT).show()
                requestLocationPermissions()
            }
        }
    }

    private fun setButtonIcon(button: Button, iconRes: Int, color: Int) {
        val drawable = ContextCompat.getDrawable(this, iconRes)?.mutate()
        drawable?.setColorFilter(color, android.graphics.PorterDuff.Mode.SRC_IN)

        // Scale icon to match text size (approximately 20dp)
        val iconSize = (20 * resources.displayMetrics.density).toInt()
        drawable?.setBounds(0, 0, iconSize, iconSize)

        button.setCompoundDrawables(drawable, null, null, null)
        button.compoundDrawablePadding = 16
    }

    private fun toggleTracking() {
        prefs.isTracking = !prefs.isTracking

        val serviceIntent = Intent(this, LocationTrackingService::class.java)
        if (prefs.isTracking) {
            serviceIntent.action = LocationTrackingService.ACTION_START_TRACKING
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Toast.makeText(this, "Tracking started", Toast.LENGTH_SHORT).show()
        } else {
            serviceIntent.action = LocationTrackingService.ACTION_STOP_TRACKING
            startService(serviceIntent)
            Toast.makeText(this, "Tracking stopped", Toast.LENGTH_SHORT).show()
        }

        updateTrackingStatus()
    }

    private fun updateTrackingStatus() {
        if (prefs.isTracking) {
            btnToggleTracking.text = "Stop Tracking"
            btnToggleTracking.backgroundTintList = ColorStateList.valueOf(
                ContextCompat.getColor(this, R.color.red)
            )
            // stop-circle from Bootstrap Icons
            setButtonIcon(btnToggleTracking, R.drawable.ic_btn_stop, android.graphics.Color.WHITE)
        } else {
            btnToggleTracking.text = "Start Tracking"
            btnToggleTracking.backgroundTintList = ColorStateList.valueOf(
                ContextCompat.getColor(this, R.color.green)
            )
            // play-circle from Bootstrap Icons
            setButtonIcon(btnToggleTracking, R.drawable.ic_btn_play, android.graphics.Color.WHITE)
        }
    }

    private fun checkLocationPermissions(): Boolean {
        val fineLocation = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocation = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineLocation && coarseLocation
    }

    private fun requestLocationPermissions() {
        val permissionsToRequest = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        ActivityCompat.requestPermissions(
            this,
            permissionsToRequest.toTypedArray(),
            LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                Toast.makeText(this, "Permissions granted", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Permissions required for tracking", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun shareGPXFile() {
        val gpxWriter = GpxWriter(this)
        val gpxFile = gpxWriter.gpxFile

        if (!gpxFile.exists()) {
            Toast.makeText(this, "No tracking data available to share", Toast.LENGTH_SHORT).show()
            return
        }

        try {
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                gpxFile
            )

            // Get statistics summary
            val statisticsText = gpxWriter.getStatisticsSummary(prefs.useMetric)

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/gpx+xml"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, "SnowTeeth Track Data")
                putExtra(Intent.EXTRA_TEXT, statisticsText)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            startActivity(Intent.createChooser(shareIntent, "Share GPX File"))
        } catch (e: Exception) {
            Log.e(TAG, "Error sharing GPX file", e)
            Toast.makeText(this, "Error sharing file: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun showResetConfirmationDialog() {
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("Reset GPS Tracking Data")
            .setMessage("This will reset your GPS tracking location and speed history. This action cannot be undone.")
            .setPositiveButton("Reset") { _, _ ->
                resetGPXData()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showStartTrackingConfirmationDialog() {
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("Reset GPS Stats?")
            .setMessage("You have existing GPS data. Do you want to reset it and start fresh, or keep adding to the existing data?")
            .setPositiveButton("Reset") { _, _ ->
                resetGPXData()
                startTracking(resetData = true)
                if (pendingVisualization) {
                    val intent = Intent(this, VisualizationActivity::class.java)
                    startActivity(intent)
                }
            }
            .setNegativeButton("Keep Existing") { _, _ ->
                startTracking(resetData = false)
                if (pendingVisualization) {
                    val intent = Intent(this, VisualizationActivity::class.java)
                    startActivity(intent)
                }
            }
            .show()
    }

    private fun startTracking(resetData: Boolean = true) {
        prefs.isTracking = true
        val serviceIntent = Intent(this, LocationTrackingService::class.java).apply {
            action = LocationTrackingService.ACTION_START_TRACKING
            putExtra(LocationTrackingService.EXTRA_RESET_DATA, resetData)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        Toast.makeText(this, "Tracking started", Toast.LENGTH_SHORT).show()
        updateTrackingStatus()
    }

    private fun hasTrackingData(): Boolean {
        val gpxWriter = GpxWriter(this)
        return gpxWriter.hasTrack()
    }

    private fun resetGPXData() {
        val gpxWriter = GpxWriter(this)
        val gpxFile = gpxWriter.gpxFile

        if (gpxFile.exists()) {
            if (gpxFile.delete()) {
                Toast.makeText(this, "GPS tracking data has been reset", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Failed to reset GPS tracking data", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, "No GPS tracking data to reset", Toast.LENGTH_SHORT).show()
        }
    }

    private fun captureAllBounds() {
        val allBounds = mutableListOf<com.snowteeth.app.effects.CollisionDetector.CollisionTarget>()

        // Capture title letter bounds
        val titleBounds = captureTitleBounds()
        allBounds.addAll(titleBounds)

        // Capture button bounds for snow accumulation
        allBounds.add(captureButtonBounds("button_config", findViewById(R.id.btnConfiguration)))
        allBounds.add(captureButtonBounds("button_viz", findViewById(R.id.btnVisualization)))
        allBounds.add(captureButtonBounds("button_stats", findViewById(R.id.btnStats)))
        allBounds.add(captureButtonBounds("button_share", findViewById(R.id.btnShareGPX)))
        allBounds.add(captureButtonBounds("button_reset", findViewById(R.id.btnResetGPX)))
        allBounds.add(captureButtonBounds("button_tracking", findViewById(R.id.btnToggleTracking)))

        snowParticleView.setTargetBounds(allBounds)
    }

    private fun captureTitleBounds(): List<com.snowteeth.app.effects.CollisionDetector.CollisionTarget> {
        val location = IntArray(2)
        titleText.getLocationOnScreen(location)

        // Also get location in window (excludes status bar offset)
        val locationInWindow = IntArray(2)
        titleText.getLocationInWindow(locationInWindow)

        val text = titleText.text.toString()
        val textSize = titleText.textSize
        val textPosition = PointF(location[0].toFloat(), location[1].toFloat())

        Log.d(TAG, "📍 Title TextView position on screen: x=${location[0]}, y=${location[1]}")
        Log.d(TAG, "   Title TextView position in window: x=${locationInWindow[0]}, y=${locationInWindow[1]}")
        Log.d(TAG, "   TextView dimensions: width=${titleText.width}, height=${titleText.height}")

        // Check SnowParticleView position for comparison
        val snowLocation = IntArray(2)
        snowParticleView.getLocationOnScreen(snowLocation)
        val snowLocationInWindow = IntArray(2)
        snowParticleView.getLocationInWindow(snowLocationInWindow)
        Log.d(TAG, "   SnowParticleView position on screen: x=${snowLocation[0]}, y=${snowLocation[1]}")
        Log.d(TAG, "   SnowParticleView position in window: x=${snowLocationInWindow[0]}, y=${snowLocationInWindow[1]}")

        // Calculate text starting X position (centered)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        paint.textSize = textSize
        paint.typeface = android.graphics.Typeface.DEFAULT_BOLD

        val textWidth = paint.measureText(text)
        val textStartX = textPosition.x + (titleText.width - textWidth) / 2f

        val fontMetrics = paint.fontMetrics
        val ascent = -fontMetrics.ascent
        val descent = fontMetrics.descent
        Log.d(TAG, "   Font metrics: ascent=$ascent, descent=$descent")
        Log.d(TAG, "   Text starting position (top): x=$textStartX, y=${textPosition.y}")

        // Pass the TOP position to calculator (it will handle baseline conversion internally)
        val calculator = com.snowteeth.app.effects.LetterBoundsCalculator()
        val letterBounds = calculator.calculateBounds(
            text = text,
            paint = paint,
            position = PointF(textStartX, textPosition.y)
        )

        Log.d(TAG, "📝 Letter bounds returned: ${letterBounds.take(3).map { "${it.id}: bounds=${it.bounds}" }}")
        return letterBounds
    }

    private fun captureButtonBounds(id: String, button: Button): com.snowteeth.app.effects.CollisionDetector.CollisionTarget {
        val location = IntArray(2)
        button.getLocationOnScreen(location)

        val bounds = RectF(
            location[0].toFloat(),
            location[1].toFloat(),
            location[0].toFloat() + button.width,
            location[1].toFloat() + button.height
        )

        Log.d(TAG, "🔘 Button $id bounds (screen coords): $bounds")

        return com.snowteeth.app.effects.CollisionDetector.CollisionTarget(id, bounds)
    }
}
