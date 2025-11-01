//
//  VelocitySmoother.swift
//  SnowTeeth
//
//  Real-time velocity smoothing using spike rejection and exponential moving average.
//  Based on shared/algorithms/velocity_smoothing.md
//

import Foundation

/// Configuration for velocity smoothing
struct VelocitySmootherConfig {
    /// Absolute maximum velocity allowed (in mph or km/h)
    let absoluteMaxValue: Float

    /// Multiplier for spike detection - reject if > this times previous value
    let spikeMultiplier: Float

    /// Minimum velocity threshold - values below this are always preserved (stops)
    let minValueThreshold: Float

    /// EMA smoothing factor (0-1) - higher = more responsive
    let alpha: Float

    /// Default configuration for skiing/snowboarding
    static func skiing(useMetric: Bool) -> VelocitySmootherConfig {
        return VelocitySmootherConfig(
            absoluteMaxValue: useMetric ? 48.0 : 30.0,  // 48 km/h or 30 mph
            spikeMultiplier: 3.0,
            minValueThreshold: useMetric ? 1.6 : 1.0,   // 1.6 km/h or 1.0 mph
            alpha: 0.6  // 60% new value, 40% history
        )
    }
}

/// Real-time velocity smoother using spike rejection and EMA
class VelocitySmoother {
    private let config: VelocitySmootherConfig
    private var previousSmoothed: Float? = nil

    init(config: VelocitySmootherConfig) {
        self.config = config
    }

    /// Add a new velocity reading and get the smoothed result
    /// - Parameter velocity: Raw velocity reading (in mph or km/h)
    /// - Returns: Smoothed velocity
    func addReading(_ velocity: Float) -> Float {
        // Stage 1: Spike rejection
        var accepted = velocity

        if velocity >= config.minValueThreshold {
            // Not a stop - check for spikes
            if let prev = previousSmoothed {
                let isSpike = velocity > config.absoluteMaxValue &&
                             velocity > config.spikeMultiplier * prev
                if isSpike {
                    accepted = prev  // Reject spike, use previous
                }
            }
        }

        // Stage 2: EMA smoothing
        let smoothed: Float
        if let prev = previousSmoothed {
            smoothed = config.alpha * accepted + (1 - config.alpha) * prev
        } else {
            smoothed = accepted  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    /// Reset the smoother (e.g., when starting a new tracking session)
    func reset() {
        previousSmoothed = nil
    }
}
