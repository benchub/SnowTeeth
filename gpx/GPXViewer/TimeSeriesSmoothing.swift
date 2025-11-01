import Foundation

/// Velocity smoothing using spike rejection and exponential moving average (EMA).
///
/// This module provides lightweight, responsive smoothing for velocity data from GPS readings.
/// It is designed specifically for winter sports (skiing, snowboarding) where rapid speed changes
/// are legitimate and must be preserved.
///
/// Algorithm:
/// 1. **Spike Rejection**: Reject only physically impossible values (> absoluteMax AND > spikeMultiplier × previous)
/// 2. **EMA Smoothing**: Apply exponential moving average for minimal lag
///
/// Example usage:
/// ```swift
/// // Real-time processing
/// let config = VelocitySmootherConfig(
///     absoluteMaxValue: 30.0,  // mph or m/s depending on your data
///     spikeMultiplier: 3.0,
///     minValueThreshold: 1.0,
///     alpha: 0.6
/// )
/// let smoother = VelocitySmoother(config: config)
/// let smoothed = smoother.addReading(velocity)
///
/// // Batch processing
/// let smoothedArray = TimeSeriesSmoothing.smoothVelocities(velocities, config: config)
/// ```
struct TimeSeriesSmoothing {

    /// Configuration for velocity smoothing.
    struct VelocitySmootherConfig {
        /// Hard ceiling for realistic velocity.
        /// Values must exceed BOTH this AND the spike multiplier to be rejected.
        /// For skiing/snowboarding: 30 mph (48 km/h) or 13.4 m/s
        let absoluteMaxValue: Double

        /// How many times previous value before rejecting (default: 3.0).
        /// Example: if previous=10 mph, reject values > 30 mph
        let spikeMultiplier: Double

        /// Minimum movement speed (values below this are always preserved as stops).
        /// For example: 1.0 mph (1.6 km/h) or 0.45 m/s
        let minValueThreshold: Double

        /// Weight given to new reading in EMA (default: 0.6).
        /// Higher alpha (0.7-0.9) = more responsive, less smooth
        /// Lower alpha (0.3-0.5) = smoother, more lag
        let alpha: Double

        /// Creates a new velocity smoother configuration.
        ///
        /// - Parameters:
        ///   - absoluteMaxValue: Hard ceiling for realistic velocity
        ///   - spikeMultiplier: Multiplier for spike detection (default: 3.0)
        ///   - minValueThreshold: Values below this are always kept (stops)
        ///   - alpha: EMA weight for new readings (default: 0.6)
        init(
            absoluteMaxValue: Double,
            spikeMultiplier: Double = 3.0,
            minValueThreshold: Double,
            alpha: Double = 0.6
        ) {
            self.absoluteMaxValue = absoluteMaxValue
            self.spikeMultiplier = spikeMultiplier
            self.minValueThreshold = minValueThreshold
            self.alpha = alpha
        }
    }

    /// Smooths an array of velocities using spike rejection and EMA.
    ///
    /// This is a convenience method for batch processing historical data.
    /// For real-time processing, use VelocitySmoother class directly.
    ///
    /// - Parameters:
    ///   - velocities: Array of optional velocity readings
    ///   - config: Configuration for smoothing
    /// - Returns: Array of smoothed velocities
    static func smoothVelocities(_ velocities: [Double?], config: VelocitySmootherConfig) -> [Double?] {
        let smoother = VelocitySmoother(config: config)
        return velocities.map { velocity in
            guard let v = velocity else { return nil }
            return smoother.addReading(v)
        }
    }

    /// Configuration for elevation smoothing.
    struct ElevationSmootherConfig {
        /// Maximum acceptable vertical accuracy (in meters).
        /// Readings with accuracy worse than this will be rejected.
        /// Default: 15.0 meters (good GPS conditions)
        let verticalAccuracyThreshold: Double

        /// Minimum weight given to new reading in EMA (default: 0.3).
        /// Used when elevation is oscillating (noise).
        let alphaMin: Double

        /// Maximum weight given to new reading in EMA (default: 0.7).
        /// Used when elevation is trending consistently (real change).
        let alphaMax: Double

        /// Number of recent readings to consider for trend detection (default: 5).
        let trendWindow: Int

