package com.snowteeth.app.util

import com.snowteeth.app.model.LocationData
import kotlin.math.*

data class Loop(
    val id: Int,
    val points: List<LocationData>,
    val simplifiedPoints: List<LocationData>,
    val distance: Double,
    val duration: Long,
    val startTime: Long,
    val endTime: Long
)

class LoopTracker {

    companion object {
        // Algorithm constants (from shared/algorithms/loop_detection.md)
        private const val LOOP_START_THRESHOLD = 20.0  // meters
        private const val LAP_THRESHOLD = 25.0         // meters
        private const val MIN_LOOP_TIME = 30000L       // milliseconds
        private const val MIN_LOOP_DISTANCE = 100.0    // meters
        private const val SIMPLIFICATION_EPSILON = 10.0 // meters
        private const val LENGTH_TOLERANCE = 0.20       // 20%
        private const val SIMILARITY_THRESHOLD = 30.0   // meters
        private const val EARTH_RADIUS_METERS = 6371000.0
    }

    private enum class Phase {
        DETECTING_FIRST,
        TRACKING_LAPS
    }

    private var phase = Phase.DETECTING_FIRST
    private val allPoints = mutableListOf<LocationData>()
    private var referenceLoop: Loop? = null
    private var lapPoint: LocationData? = null
    private var currentLoopStartIndex = 0
    private val completedLoops = mutableListOf<Loop>()
    private val spatialIndex = SpatialGrid()

    /**
     * Add a new GPS point and check for loop completion
     * Returns the number of completed loops if a new loop was detected, null otherwise
     */
    fun addPoint(point: LocationData): Int? {
        allPoints.add(point)
        val currentIndex = allPoints.size - 1

        // Add to spatial index
        spatialIndex.insert(point, currentIndex)

        return when (phase) {
            Phase.DETECTING_FIRST -> checkForFirstLoop(currentIndex)
            Phase.TRACKING_LAPS -> checkForNextLap(currentIndex)
        }
    }

    /**
     * Returns the total number of completed loops
     */
    fun getLoopCount(): Int = completedLoops.size

    // MARK: - Phase 1: First Loop Detection

    private fun checkForFirstLoop(currentIndex: Int): Int? {
        val currentPoint = allPoints[currentIndex]

        // Don't check points from the last 30 seconds to avoid premature detection
        val minTimeDiff = 30000L // 30 seconds in milliseconds

        // Find nearby points that are old enough
        val nearbyIndices = spatialIndex.findNearbyPoints(currentPoint, LOOP_START_THRESHOLD)

        for (nearbyIndex in nearbyIndices) {
            val nearbyPoint = allPoints[nearbyIndex]

            // Check time difference
            if (abs(currentPoint.timestamp - nearbyPoint.timestamp) < minTimeDiff) {
                continue
            }

            val distance = calculateDistance(currentPoint, nearbyPoint)

            if (distance <= LOOP_START_THRESHOLD) {
                // Found first loop closure!
                val loopPoints = allPoints.subList(nearbyIndex, currentIndex + 1).toList()

                // Validate loop
                if (isValidLoop(loopPoints)) {
                    // Create reference loop
                    val loop = createLoop(1, loopPoints, nearbyIndex, currentIndex)

                    referenceLoop = loop
                    lapPoint = nearbyPoint
                    currentLoopStartIndex = currentIndex
                    completedLoops.add(loop)
                    phase = Phase.TRACKING_LAPS

                    return completedLoops.size
                }
            }
        }

        return null
    }

    // MARK: - Phase 2: Subsequent Loop Detection

    private fun checkForNextLap(currentIndex: Int): Int? {
        val lapPoint = this.lapPoint ?: return null

        val currentPoint = allPoints[currentIndex]
        val distanceToLapPoint = calculateDistance(currentPoint, lapPoint)

        if (distanceToLapPoint <= LAP_THRESHOLD) {
            // Potential lap completion
            val candidateLoopPoints = allPoints.subList(currentLoopStartIndex, currentIndex + 1).toList()

            // Validate as a loop
            if (!isValidLoop(candidateLoopPoints)) {
                return null
            }

            // Check if it matches the reference loop
            val referenceLoop = this.referenceLoop
            if (referenceLoop != null && loopsAreSimilar(candidateLoopPoints, referenceLoop.points)) {
                // Valid matching loop!
                val loop = createLoop(
                    completedLoops.size + 1,
                    candidateLoopPoints,
                    currentLoopStartIndex,
                    currentIndex
                )

                completedLoops.add(loop)
                currentLoopStartIndex = currentIndex

                return completedLoops.size
            }
        }

        return null
    }

    // MARK: - Validation and Comparison

    private fun isValidLoop(points: List<LocationData>): Boolean {
        if (points.size < 2) return false

        // Check minimum time
        val duration = points.last().timestamp - points.first().timestamp
        if (duration < MIN_LOOP_TIME) {
            return false
        }

        // Check minimum distance
        val distance = calculateTotalDistance(points)
        if (distance < MIN_LOOP_DISTANCE) {
            return false
        }

        return true
    }

