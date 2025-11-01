import Foundation

/// A self-contained module for cleaning and smoothing noisy time-series data.
///
/// This module provides two key operations:
/// 1. **Outlier Detection and Removal**: Uses Median Absolute Deviation (MAD) to identify
///    and replace statistical outliers while preserving legitimate extreme values.
/// 2. **Moving Average Smoothing**: Applies a configurable window-based moving average
///    to reduce noise in the data.
///
/// Example usage:
/// ```swift
/// let noisyData: [Double?] = [1.0, 2.0, 100.0, 3.0, 2.5, 3.5]
///
/// // Remove outliers
/// let config = TimeSeriesSmoothing.OutlierDetectionConfig(
///     madMultiplier: 3.0,
///     absoluteMaxValue: 30.0,
///     minValueThreshold: 1.0,
///     replacementWindowRadius: 5
/// )
/// let cleaned = TimeSeriesSmoothing.removeOutliers(from: noisyData, config: config)
///
/// // Apply smoothing
/// let smoothed = TimeSeriesSmoothing.movingAverage(data: cleaned, windowSize: 5)
///
/// // Or do both in one step
/// let result = TimeSeriesSmoothing.cleanAndSmooth(
///     data: noisyData,
///     outlierConfig: config,
///     windowSize: 5
/// )
/// ```
struct TimeSeriesSmoothing {

    /// Configuration for outlier detection using Median Absolute Deviation (MAD).
    struct OutlierDetectionConfig {
        /// Multiplier for MAD threshold (typically 2.5-3.5).
        /// Higher values are more permissive, lower values detect more outliers.
        let madMultiplier: Double

        /// Absolute maximum value allowed in the data (optional).
        /// Any value exceeding this will be considered an outlier regardless of MAD.
        /// Set to `nil` to disable.
        let absoluteMaxValue: Double?

        /// Minimum value threshold (optional).
        /// Values below this threshold are always preserved (e.g., to keep legitimate stops/zeros).
        /// Set to `nil` to disable.
        let minValueThreshold: Double?

        /// Radius of the window to search for replacement values when an outlier is found.
        /// For example, a radius of 5 will look at 5 points before and after the outlier.
        let replacementWindowRadius: Int

        /// Creates a new outlier detection configuration.
        ///
        /// - Parameters:
        ///   - madMultiplier: Multiplier for MAD threshold (default: 3.0)
        ///   - absoluteMaxValue: Absolute maximum value allowed (default: nil)
        ///   - minValueThreshold: Values below this are always kept (default: nil)
        ///   - replacementWindowRadius: Window radius for replacement values (default: 5)
        init(
            madMultiplier: Double = 3.0,
            absoluteMaxValue: Double? = nil,
            minValueThreshold: Double? = nil,
            replacementWindowRadius: Int = 5
        ) {
            self.madMultiplier = madMultiplier
            self.absoluteMaxValue = absoluteMaxValue
            self.minValueThreshold = minValueThreshold
            self.replacementWindowRadius = replacementWindowRadius
        }
    }

    // MARK: - Public API

