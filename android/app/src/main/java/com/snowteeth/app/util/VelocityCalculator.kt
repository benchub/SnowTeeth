package com.snowteeth.app.util

import com.snowteeth.app.model.LocationData
import com.snowteeth.app.model.VelocityBucket
import kotlin.math.abs

class VelocityCalculator(private val prefs: AppPreferences) {

    companion object {
        private const val MPH_TO_MPS = 0.44704f // miles per hour to meters per second
        private const val KPH_TO_MPS = 0.27778f // kilometers per hour to meters per second
    }

    /**
     * Calculates the velocity bucket based on speed and elevation change
     * @param currentLocation current GPS location
     * @param previousLocation previous GPS location
     * @return VelocityBucket representing the current state
     */
    fun calculateBucket(
        currentLocation: LocationData,
        previousLocation: LocationData?
    ): VelocityBucket {
        if (previousLocation == null) {
            return VelocityBucket.IDLE
        }

        val elevationChange = currentLocation.altitude - previousLocation.altitude
        val speedMps = currentLocation.speed
        val speedMph = speedMps / MPH_TO_MPS

        // Determine if going uphill or downhill
        val isDownhill = elevationChange < 0

        return if (isDownhill) {
            calculateDownhillBucket(speedMph)
        } else {
            calculateUphillBucket(speedMph)
        }
    }

    private fun calculateDownhillBucket(speedMph: Float): VelocityBucket {
        return when {
            speedMph >= prefs.downhillHardThreshold -> VelocityBucket.DOWNHILL_HARD
            speedMph >= prefs.downhillMediumThreshold -> VelocityBucket.DOWNHILL_MEDIUM
            speedMph >= prefs.downhillEasyThreshold -> VelocityBucket.DOWNHILL_EASY
            else -> VelocityBucket.IDLE
        }
    }

    private fun calculateUphillBucket(speedMph: Float): VelocityBucket {
        return when {
            speedMph >= prefs.uphillHardThreshold -> VelocityBucket.UPHILL_HARD
            speedMph >= prefs.uphillMediumThreshold -> VelocityBucket.UPHILL_MEDIUM
            speedMph >= prefs.uphillEasyThreshold -> VelocityBucket.UPHILL_EASY
            else -> VelocityBucket.IDLE
        }
    }

    /**
     * Calculates interpolation factor between two buckets for smooth color transitions
     * Returns 0.0 at lower threshold and 1.0 at upper threshold
     */
    fun calculateInterpolationFactor(
        currentLocation: LocationData,
        previousLocation: LocationData?,
        lowerBucket: VelocityBucket,
        upperBucket: VelocityBucket
    ): Float {
        if (previousLocation == null) return 0f

        val speedMps = currentLocation.speed
        val speedMph = speedMps / MPH_TO_MPS
        val elevationChange = currentLocation.altitude - previousLocation.altitude
        val isDownhill = elevationChange < 0

        val (lowerThreshold, upperThreshold) = when {
            isDownhill && lowerBucket == VelocityBucket.DOWNHILL_MEDIUM &&
                upperBucket == VelocityBucket.DOWNHILL_HARD ->
                prefs.downhillMediumThreshold to prefs.downhillHardThreshold

            isDownhill && lowerBucket == VelocityBucket.DOWNHILL_EASY &&
                upperBucket == VelocityBucket.DOWNHILL_MEDIUM ->
                prefs.downhillEasyThreshold to prefs.downhillMediumThreshold

            !isDownhill && lowerBucket == VelocityBucket.UPHILL_MEDIUM &&
                upperBucket == VelocityBucket.UPHILL_HARD ->
                prefs.uphillMediumThreshold to prefs.uphillHardThreshold

            !isDownhill && lowerBucket == VelocityBucket.UPHILL_EASY &&
                upperBucket == VelocityBucket.UPHILL_MEDIUM ->
                prefs.uphillEasyThreshold to prefs.uphillMediumThreshold

            else -> return 0f
        }

        if (upperThreshold == lowerThreshold) return 0f

        val factor = (speedMph - lowerThreshold) / (upperThreshold - lowerThreshold)
        return factor.coerceIn(0f, 1f)
    }
}
