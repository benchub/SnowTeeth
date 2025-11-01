package com.snowteeth.app.util

/**
 * Configuration for elevation smoothing
 */
data class ElevationSmootherConfig(
    /** Maximum acceptable vertical accuracy in meters (for pattern-based estimates) */
    val verticalAccuracyThreshold: Double = 20.0,

    /** Minimum alpha (used for noisy/oscillating data) */
    val alphaMin: Double = 0.25,

    /** Maximum alpha (used for consistent trends) */
    val alphaMax: Double = 0.75,

    /** Number of recent readings to consider for trend detection */
    val trendWindow: Int = 5,

    /** Minimum change (in meters) to check for reversal spikes */
    val spikeReversalThreshold: Double = 3.0
) {
    companion object {
        /** Default configuration for GPS elevation smoothing */
        fun standard() = ElevationSmootherConfig()
    }
}

/**
 * Real-time elevation smoother using pattern-based spike detection and adaptive EMA.
 *
 * Algorithm:
 * 1. **Pattern-Based Spike Detection**: Analyze sequence of changes to detect spikes vs trends
 * 2. **Trend Detection**: Analyze accepted elevations to detect consistent trends
 * 3. **Adaptive EMA**: Use higher alpha for trends (responsive), lower for noise (smooth)
 */
class ElevationSmoother(private val config: ElevationSmootherConfig) {
    private var previousSmoothed: Double? = null
    private val recentElevations = mutableListOf<Double>()  // Raw elevations for pattern detection
    private val recentAcceptedElevations = mutableListOf<Double>()  // Accepted elevations for trend detection

    /**
     * Add a new elevation reading and get the smoothed result
     *
     * @param elevation Raw elevation reading in meters
     * @param verticalAccuracy Vertical accuracy in meters (negative = unavailable, use pattern detection)
     * @return Smoothed elevation
     */
    fun addReading(elevation: Double, verticalAccuracy: Double): Double {
        // Track raw elevations for pattern-based spike detection
        recentElevations.add(elevation)
        if (recentElevations.size > 4) {
            recentElevations.removeAt(0)
        }

        // Stage 1: Pattern-based spike detection
        val estimatedAccuracy = estimateAccuracyFromPattern()
        var elevationToSmooth = elevation
        var wasRejected = false

        // Use provided vertical accuracy if available, otherwise use pattern-based estimate
        val accuracyToUse = if (verticalAccuracy >= 0) verticalAccuracy else estimatedAccuracy

        if (accuracyToUse > config.verticalAccuracyThreshold) {
            // Poor accuracy - use previous smoothed value if available
            previousSmoothed?.let {
                elevationToSmooth = it
                wasRejected = true
            }
        }

        // Track accepted elevations for adaptive smoothing
        if (!wasRejected) {
            recentAcceptedElevations.add(elevationToSmooth)
            if (recentAcceptedElevations.size > config.trendWindow) {
                recentAcceptedElevations.removeAt(0)
            }
        }

        // Stage 2: Adaptive EMA smoothing
        val alpha = calculateAdaptiveAlpha()
        val smoothed = previousSmoothed?.let { prev ->
            alpha * elevationToSmooth + (1 - alpha) * prev
        } ?: elevationToSmooth  // First reading

        previousSmoothed = smoothed
        return smoothed
    }

    /**
     * Estimates accuracy based on pattern analysis of recent elevations
     */
    private fun estimateAccuracyFromPattern(): Double {
        // Need at least 4 points to detect patterns
        if (recentElevations.size < 4) {
            return 20.0  // Conservative for first few points
        }

        // Calculate recent changes
        val changes = mutableListOf<Double>()
        for (i in 1 until recentElevations.size) {
            changes.add(recentElevations[i] - recentElevations[i - 1])
        }

        // Pattern 1: Detect reversal spikes (large change that reverses)
        if (changes.size >= 2) {
            val lastChange = changes[changes.size - 1]
            val secondLastChange = changes[changes.size - 2]

            if (kotlin.math.abs(lastChange) > config.spikeReversalThreshold &&
                kotlin.math.abs(secondLastChange) > config.spikeReversalThreshold) {
                // Check if they reverse direction
                if ((lastChange > 0 && secondLastChange < 0) ||
                    (lastChange < 0 && secondLastChange > 0)) {
                    return 30.0  // GPS spike detected
                }
            }
        }

        // Pattern 2: Detect oscillating noise (alternating directions)
        if (changes.size >= 3) {
            val signs = changes.map { when {
                it > 0 -> 1
                it < 0 -> -1
                else -> 0
            }}
            if (signs[0] != 0 && signs[1] != 0 && signs[2] != 0) {
                // Check if alternating: +, -, + or -, +, -
                if (signs[0] != signs[1] && signs[1] != signs[2]) {
                    return 25.0  // Oscillating noise
                }
            }
        }

        // Pattern 3: Check for micro-jitter (small oscillations around same value)
        if (recentElevations.size >= 5) {
            val mean = recentElevations.average()
            val maxDeviation = recentElevations.map { kotlin.math.abs(it - mean) }.maxOrNull() ?: 0.0
            if (maxDeviation < 1.0) {
                return 15.0  // Minor jitter while stationary
            }
        }

        // If no spike pattern detected, accept as legitimate
        return 8.0  // Good accuracy
    }

    /**
     * Calculates adaptive alpha based on trend detection
     */
    private fun calculateAdaptiveAlpha(): Double {
        // Need at least 3 readings to detect a trend
        if (recentAcceptedElevations.size < 3) {
            return config.alphaMin
        }

        // Calculate changes between consecutive accepted readings
        val changes = mutableListOf<Double>()
        for (i in 1 until recentAcceptedElevations.size) {
            changes.add(recentAcceptedElevations[i] - recentAcceptedElevations[i - 1])
        }

        // Count changes in same direction
        val positiveCount = changes.count { it > 0 }
        val negativeCount = changes.count { it < 0 }
        val totalNonZero = positiveCount + negativeCount

        if (totalNonZero == 0) {
            return config.alphaMin
        }

        val majorityCount = maxOf(positiveCount, negativeCount)
        val trendStrength = majorityCount.toDouble() / totalNonZero.toDouble()

        // Consider magnitude: larger changes = stronger trend
        val avgMagnitude = changes.map { kotlin.math.abs(it) }.average()
        val magnitudeBoost = minOf(avgMagnitude / 2.0, 1.0)

        // Combine and map to alpha range
        val combinedStrength = (trendStrength + magnitudeBoost) / 2.0
        val alpha = config.alphaMin + combinedStrength * (config.alphaMax - config.alphaMin)
        return maxOf(config.alphaMin, minOf(config.alphaMax, alpha))
    }

    /**
     * Reset the smoother (e.g., when starting a new tracking session)
     */
    fun reset() {
        previousSmoothed = null
        recentElevations.clear()
        recentAcceptedElevations.clear()
    }
}