    /// Removes outliers from time-series data using Median Absolute Deviation (MAD).
    ///
    /// This method identifies statistical outliers using MAD and replaces them with
    /// the median of nearby valid values. Optionally preserves values below a minimum
    /// threshold (useful for keeping legitimate stops/zeros).
    ///
    /// Algorithm:
    /// 1. Calculate median and MAD only from values above minValueThreshold (actual movement)
    ///    - This prevents long periods of stops from skewing the statistics
    /// 2. Define outlier threshold: median + (madMultiplier × MAD × 1.4826)
    /// 3. For each value:
    ///    - If below minValueThreshold: keep it (legitimate minimum/stop)
    ///    - If above threshold or absoluteMaxValue: replace with median of nearby valid values
    ///    - Otherwise: keep it
    ///
    /// - Parameters:
    ///   - data: Array of optional doubles representing the time-series
    ///   - config: Configuration for outlier detection
    /// - Returns: Array with outliers replaced by estimated valid values
    static func removeOutliers(from data: [Double?], config: OutlierDetectionConfig) -> [Double?] {
        // Extract all non-nil values
        let allValues = data.compactMap { $0 }
        guard !allValues.isEmpty else {
            return data.map { _ in nil }
        }

        // For datasets with long periods of stops, we need to calculate MAD only from
        // actual movement speeds (above minValueThreshold). Otherwise, stops will skew
        // the statistics and cause normal movement to be flagged as outliers.
        let movementValues: [Double]
        if let minThreshold = config.minValueThreshold {
            movementValues = allValues.filter { $0 >= minThreshold }
        } else {
            movementValues = allValues
        }

        // If we have no movement values (all stops), just return the data as-is
        guard !movementValues.isEmpty else {
            return data
        }

        // Calculate median and MAD (Median Absolute Deviation) from movement speeds only
        let sortedValues = movementValues.sorted()
        let median = sortedValues[sortedValues.count / 2]

        let deviations = movementValues.map { abs($0 - median) }.sorted()
        let mad = deviations[deviations.count / 2]

        // Define outlier threshold
        // The 1.4826 factor makes MAD comparable to standard deviation for normal distributions
        let upperThreshold = median + (config.madMultiplier * mad * 1.4826)

        // Clean the data
        var cleanedData: [Double?] = []

        for (index, value) in data.enumerated() {
            guard let value = value else {
                cleanedData.append(nil)
                continue
            }

            // Always keep values below the minimum threshold (if set)
            if let minThreshold = config.minValueThreshold, value < minThreshold {
                cleanedData.append(value)
                continue
            }

            // Check if value is an outlier
            let isOutlier: Bool
            if let absMax = config.absoluteMaxValue {
                isOutlier = value > upperThreshold || value > absMax
            } else {
                isOutlier = value > upperThreshold
            }

            if isOutlier {
                // Replace with median of nearby valid values
                let windowRadius = config.replacementWindowRadius
                let startIndex = max(0, index - windowRadius)
                let endIndex = min(data.count - 1, index + windowRadius)

                var nearbyValues: [Double] = []
                for i in startIndex...endIndex {
                    if i == index { continue } // Skip the outlier itself
                    if let nearbyValue = data[i],
                       nearbyValue <= upperThreshold,
                       (config.absoluteMaxValue == nil || nearbyValue <= config.absoluteMaxValue!) {
                        nearbyValues.append(nearbyValue)
                    }
                }

                if !nearbyValues.isEmpty {
                    // Use median of nearby valid values
                    let sortedNearby = nearbyValues.sorted()
                    cleanedData.append(sortedNearby[sortedNearby.count / 2])
                } else {
                    // If no nearby valid values, use overall median
                    cleanedData.append(median)
                }
            } else {
                // Value is valid, keep it
                cleanedData.append(value)
            }
        }

        return cleanedData
    }

    /// Applies a moving average to smooth time-series data.
    ///
    /// For each point, calculates the average of values within a centered window.
    /// Handles nil values gracefully by excluding them from the average calculation.
    ///
    /// - Parameters:
    ///   - data: Array of optional doubles representing the time-series
    ///   - windowSize: Size of the moving average window (must be odd for centered window)
    /// - Returns: Array with smoothed values
    static func movingAverage(data: [Double?], windowSize: Int) -> [Double?] {
        guard windowSize > 0 else { return data }

        var smoothedData: [Double?] = []

        for (index, value) in data.enumerated() {
            guard value != nil else {
                smoothedData.append(nil)
                continue
            }

            // Calculate window bounds (centered on current point)
            let halfWindow = windowSize / 2
            let startIndex = max(0, index - halfWindow)
            let endIndex = min(data.count - 1, index + halfWindow)

            // Collect non-nil values in the window
            var windowValues: [Double] = []
            for i in startIndex...endIndex {
                if let windowValue = data[i] {
                    windowValues.append(windowValue)
                }
            }

            // Calculate average
            if !windowValues.isEmpty {
                let average = windowValues.reduce(0.0, +) / Double(windowValues.count)
                smoothedData.append(average)
            } else {
                smoothedData.append(nil)
            }
        }

        return smoothedData
    }

    /// Combines outlier removal and moving average smoothing in a single operation.
    ///
    /// This is equivalent to calling `removeOutliers()` followed by `movingAverage()`,
    /// but provided as a convenience method for the common use case.
    ///
    /// - Parameters:
    ///   - data: Array of optional doubles representing the time-series
    ///   - outlierConfig: Configuration for outlier detection
    ///   - windowSize: Size of the moving average window
    /// - Returns: Array with outliers removed and smoothing applied
    static func cleanAndSmooth(
        data: [Double?],
        outlierConfig: OutlierDetectionConfig,
        windowSize: Int
    ) -> [Double?] {
        let cleaned = removeOutliers(from: data, config: outlierConfig)
        return movingAverage(data: cleaned, windowSize: windowSize)
    }
}