        /// Creates a new elevation smoother configuration.
        ///
        /// - Parameters:
        ///   - verticalAccuracyThreshold: Maximum acceptable vertical accuracy (default: 15.0m)
        ///   - alphaMin: Minimum EMA weight for noisy data (default: 0.3)
        ///   - alphaMax: Maximum EMA weight for trending data (default: 0.7)
        ///   - trendWindow: Number of readings for trend detection (default: 5)
        init(
            verticalAccuracyThreshold: Double = 15.0,
            alphaMin: Double = 0.3,
            alphaMax: Double = 0.7,
            trendWindow: Int = 5
        ) {
            self.verticalAccuracyThreshold = verticalAccuracyThreshold
            self.alphaMin = alphaMin
            self.alphaMax = alphaMax
            self.trendWindow = trendWindow
        }
    }

    /// Smooths an array of elevations using accuracy filtering and EMA.
    ///
    /// This is a convenience method for batch processing historical data.
    /// For real-time processing, use ElevationSmoother class directly.
    ///
    /// - Parameters:
    ///   - elevations: Array of optional elevation readings
    ///   - verticalAccuracies: Array of optional vertical accuracy values (negative = unavailable)
    ///   - config: Configuration for smoothing
    /// - Returns: Array of smoothed elevations
    static func smoothElevations(
        _ elevations: [Double?],
        verticalAccuracies: [Double?],
        config: ElevationSmootherConfig
    ) -> [Double?] {
        let smoother = ElevationSmoother(config: config)
        var results: [Double?] = []

        for i in 0..<elevations.count {
            guard let elevation = elevations[i] else {
                results.append(nil)
                continue
            }

            let verticalAccuracy = verticalAccuracies[i] ?? -1.0
            results.append(smoother.addReading(elevation, verticalAccuracy: verticalAccuracy))
        }

        return results
    }
}

/// Real-time velocity smoother using spike rejection and exponential moving average.
///
/// This class maintains state for sequential processing of velocity readings.
/// Use this for real-time applications or when you need to process readings one at a time.
class VelocitySmoother {
    private var previousSmoothed: Double? = nil
    private let config: TimeSeriesSmoothing.VelocitySmootherConfig

    /// Creates a new velocity smoother with the given configuration.
    ///
    /// - Parameter config: Configuration for smoothing behavior
    init(config: TimeSeriesSmoothing.VelocitySmootherConfig) {
        self.config = config
    }

