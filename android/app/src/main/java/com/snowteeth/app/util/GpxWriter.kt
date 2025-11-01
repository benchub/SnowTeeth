package com.snowteeth.app.util

import android.content.Context
import android.location.Location
import com.snowteeth.app.model.LocationData
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*

class GpxWriter(private val context: Context) {

    companion object {
        private const val GPX_FILE_NAME = "snowteeth_track.gpx"
        private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
    }

    val gpxFile: File
        get() = File(context.getExternalFilesDir(null), GPX_FILE_NAME)

    // Track statistics
    private var previousLocation: LocationData? = null
    private var secondPreviousLocation: LocationData? = null
    private var downhillDistance: Double = 0.0  // meters
    private var downhillVelocitySum: Double = 0.0  // m/s
    private var downhillMovingPointCount: Int = 0  // Only points with speed > threshold
    private var uphillDistance: Double = 0.0  // meters
    private var uphillVelocitySum: Double = 0.0  // m/s
    private var uphillMovingPointCount: Int = 0  // Only points with speed > threshold

    // Minimum speed threshold to be considered "moving" (0.5 m/s ≈ 1.1 mph ≈ 1.8 km/h)
    private val minimumMovingSpeed: Double = 0.5

    /**
     * Starts a new GPX track file
     */
    fun startNewTrack() {
        // Reset statistics
        previousLocation = null
        secondPreviousLocation = null
        downhillDistance = 0.0
        downhillVelocitySum = 0.0
        downhillMovingPointCount = 0
        uphillDistance = 0.0
        uphillVelocitySum = 0.0
        uphillMovingPointCount = 0

        val file = gpxFile
        FileWriter(file, false).use { writer ->
            writer.write("""
                <?xml version="1.0" encoding="UTF-8"?>
                <gpx version="1.1" creator="SnowTeeth"
                     xmlns="http://www.topografix.com/GPX/1/1"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
                  <trk>
                    <name>SnowTeeth Track</name>
                    <trkseg>

            """.trimIndent())
        }
    }

    /**
     * Appends a location point to the GPX file
     * If the new point is at the same lat/lon as the two previous points,
     * removes the previous point (middle of three identical points)
     */
    fun appendPoint(location: LocationData) {
        val file = gpxFile
        if (!file.exists()) {
            startNewTrack()
        }

        // Check if we should remove the previous point (redundant stationary point)
        val shouldRemovePrevious = previousLocation != null &&
                                   secondPreviousLocation != null &&
                                   location.latitude == previousLocation!!.latitude &&
                                   location.longitude == previousLocation!!.longitude &&
                                   previousLocation!!.latitude == secondPreviousLocation!!.latitude &&
                                   previousLocation!!.longitude == secondPreviousLocation!!.longitude

        // Calculate statistics if we have a previous location
        previousLocation?.let { prev ->
            // Calculate distance between points
            val prevLocation = Location("").apply {
                latitude = prev.latitude
                longitude = prev.longitude
            }
            val currLocation = Location("").apply {
                latitude = location.latitude
                longitude = location.longitude
            }
            val distance = prevLocation.distanceTo(currLocation).toDouble() // meters

            // Determine if downhill or uphill
            val elevationChange = location.altitude - prev.altitude

            if (elevationChange < 0) {
                // Downhill
                downhillDistance += distance
                // Only include velocity in average if moving (speed > threshold)
                if (location.speed.toDouble() > minimumMovingSpeed) {
                    downhillVelocitySum += location.speed.toDouble()
                    downhillMovingPointCount += 1
                }
            } else {
                // Uphill (includes flat)
                uphillDistance += distance
                // Only include velocity in average if moving (speed > threshold)
                if (location.speed.toDouble() > minimumMovingSpeed) {
                    uphillVelocitySum += location.speed.toDouble()
                    uphillMovingPointCount += 1
                }
            }
        }

        // Update location history
        secondPreviousLocation = previousLocation
        previousLocation = location

        // Read existing content
        var content = file.readText()

        // Remove closing tags
        content = content
            .replace("    </trkseg>", "")
            .replace("  </trk>", "")
            .replace("</gpx>", "")
            .trimEnd()

        // If we should remove the previous point, find and remove the last <trkpt>...</trkpt> block
        if (shouldRemovePrevious) {
            val lastTrkptStart = content.lastIndexOf("<trkpt")
            if (lastTrkptStart >= 0) {
                val lastTrkptEnd = content.indexOf("</trkpt>", lastTrkptStart)
                if (lastTrkptEnd >= 0) {
                    // Remove the last trkpt block including the closing tag
                    content = content.substring(0, lastTrkptStart) +
                             content.substring(lastTrkptEnd + "</trkpt>".length)
                    content = content.trimEnd()
                }
            }
        }

        // Create new point
        val timestamp = dateFormat.format(Date(location.timestamp))
        val newPoint = """
      <trkpt lat="${location.latitude}" lon="${location.longitude}">
        <ele>${location.altitude}</ele>
        <time>$timestamp</time>
      </trkpt>
        """.trimIndent()

        // Write back with new point and closing tags
        FileWriter(file, false).use { writer ->
            writer.write(content)
            writer.write("\n")
            writer.write(newPoint)
            writer.write("\n")
            writer.write("""
                    </trkseg>
                  </trk>
                </gpx>
            """.trimIndent())
        }
    }

    /**
     * Finalizes the GPX file
     */
    fun finalizeTrack() {
        // File is already properly formatted with closing tags after each append
        // This method exists for API completeness
    }

    /**
     * Checks if a GPX file exists
     */
    fun hasTrack(): Boolean = gpxFile.exists() && gpxFile.length() > 0

    /**
     * Generates a statistics summary for sharing
     */
    fun getStatisticsSummary(useMetric: Boolean): String {
        // Calculate average velocity only from moving points (excludes stationary periods)
        val downhillAvgVelocity = if (downhillMovingPointCount > 0) downhillVelocitySum / downhillMovingPointCount else 0.0
        val uphillAvgVelocity = if (uphillMovingPointCount > 0) uphillVelocitySum / uphillMovingPointCount else 0.0

        return if (useMetric) {
            // Convert to km and km/h
            val downhillDistanceKm = downhillDistance / 1000.0
            val uphillDistanceKm = uphillDistance / 1000.0
            val downhillAvgVelocityKph = downhillAvgVelocity * 3.6
            val uphillAvgVelocityKph = uphillAvgVelocity * 3.6

            String.format(
                "Downhill: %.2f km @ %.1f km/h\nUphill: %.2f km @ %.1f km/h",
                downhillDistanceKm, downhillAvgVelocityKph,
                uphillDistanceKm, uphillAvgVelocityKph
            )
        } else {
            // Convert to miles and mph
            val downhillDistanceMiles = downhillDistance / 1609.34
            val uphillDistanceMiles = uphillDistance / 1609.34
            val downhillAvgVelocityMph = downhillAvgVelocity * 2.23694
            val uphillAvgVelocityMph = uphillAvgVelocity * 2.23694

            String.format(
                "Downhill: %.2f mi @ %.1f mph\nUphill: %.2f mi @ %.1f mph",
                downhillDistanceMiles, downhillAvgVelocityMph,
                uphillDistanceMiles, uphillAvgVelocityMph
            )
        }
    }
}
