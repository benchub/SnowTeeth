//
//  VelocityCalculator.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation

class VelocityCalculator {
    private let prefs: AppPreferences

    // Conversion constants
    private static let mphToMps: Float = 0.44704 // miles per hour to meters per second
    private static let kphToMps: Float = 0.27778 // kilometers per hour to meters per second

    init(prefs: AppPreferences) {
        self.prefs = prefs
    }

    /// Calculates the velocity bucket based on speed and elevation change
    /// - Parameters:
    ///   - currentLocation: current GPS location
    ///   - previousLocation: previous GPS location
    /// - Returns: VelocityBucket representing the current state
    func calculateBucket(currentLocation: LocationData, previousLocation: LocationData?) -> VelocityBucket {
        guard let previousLocation = previousLocation else {
            return .idle
        }

        let elevationChange = currentLocation.altitude - previousLocation.altitude
        let speedMps = currentLocation.speed
        let speedMph = speedMps / Self.mphToMps

        // Determine if going uphill or downhill
        let isDownhill = elevationChange < 0

        return isDownhill ? calculateDownhillBucket(speedMph: speedMph) : calculateUphillBucket(speedMph: speedMph)
    }

    private func calculateDownhillBucket(speedMph: Float) -> VelocityBucket {
        if speedMph >= prefs.downhillHardThreshold {
            return .downhillHard
        } else if speedMph >= prefs.downhillMediumThreshold {
            return .downhillMedium
        } else if speedMph >= prefs.downhillEasyThreshold {
            return .downhillEasy
        } else {
            return .idle
        }
    }

    private func calculateUphillBucket(speedMph: Float) -> VelocityBucket {
        if speedMph >= prefs.uphillHardThreshold {
            return .uphillHard
        } else if speedMph >= prefs.uphillMediumThreshold {
            return .uphillMedium
        } else if speedMph >= prefs.uphillEasyThreshold {
            return .uphillEasy
        } else {
            return .idle
        }
    }

    /// Calculates interpolation factor between two buckets for smooth color transitions
    /// Returns 0.0 at lower threshold and 1.0 at upper threshold
    func calculateInterpolationFactor(
        currentLocation: LocationData,
        previousLocation: LocationData?,
        lowerBucket: VelocityBucket,
        upperBucket: VelocityBucket
    ) -> Float {
        guard let previousLocation = previousLocation else {
            return 0.0
        }

        let speedMps = currentLocation.speed
        let speedMph = speedMps / Self.mphToMps
        let elevationChange = currentLocation.altitude - previousLocation.altitude
        let isDownhill = elevationChange < 0

        let (lowerThreshold, upperThreshold): (Float, Float)

        if isDownhill && lowerBucket == .downhillMedium && upperBucket == .downhillHard {
            lowerThreshold = prefs.downhillMediumThreshold
            upperThreshold = prefs.downhillHardThreshold
        } else if isDownhill && lowerBucket == .downhillEasy && upperBucket == .downhillMedium {
            lowerThreshold = prefs.downhillEasyThreshold
            upperThreshold = prefs.downhillMediumThreshold
        } else if !isDownhill && lowerBucket == .uphillMedium && upperBucket == .uphillHard {
            lowerThreshold = prefs.uphillMediumThreshold
            upperThreshold = prefs.uphillHardThreshold
        } else if !isDownhill && lowerBucket == .uphillEasy && upperBucket == .uphillMedium {
            lowerThreshold = prefs.uphillEasyThreshold
            upperThreshold = prefs.uphillMediumThreshold
        } else {
            return 0.0
        }

        if upperThreshold == lowerThreshold {
            return 0.0
        }

        let factor = (speedMph - lowerThreshold) / (upperThreshold - lowerThreshold)
        return max(0.0, min(1.0, factor))
    }
}
