package com.snowteeth.app.util

/**
 * Real-time velocity smoothing using spike rejection and exponential moving average.
 * Based on shared/algorithms/velocity_smoothing.md
 */

/**
 * Configuration for velocity smoothing
 */
data class VelocitySmootherConfig(
    /** Absolute maximum velocity allowed (in mph or km/h) */
    val absoluteMaxValue: Float,

    /** Multiplier for spike detection - reject if > this times previous value */
    val spikeMultiplier: Float = 3.0f,

    /** Minimum velocity threshold - values below this are always preserved (stops) */
    val minValueThreshold: Float,

    /** EMA smoothing factor (0-1) - higher = more responsive */
    val alpha: Float = 0.6f
) {
    companion object {
        /** Default configuration for skiing/snowboarding */
        fun skiing(useMetric: Boolean): VelocitySmootherConfig {
            return VelocitySmootherConfig(
                absoluteMaxValue = if (useMetric) 48.0f else 30.0f,  // 48 km/h or 30 mph
                spikeMultiplier = 3.0f,
                minValueThreshold = if (useMetric) 1.6f else 1.0f,   // 1.6 km/h or 1.0 mph
                alpha = 0.6f  // 60% new value, 40% history
            )
        }
    }
}

/**
 * Real-time velocity smoother using spike rejection and EMA
 */
class VelocitySmoother(private val config: VelocitySmootherConfig) {
    private var previousSmoothed: Float? = null

    /**
     * Add a new velocity reading and get the smoothed result
     * @param velocity Raw velocity reading (in mph or km/h)
     * @return Smoothed velocity
     */
    fun addReading(velocity: Float): Float {
        // Stage 1: Spike rejection
        var accepted = velocity

        if (velocity >= config.minValueThreshold) {
            // Not a stop - check for spikes
            previousSmoothed?.let { prev ->
                val isSpike = velocity > config.absoluteMaxValue &&
                             velocity > config.spikeMultiplier * prev
                if (isSpike) {
                    accepted = prev  // Reject spike, use previous
                }
            }
        }

        // Stage 2: EMA smoothing
        val smoothed = previousSmoothed?.let { prev ->
            config.alpha * accepted + (1 - config.alpha) * prev
        } ?: accepted  // First reading

        previousSmoothed = smoothed
        return smoothed
    }

    /** Reset the smoother (e.g., when starting a new tracking session) */
    fun reset() {
        previousSmoothed = null
    }
}
