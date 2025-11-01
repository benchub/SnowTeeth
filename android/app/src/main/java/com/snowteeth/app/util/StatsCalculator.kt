package com.snowteeth.app.util

import com.snowteeth.app.model.LocationData
import kotlin.math.*

data class TrackStats(
    val verticalFeetUp: Double,
    val verticalFeetDown: Double,
    val horizontalDistance: Double,
    val avgDownhillPace: Double,  // Average velocity in display units (mph or km/h)
    val avgUphillPace: Double,    // Average velocity in display units (mph or km/h)
    val movingTimeSeconds: Double
) {
    /**
     * Format moving time as HH:MM:SS (always shows hours for clarity)
     */
    fun formattedMovingTime(): String {
        val hours = (movingTimeSeconds.toInt()) / 3600
        val minutes = (movingTimeSeconds.toInt() % 3600) / 60
        val secs = movingTimeSeconds.toInt() % 60

        return String.format("%d:%02d:%02d", hours, minutes, secs)
    }
}

class StatsCalculator {

    companion object {
        private const val METERS_TO_FEET = 3.28084
        private const val METERS_TO_MILES = 0.000621371
        private const val METERS_TO_KM = 0.001
        private const val EARTH_RADIUS_METERS = 6371000.0
        private const val MPS_TO_MPH = 2.23694
        private const val MPS_TO_KPH = 3.6

        // Moving time threshold (speed above this is considered "moving")
        private const val MOVING_SPEED_THRESHOLD_MPH = 1.0
        private const val MOVING_SPEED_THRESHOLD_KPH = 1.6
    }

    /**
     * Calculates statistics from a list of location points
     */
    fun calculateStats(points: List<LocationData>, useMetric: Boolean): TrackStats {
        if (points.size < 2) {
            return TrackStats(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        }

        var totalUp = 0.0
        var totalDown = 0.0
        var totalDistance = 0.0

        // Track downhill and uphill distance and time for velocity calculation
        var downhillDistance = 0.0  // meters
        var downhillTime = 0.0      // seconds
        var uphillDistance = 0.0    // meters
        var uphillTime = 0.0        // seconds

        // Track moving time
        var movingTimeSeconds = 0.0
        val movingSpeedThreshold = if (useMetric) MOVING_SPEED_THRESHOLD_KPH else MOVING_SPEED_THRESHOLD_MPH

        for (i in 1 until points.size) {
            val prev = points[i - 1]
            val curr = points[i]

            // Calculate horizontal distance
            val segmentDistance = calculateDistance(prev, curr)
            totalDistance += segmentDistance

            // Calculate time elapsed (timestamps are in milliseconds)
            val timeDelta = (curr.timestamp - prev.timestamp) / 1000.0  // seconds

            // Calculate elevation change
            val elevationChange = curr.altitude - prev.altitude

            // Calculate instantaneous speed for this segment
            val instantaneousSpeedMPS = if (timeDelta > 0) segmentDistance / timeDelta else 0.0
            val instantaneousSpeedDisplay = if (useMetric) {
                instantaneousSpeedMPS * MPS_TO_KPH
            } else {
                instantaneousSpeedMPS * MPS_TO_MPH
            }

            // Track moving time (exclude stationary periods)
            if (instantaneousSpeedDisplay > movingSpeedThreshold) {
                movingTimeSeconds += timeDelta
            }

            // Track vertical gain/loss and velocity by direction
            if (elevationChange < 0) {
                // Downhill
                totalDown += abs(elevationChange)
                downhillDistance += segmentDistance
                downhillTime += timeDelta
            } else {
                // Uphill (includes flat)
                totalUp += elevationChange
                uphillDistance += segmentDistance
                uphillTime += timeDelta
            }
        }

        // Calculate average velocities (distance / time) and convert to display units
        val avgDownhillVelocityMPS = if (downhillTime > 0) downhillDistance / downhillTime else 0.0
        val avgUphillVelocityMPS = if (uphillTime > 0) uphillDistance / uphillTime else 0.0

        // Convert m/s to mph or km/h
        val avgDownhillPace = if (useMetric) avgDownhillVelocityMPS * MPS_TO_KPH else avgDownhillVelocityMPS * MPS_TO_MPH
        val avgUphillPace = if (useMetric) avgUphillVelocityMPS * MPS_TO_KPH else avgUphillVelocityMPS * MPS_TO_MPH

        // Convert to appropriate units
        val verticalUp = totalUp * METERS_TO_FEET
        val verticalDown = totalDown * METERS_TO_FEET
        val horizontalDist = if (useMetric) {
            totalDistance * METERS_TO_KM
        } else {
            totalDistance * METERS_TO_MILES
        }

        return TrackStats(
            verticalFeetUp = verticalUp,
            verticalFeetDown = verticalDown,
            horizontalDistance = horizontalDist,
            avgDownhillPace = avgDownhillPace,
            avgUphillPace = avgUphillPace,
            movingTimeSeconds = movingTimeSeconds
        )
    }

    /**
     * Calculates distance between two points using Haversine formula
     */
    private fun calculateDistance(point1: LocationData, point2: LocationData): Double {
        val lat1Rad = Math.toRadians(point1.latitude)
        val lat2Rad = Math.toRadians(point2.latitude)
        val deltaLat = Math.toRadians(point2.latitude - point1.latitude)
        val deltaLon = Math.toRadians(point2.longitude - point1.longitude)

        val a = sin(deltaLat / 2).pow(2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2).pow(2)

        val c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return EARTH_RADIUS_METERS * c
    }

    /**
     * Parses GPX file and returns list of location points
     */
    fun parseGpxFile(gpxContent: String): List<LocationData> {
        val points = mutableListOf<LocationData>()
        val trkptRegex = """<trkpt lat="([^"]+)" lon="([^"]+)">""".toRegex()
        val eleRegex = """<ele>([^<]+)</ele>""".toRegex()
        val timeRegex = """<time>([^<]+)</time>""".toRegex()

        val lines = gpxContent.lines()
        var i = 0
        while (i < lines.size) {
            val line = lines[i]
            val trkptMatch = trkptRegex.find(line)

            if (trkptMatch != null) {
                val lat = trkptMatch.groupValues[1].toDouble()
                val lon = trkptMatch.groupValues[2].toDouble()

                var ele = 0.0
                var time = System.currentTimeMillis()

                // Look ahead for ele and time tags
                for (j in i + 1 until minOf(i + 5, lines.size)) {
                    eleRegex.find(lines[j])?.let {
                        ele = it.groupValues[1].toDouble()
                    }
                    timeRegex.find(lines[j])?.let {
                        time = parseIso8601(it.groupValues[1])
                    }
                }

                points.add(LocationData(lat, lon, ele, time, 0f))
            }
            i++
        }

        return points
    }

    private fun parseIso8601(timestamp: String): Long {
        return try {
            val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
            sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
            sdf.parse(timestamp)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }
}
