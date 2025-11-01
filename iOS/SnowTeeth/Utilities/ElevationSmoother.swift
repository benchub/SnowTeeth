//
//  ElevationSmoother.swift
//  SnowTeeth
//
//  Real-time elevation smoothing using pattern-based spike detection and adaptive EMA.
//  Based on shared/algorithms/elevation_smoothing.md
//

import Foundation

/// Configuration for elevation smoothing
struct ElevationSmootherConfig {
    /// Maximum acceptable vertical accuracy in meters (for pattern-based estimates)
    let verticalAccuracyThreshold: Double

    /// Minimum alpha (used for noisy/oscillating data)
    let alphaMin: Double

    /// Maximum alpha (used for consistent trends)
    let alphaMax: Double

    /// Number of recent readings to consider for trend detection
    let trendWindow: Int

    /// Minimum change (in meters) to check for reversal spikes
    let spikeReversalThreshold: Double

    /// Default configuration for GPS elevation smoothing
    static func standard() -> ElevationSmootherConfig {
        return ElevationSmootherConfig(
            verticalAccuracyThreshold: 20.0,  // Reject spikes marked as 25m+
            alphaMin: 0.25,                    // Moderate smoothing for noise
            alphaMax: 0.75,                    // Responsive for trends
            trendWindow: 5,                    // Look at 5 recent readings
            spikeReversalThreshold: 3.0        // Changes >3m checked for reversals
        )
    }
}

/// Real-time elevation smoother using pattern-based spike detection and adaptive EMA
class ElevationSmoother {
    private let config: ElevationSmootherConfig
    private var previousSmoothed: Double? = nil
    private var recentElevations: [Double] = []  // Raw elevations for pattern detection
    private var recentAcceptedElevations: [Double] = []  // Accepted elevations for trend detection

    init(config: ElevationSmootherConfig) {
        self.config = config
    }

    /// Add a new elevation reading and get the smoothed result
    /// - Parameters:
    ///   - elevation: Raw elevation reading in meters
    ///   - verticalAccuracy: Vertical accuracy in meters (negative = unavailable, use pattern detection)
    /// - Returns: Smoothed elevation
    func addReading(_ elevation: Double, verticalAccuracy: Double) -> Double {
        // Track raw elevations for pattern-based spike detection
        recentElevations.append(elevation)
        if recentElevations.count > 4 {
            recentElevations.removeFirst()
        }

        // Stage 1: Pattern-based spike detection
        let estimatedAccuracy = estimateAccuracyFromPattern()
        var elevationToSmooth = elevation
        var wasRejected = false

        // Use provided vertical accuracy if available, otherwise use pattern-based estimate
        let accuracyToUse = verticalAccuracy >= 0 ? verticalAccuracy : estimatedAccuracy

        if accuracyToUse > config.verticalAccuracyThreshold {
            // Poor accuracy - use previous smoothed value if available
            if let prev = previousSmoothed {
                elevationToSmooth = prev
                wasRejected = true
            }
        }

        // Track accepted elevations for adaptive smoothing
        if !wasRejected {
            recentAcceptedElevations.append(elevationToSmooth)
            if recentAcceptedElevations.count > config.trendWindow {
                recentAcceptedElevations.removeFirst()
            }
        }

        // Stage 2: Adaptive EMA smoothing
        let alpha = calculateAdaptiveAlpha()
        let smoothed: Double
        if let prev = previousSmoothed {
            smoothed = alpha * elevationToSmooth + (1 - alpha) * prev
        } else {
            smoothed = elevationToSmooth  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    /// Estimates accuracy based on pattern analysis of recent elevations
    private func estimateAccuracyFromPattern() -> Double {
        // Need at least 4 points to detect patterns
        guard recentElevations.count >= 4 else {
            return 20.0  // Conservative for first few points
        }

        // Calculate recent changes
        var changes: [Double] = []
        for i in 1..<recentElevations.count {
            changes.append(recentElevations[i] - recentElevations[i-1])
        }

        // Pattern 1: Detect reversal spikes (large change that reverses)
        if changes.count >= 2 {
            let lastChange = changes[changes.count - 1]
            let secondLastChange = changes[changes.count - 2]

            if abs(lastChange) > config.spikeReversalThreshold &&
               abs(secondLastChange) > config.spikeReversalThreshold {
                // Check if they reverse direction
                if (lastChange > 0 && secondLastChange < 0) ||
                   (lastChange < 0 && secondLastChange > 0) {
                    return 30.0  // GPS spike detected
                }
            }
        }

        // Pattern 2: Detect oscillating noise (alternating directions)
        if changes.count >= 3 {
            let signs = changes.map { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }
            if signs[0] != 0 && signs[1] != 0 && signs[2] != 0 {
                // Check if alternating: +, -, + or -, +, -
                if signs[0] != signs[1] && signs[1] != signs[2] {
                    return 25.0  // Oscillating noise
                }
            }
        }

        // Pattern 3: Check for micro-jitter (small oscillations around same value)
        if recentElevations.count >= 5 {
            let mean = recentElevations.reduce(0, +) / Double(recentElevations.count)
            let maxDeviation = recentElevations.map { abs($0 - mean) }.max() ?? 0
            if maxDeviation < 1.0 {
                return 15.0  // Minor jitter while stationary
            }
        }

        // If no spike pattern detected, accept as legitimate
        return 8.0  // Good accuracy
    }

    /// Calculates adaptive alpha based on trend detection
    private func calculateAdaptiveAlpha() -> Double {
        // Need at least 3 readings to detect a trend
        guard recentAcceptedElevations.count >= 3 else {
            return config.alphaMin
        }

        // Calculate changes between consecutive accepted readings
        var changes: [Double] = []
        for i in 1..<recentAcceptedElevations.count {
            changes.append(recentAcceptedElevations[i] - recentAcceptedElevations[i-1])
        }

        // Count changes in same direction
        let positiveCount = changes.filter { $0 > 0 }.count
        let negativeCount = changes.filter { $0 < 0 }.count
        let totalNonZero = positiveCount + negativeCount

        guard totalNonZero > 0 else { return config.alphaMin }

        let majorityCount = max(positiveCount, negativeCount)
        let trendStrength = Double(majorityCount) / Double(totalNonZero)

        // Consider magnitude: larger changes = stronger trend
        let avgMagnitude = changes.map { abs($0) }.reduce(0, +) / Double(changes.count)
        let magnitudeBoost = min(avgMagnitude / 2.0, 1.0)

        // Combine and map to alpha range
        let combinedStrength = (trendStrength + magnitudeBoost) / 2.0
        let alpha = config.alphaMin + combinedStrength * (config.alphaMax - config.alphaMin)

        return max(config.alphaMin, min(config.alphaMax, alpha))
    }

    /// Reset the smoother (e.g., when starting a new tracking session)
    func reset() {
        previousSmoothed = nil
        recentElevations.removeAll()
        recentAcceptedElevations.removeAll()
    }
}
