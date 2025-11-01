package com.snowteeth.app

import android.graphics.Color
import android.graphics.PorterDuff
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.util.GpxWriter
import com.snowteeth.app.util.StatsCalculator

class StatsActivity : AppCompatActivity() {

    private lateinit var prefs: AppPreferences
    private lateinit var gpxWriter: GpxWriter
    private lateinit var statsCalculator: StatsCalculator

    private lateinit var noDataContainer: LinearLayout
    private lateinit var tvNoData: TextView
    private lateinit var statsContainer: ScrollView
    private lateinit var tvTrackingStartTime: TextView

    private var trackingStartTimeMillis: Long? = null
    private var pointCount: Int = 0

    private val updateHandler = Handler(Looper.getMainLooper())
    private val updateInterval = 1000L // 1 second

    private val updateRunnable = object : Runnable {
        override fun run() {
            loadStats()
            updateDurationDisplay()
            updateHandler.postDelayed(this, updateInterval)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_stats)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "Track Statistics"

        prefs = AppPreferences(this)
        gpxWriter = GpxWriter(this)
        statsCalculator = StatsCalculator()

        initializeViews()
        loadStats()
    }

    override fun onResume() {
        super.onResume()
        // Start auto-refresh
        updateHandler.postDelayed(updateRunnable, updateInterval)
    }

    override fun onPause() {
        super.onPause()
        // Stop auto-refresh
        updateHandler.removeCallbacks(updateRunnable)
    }

    private fun initializeViews() {
        noDataContainer = findViewById(R.id.noDataContainer)
        tvNoData = findViewById(R.id.tvNoData)
        statsContainer = findViewById(R.id.statsContainer)
        tvTrackingStartTime = findViewById(R.id.tvTrackingStartTime)
    }

    private fun loadStats() {
        if (!gpxWriter.hasTrack()) {
            showNoData()
            return
        }

        try {
            val gpxFile = gpxWriter.gpxFile
            val gpxContent = gpxFile.readText()
            val points = statsCalculator.parseGpxFile(gpxContent)

            if (points.isEmpty()) {
                showNoData()
                return
            }

            val stats = statsCalculator.calculateStats(points, prefs.useMetric)
            // Extract start time from first point (timestamp is in milliseconds)
            trackingStartTimeMillis = points.firstOrNull()?.timestamp

            // Calculate optimized point count
            // When stationary, the last point is temporary and will be removed when the next arrives
            // Check if last 3 points have same lat/lon (stationary)
            var optimizedCount = points.size
            if (points.size >= 3) {
                val last = points[points.size - 1]
                val secondLast = points[points.size - 2]
                val thirdLast = points[points.size - 3]

                if (last.latitude == secondLast.latitude &&
                    last.longitude == secondLast.longitude &&
                    secondLast.latitude == thirdLast.latitude &&
                    secondLast.longitude == thirdLast.longitude) {
                    // Stationary: current count includes temporary middle point that will be removed
                    optimizedCount = points.size - 1
                }
            }

            pointCount = optimizedCount
            displayStats(stats)
        } catch (e: Exception) {
            e.printStackTrace()
            showNoData()
        }
    }

    private fun showNoData() {
        noDataContainer.visibility = View.VISIBLE
        statsContainer.visibility = View.GONE

        // Set message based on tracking status
        val message = if (prefs.isTracking) {
            "Still gathering initial set of GPS data; will refresh when we have some."
        } else {
            "You need tracking enabled to see stats."
        }
        tvNoData.text = message
    }