    /// Processes a single velocity reading and returns the smoothed value.
    ///
    /// Algorithm:
    /// 1. Spike Rejection:
    ///    - Always preserve stops (< minValueThreshold)
    ///    - Reject values that are BOTH > absoluteMax AND > spikeMultiplier × previous
    ///    - Rejected spikes are replaced with previous smoothed value
    /// 2. EMA Smoothing:
    ///    - smoothed = alpha × accepted + (1 - alpha) × previousSmoothed
    ///    - First reading is not smoothed (no previous value)
    ///
    /// - Parameter velocity: Raw velocity reading
    /// - Returns: Smoothed velocity value
    func addReading(_ velocity: Double) -> Double {
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
        let smoothed: Double
        if let prev = previousSmoothed {
            smoothed = config.alpha * accepted + (1 - config.alpha) * prev
        } else {
            smoothed = accepted  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    /// Resets the smoother state for a new tracking session.
    func reset() {
        previousSmoothed = nil
    }
}

/// Real-time elevation smoother using accuracy filtering and adaptive exponential moving average.
///
/// This class maintains state for sequential processing of elevation readings.
/// Use this for real-time applications or when you need to process readings one at a time.
///
/// Algorithm:
/// 1. **Accuracy Filtering**: Reject readings with poor vertical accuracy (> threshold)
/// 2. **Trend Detection**: Analyze recent elevation changes to detect consistent trends
/// 3. **Adaptive EMA**: Use higher alpha for trends (responsive), lower for noise (smooth)
class ElevationSmoother {
    private var previousSmoothed: Double? = nil
    private var recentAcceptedElevations: [Double] = []
    private let config: TimeSeriesSmoothing.ElevationSmootherConfig

    /// Creates a new elevation smoother with the given configuration.
    ///
    /// - Parameter config: Configuration for smoothing behavior
    init(config: TimeSeriesSmoothing.ElevationSmootherConfig) {
        self.config = config
    }

    /// Processes a single elevation reading and returns the smoothed value.
    ///
    /// Algorithm:
    /// 1. Accuracy Filtering:
    ///    - Reject readings with verticalAccuracy < 0 (unavailable)
    ///    - Reject readings with verticalAccuracy > threshold (poor GPS)
    ///    - Rejected readings are replaced with previous smoothed value
    /// 2. Trend Detection:
    ///    - Analyze recent accepted elevations to detect consistent trends
    ///    - Calculate trend strength (0.0 = pure noise, 1.0 = perfect trend)
    /// 3. Adaptive EMA:
    ///    - alpha = alphaMin + trendStrength × (alphaMax - alphaMin)
    ///    - smoothed = alpha × accepted + (1 - alpha) × previousSmoothed
    ///
    /// - Parameters:
    ///   - elevation: Raw elevation reading in meters
    ///   - verticalAccuracy: Vertical accuracy in meters (negative = unavailable)
    /// - Returns: Smoothed elevation value
    func addReading(_ elevation: Double, verticalAccuracy: Double) -> Double {
        // Stage 1: Accuracy-based filtering
        var elevationToSmooth = elevation
        var wasRejected = false

        if verticalAccuracy < 0 || verticalAccuracy > config.verticalAccuracyThreshold {
            // Poor vertical accuracy - use previous smoothed value if available
            if let prev = previousSmoothed {
                elevationToSmooth = prev
                wasRejected = true
            }
            // If no previous value, accept raw reading anyway (first reading)
        }

        // Track accepted elevations for trend detection (but not rejected ones)
        if !wasRejected {
            recentAcceptedElevations.append(elevationToSmooth)
            if recentAcceptedElevations.count > config.trendWindow {
                recentAcceptedElevations.removeFirst()
            }
        }

        // Stage 2: Trend detection and adaptive alpha calculation
        let alpha = calculateAdaptiveAlpha()

        // Stage 3: EMA smoothing with adaptive alpha
        let smoothed: Double
        if let prev = previousSmoothed {
            smoothed = alpha * elevationToSmooth + (1 - alpha) * prev
        } else {
            smoothed = elevationToSmooth  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    /// Calculates adaptive alpha based on trend detection.
    ///
    /// Analyzes recent accepted elevations to determine if there's a consistent trend
    /// (all going up or all going down) vs. oscillating noise.
    ///
    /// - Returns: Alpha value between alphaMin and alphaMax
    private func calculateAdaptiveAlpha() -> Double {
        // Need at least 3 readings to detect a trend
        guard recentAcceptedElevations.count >= 3 else {
            return config.alphaMin  // Not enough data, be conservative
        }

        // Calculate changes between consecutive readings
        var changes: [Double] = []
        for i in 1..<recentAcceptedElevations.count {
            let change = recentAcceptedElevations[i] - recentAcceptedElevations[i-1]
            changes.append(change)
        }

        // Count how many changes are in the same direction as the majority
        let positiveCount = changes.filter { $0 > 0 }.count
        let negativeCount = changes.filter { $0 < 0 }.count
        let totalNonZero = positiveCount + negativeCount

        guard totalNonZero > 0 else {
            return config.alphaMin  // No change detected, be conservative
        }

        // Trend strength: 1.0 = all changes in same direction, 0.0 = evenly split
        let majorityCount = max(positiveCount, negativeCount)
        let trendStrength = Double(majorityCount) / Double(totalNonZero)

        // Also consider magnitude: larger consistent changes = stronger trend
        let avgMagnitude = changes.map { abs($0) }.reduce(0, +) / Double(changes.count)
        let magnitudeBoost = min(avgMagnitude / 2.0, 1.0)  // Cap at 1.0, boost if changes > 2m

        // Combine trend consistency and magnitude
        let combinedStrength = (trendStrength + magnitudeBoost) / 2.0

        // Map to alpha range
        let alpha = config.alphaMin + combinedStrength * (config.alphaMax - config.alphaMin)

        return max(config.alphaMin, min(config.alphaMax, alpha))
    }

    /// Resets the smoother state for a new tracking session.
    func reset() {
        previousSmoothed = nil
        recentAcceptedElevations.removeAll()
    }
}