    private fun loopsAreSimilar(loop1: List<LocationData>, loop2: List<LocationData>): Boolean {
        // Step 1: Simplify both loops
        val simplified1 = douglasPeucker(loop1, SIMPLIFICATION_EPSILON)
        val simplified2 = douglasPeucker(loop2, SIMPLIFICATION_EPSILON)

        // Step 2: Length check
        val length1 = calculateTotalDistance(loop1)
        val length2 = calculateTotalDistance(loop2)
        val lengthRatio = abs(length1 - length2) / maxOf(length1, length2)

        if (lengthRatio > LENGTH_TOLERANCE) {
            return false
        }

        // Step 3: Hausdorff-style distance
        val forwardDist = averageDistanceToClosestPoint(simplified1, simplified2)
        val backwardDist = averageDistanceToClosestPoint(simplified2, simplified1)
        val maxDeviation = maxOf(forwardDist, backwardDist)

        return maxDeviation < SIMILARITY_THRESHOLD
    }

    // MARK: - Helper Methods

    private fun createLoop(id: Int, points: List<LocationData>, startIndex: Int, endIndex: Int): Loop {
        val simplified = douglasPeucker(points, SIMPLIFICATION_EPSILON)
        val distance = calculateTotalDistance(points)
        val duration = points.last().timestamp - points.first().timestamp

        return Loop(
            id = id,
            points = points,
            simplifiedPoints = simplified,
            distance = distance,
            duration = duration,
            startTime = points.first().timestamp,
            endTime = points.last().timestamp
        )
    }

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

    private fun calculateTotalDistance(points: List<LocationData>): Double {
        if (points.size < 2) return 0.0

        var total = 0.0
        for (i in 1 until points.size) {
            total += calculateDistance(points[i - 1], points[i])
        }
        return total
    }

    private fun averageDistanceToClosestPoint(from: List<LocationData>, to: List<LocationData>): Double {
        if (from.isEmpty() || to.isEmpty()) return 0.0

        var totalDistance = 0.0

        for (point in from) {
            var minDistance = Double.MAX_VALUE
            for (otherPoint in to) {
                val distance = calculateDistance(point, otherPoint)
                minDistance = minOf(minDistance, distance)
            }
            totalDistance += minDistance
        }

        return totalDistance / from.size
    }

    // Douglas-Peucker algorithm for path simplification
    private fun douglasPeucker(points: List<LocationData>, epsilon: Double): List<LocationData> {
        if (points.size <= 2) return points

        // Find the point with maximum distance
        var maxDistance = 0.0
        var maxIndex = 0
        val end = points.size - 1

        for (i in 1 until end) {
            val distance = perpendicularDistance(
                points[i],
                points[0],
                points[end]
            )

            if (distance > maxDistance) {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance is greater than epsilon, recursively simplify
        return if (maxDistance > epsilon) {
            val left = douglasPeucker(points.subList(0, maxIndex + 1), epsilon)
            val right = douglasPeucker(points.subList(maxIndex, end + 1), epsilon)

            // Combine results (remove duplicate middle point)
            left + right.drop(1)
        } else {
            // All points in between can be removed
            listOf(points[0], points[end])
        }
    }

    private fun perpendicularDistance(
        point: LocationData,
        lineStart: LocationData,
        lineEnd: LocationData
    ): Double {
        // Calculate perpendicular distance from point to line
        val x0 = point.latitude
        val y0 = point.longitude
        val x1 = lineStart.latitude
        val y1 = lineStart.longitude
        val x2 = lineEnd.latitude
        val y2 = lineEnd.longitude

        val numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        val denominator = sqrt((y2 - y1).pow(2) + (x2 - x1).pow(2))

        if (denominator == 0.0) {
            return calculateDistance(point, lineStart)
        }

        // Convert to meters (rough approximation)
        val degreesToMeters = 111319.9 // meters per degree at equator
        return (numerator / denominator) * degreesToMeters
    }
}

// MARK: - Spatial Grid for Efficient Proximity Queries

class SpatialGrid {
    companion object {
        private const val CELL_SIZE = 50.0 // 50 meters per cell
        private const val METERS_PER_DEGREE = 111319.9
    }

    private val grid = mutableMapOf<GridCell, MutableList<Int>>()

    data class GridCell(val x: Int, val y: Int)

    fun insert(point: LocationData, index: Int) {
        val cell = getCell(point)
        grid.getOrPut(cell) { mutableListOf() }.add(index)
    }

    fun findNearbyPoints(point: LocationData, radius: Double): List<Int> {
        val centerCell = getCell(point)
        val nearbyIndices = mutableListOf<Int>()

        // Check 3x3 grid of cells
        for (dx in -1..1) {
            for (dy in -1..1) {
                val cell = GridCell(centerCell.x + dx, centerCell.y + dy)
                grid[cell]?.let { nearbyIndices.addAll(it) }
            }
        }

        return nearbyIndices
    }

    private fun getCell(point: LocationData): GridCell {
        // Convert lat/lon to approximate meters (rough calculation)
        val x = (point.latitude * METERS_PER_DEGREE / CELL_SIZE).toInt()
        val y = (point.longitude * METERS_PER_DEGREE / CELL_SIZE).toInt()
        return GridCell(x, y)
    }
}