    private fun displayStats(stats: com.snowteeth.app.util.TrackStats) {
        noDataContainer.visibility = View.GONE
        statsContainer.visibility = View.VISIBLE

        // Detect landscape mode
        val isLandscape = resources.configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE

        // Show GPS point count and duration - will be updated every second by updateDurationDisplay()
        updateDurationDisplay()

        // Vertical Feet Up - green arrow-up-circle-fill from Bootstrap Icons
        setupStatCard(
            R.id.cardVerticalUp,
            "Vertical Feet Up",
            String.format("%.0f ft", stats.verticalFeetUp),
            R.drawable.ic_stat_vertical_up,
            isLandscape
        )

        // Vertical Feet Down - red arrow-down-circle-fill from Bootstrap Icons
        setupStatCard(
            R.id.cardVerticalDown,
            "Vertical Feet Down",
            String.format("%.0f ft", stats.verticalFeetDown),
            R.drawable.ic_stat_vertical_down,
            isLandscape
        )

        // Horizontal Distance - white arrows on blue circle from Bootstrap Icons
        val distanceUnit = if (prefs.useMetric) "km" else "mi"
        setupStatCard(
            R.id.cardHorizontalDistance,
            "Horizontal Distance",
            String.format("%.2f %s", stats.horizontalDistance, distanceUnit),
            R.drawable.ic_stat_horizontal_distance,
            isLandscape
        )

        // Average Downhill Pace - white graph-down on orange square from Bootstrap Icons
        val paceUnit = if (prefs.useMetric) "km/h" else "mph"
        setupStatCard(
            R.id.cardDownhills,
            "Average Downhill Pace",
            String.format("%.1f %s", stats.avgDownhillPace, paceUnit),
            R.drawable.ic_stat_downhill,
            isLandscape
        )

        // Average Uphill Pace - white graph-up on purple square from Bootstrap Icons
        setupStatCard(
            R.id.cardUphills,
            "Average Uphill Pace",
            String.format("%.1f %s", stats.avgUphillPace, paceUnit),
            R.drawable.ic_stat_uphill,
            isLandscape
        )

        // Moving Time - white clock icon on blue square from Bootstrap Icons
        setupStatCard(
            R.id.cardLoops,
            "Moving Time",
            stats.formattedMovingTime(),
            R.drawable.ic_stat_clock,
            isLandscape
        )
    }

    private fun setupStatCard(cardId: Int, title: String, value: String, iconRes: Int, isCompact: Boolean) {
        val card = findViewById<View>(cardId)
        val ivIcon = card.findViewById<ImageView>(R.id.ivIcon)
        val tvTitle = card.findViewById<TextView>(R.id.tvTitle)
        val tvValue = card.findViewById<TextView>(R.id.tvValue)

        ivIcon.setImageResource(iconRes)
        // No color filter needed - Bootstrap Icons have colors baked in
        tvTitle.text = title
        tvValue.text = value

        // Apply compact styling in landscape mode
        val iconSizeDp = if (isCompact) 45 else 60
        val iconSizePx = (iconSizeDp * resources.displayMetrics.density).toInt()
        ivIcon.layoutParams.width = iconSizePx
        ivIcon.layoutParams.height = iconSizePx

        // Adjust text sizes
        tvTitle.textSize = if (isCompact) 11f else 14f
        tvValue.textSize = if (isCompact) 18f else 22f

        // Adjust card padding
        val paddingDp = if (isCompact) 12 else 16
        val paddingPx = (paddingDp * resources.displayMetrics.density).toInt()
        card.setPadding(paddingPx, paddingPx, paddingPx, paddingPx)

        // Adjust card margins
        val marginDp = if (isCompact) 6 else 13
        val marginPx = (marginDp * resources.displayMetrics.density).toInt()
        val layoutParams = card.layoutParams as android.view.ViewGroup.MarginLayoutParams
        layoutParams.setMargins(0, 0, 0, marginPx)
        card.layoutParams = layoutParams
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun updateDurationDisplay() {
        if (trackingStartTimeMillis != null) {
            val duration = formatDuration(trackingStartTimeMillis!!)
            val formattedCount = java.text.NumberFormat.getNumberInstance().format(pointCount)
            tvTrackingStartTime.text = "$formattedCount distinct GPS points over the last $duration"
            tvTrackingStartTime.visibility = View.VISIBLE
        } else {
            tvTrackingStartTime.visibility = View.GONE
        }
    }

    private fun formatDuration(startTimeMillis: Long): String {
        val interval = System.currentTimeMillis() - startTimeMillis
        val totalSeconds = (interval / 1000).toInt()

        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60

        return String.format("%d:%02d:%02d", hours, minutes, seconds)
    }
}
