//
//  LoopTracker.swift
//  SnowTeeth
//
//  Loop detection algorithm for tracking when user completes laps/loops
//

import Foundation
import CoreLocation

struct Loop {
    let id: Int
    let points: [LocationData]
    let simplifiedPoints: [LocationData]
    let distance: Double
    let duration: TimeInterval
    let startTime: Int64
    let endTime: Int64
}

class LoopTracker {
    // Algorithm constants (from shared/algorithms/loop_detection.md)
    private static let loopStartThreshold: Double = 20.0  // meters
    private static let lapThreshold: Double = 25.0         // meters
    private static let minLoopTime: TimeInterval = 30.0    // seconds
    private static let minLoopDistance: Double = 100.0     // meters
    private static let simplificationEpsilon: Double = 10.0 // meters
    private static let lengthTolerance: Double = 0.20       // 20%
    private static let similarityThreshold: Double = 30.0   // meters

    private enum Phase {
        case detectingFirst
        case trackingLaps
    }

    private var phase: Phase = .detectingFirst
    private var allPoints: [LocationData] = []
    private var referenceLoop: Loop?
    private var lapPoint: LocationData?
    private var currentLoopStartIndex: Int = 0
    private var completedLoops: [Loop] = []
    private var spatialIndex: SpatialGrid = SpatialGrid()

    /// Add a new GPS point and check for loop completion
    /// Returns the number of completed loops if a new loop was detected, nil otherwise
    func addPoint(_ point: LocationData) -> Int? {
        allPoints.append(point)
        let currentIndex = allPoints.count - 1

        // Add to spatial index
        spatialIndex.insert(point: point, index: currentIndex)

        switch phase {
        case .detectingFirst:
            return checkForFirstLoop(currentIndex: currentIndex)

        case .trackingLaps:
            return checkForNextLap(currentIndex: currentIndex)
        }
    }

    /// Returns the total number of completed loops
    func getLoopCount() -> Int {
        return completedLoops.count
    }

    // MARK: - Phase 1: First Loop Detection

    private func checkForFirstLoop(currentIndex: Int) -> Int? {
        let currentPoint = allPoints[currentIndex]

        // Don't check points from the last 30 seconds to avoid premature detection
        let minTimeDiff: Int64 = 30000 // 30 seconds in milliseconds

        // Find nearby points that are old enough
        let nearbyIndices = spatialIndex.findNearbyPoints(point: currentPoint, radius: Self.loopStartThreshold)

        for nearbyIndex in nearbyIndices {
            let nearbyPoint = allPoints[nearbyIndex]

            // Check time difference
            if abs(currentPoint.timestamp - nearbyPoint.timestamp) < minTimeDiff {
                continue
            }

            let distance = calculateDistance(point1: currentPoint, point2: nearbyPoint)

            if distance <= Self.loopStartThreshold {
                // Found first loop closure!
                let loopPoints = Array(allPoints[nearbyIndex...currentIndex])

                // Validate loop
                if isValidLoop(points: loopPoints) {
                    // Create reference loop
                    let loop = createLoop(
                        id: 1,
                        points: loopPoints,
                        startIndex: nearbyIndex,
                        endIndex: currentIndex
                    )

                    referenceLoop = loop
                    lapPoint = nearbyPoint
                    currentLoopStartIndex = currentIndex
                    completedLoops.append(loop)
                    phase = .trackingLaps

                    return completedLoops.count
                }
            }
        }

        return nil
    }

    // MARK: - Phase 2: Subsequent Loop Detection

    private func checkForNextLap(currentIndex: Int) -> Int? {
        guard let lapPoint = lapPoint else { return nil }

        let currentPoint = allPoints[currentIndex]
        let distanceToLapPoint = calculateDistance(point1: currentPoint, point2: lapPoint)

        if distanceToLapPoint <= Self.lapThreshold {
            // Potential lap completion
            let candidateLoopPoints = Array(allPoints[currentLoopStartIndex...currentIndex])

            // Validate as a loop
            guard isValidLoop(points: candidateLoopPoints) else {
                return nil
            }

            // Check if it matches the reference loop
            if let referenceLoop = referenceLoop,
               loopsAreSimilar(loop1: candidateLoopPoints, loop2: referenceLoop.points) {
                // Valid matching loop!
                let loop = createLoop(
                    id: completedLoops.count + 1,
                    points: candidateLoopPoints,
                    startIndex: currentLoopStartIndex,
                    endIndex: currentIndex
                )

                completedLoops.append(loop)
                currentLoopStartIndex = currentIndex

                return completedLoops.count
            }
        }

        return nil
    }

    // MARK: - Validation and Comparison

    private func isValidLoop(points: [LocationData]) -> Bool {
        guard points.count >= 2 else { return false }

        // Check minimum time
        let duration = TimeInterval(points.last!.timestamp - points.first!.timestamp) / 1000.0
        if duration < Self.minLoopTime {
            return false
        }

        // Check minimum distance
        let distance = calculateTotalDistance(points: points)
        if distance < Self.minLoopDistance {
            return false
        }

        return true
    }

    private func loopsAreSimilar(loop1: [LocationData], loop2: [LocationData]) -> Bool {
        // Step 1: Simplify both loops
        let simplified1 = douglasPeucker(points: loop1, epsilon: Self.simplificationEpsilon)
        let simplified2 = douglasPeucker(points: loop2, epsilon: Self.simplificationEpsilon)

        // Step 2: Length check
        let length1 = calculateTotalDistance(points: loop1)
        let length2 = calculateTotalDistance(points: loop2)
        let lengthRatio = abs(length1 - length2) / max(length1, length2)

        if lengthRatio > Self.lengthTolerance {
            return false
        }

        // Step 3: Hausdorff-style distance
        let forwardDist = averageDistanceToClosestPoint(from: simplified1, to: simplified2)
        let backwardDist = averageDistanceToClosestPoint(from: simplified2, to: simplified1)
        let maxDeviation = max(forwardDist, backwardDist)

        return maxDeviation < Self.similarityThreshold
    }

    // MARK: - Helper Methods

    private func createLoop(id: Int, points: [LocationData], startIndex: Int, endIndex: Int) -> Loop {
        let simplified = douglasPeucker(points: points, epsilon: Self.simplificationEpsilon)
        let distance = calculateTotalDistance(points: points)
        let duration = TimeInterval(points.last!.timestamp - points.first!.timestamp) / 1000.0

        return Loop(
            id: id,
            points: points,
            simplifiedPoints: simplified,
            distance: distance,
            duration: duration,
            startTime: points.first!.timestamp,
            endTime: points.last!.timestamp
        )
    }

    private func calculateDistance(point1: LocationData, point2: LocationData) -> Double {
        let earthRadiusMeters: Double = 6371000.0

        let lat1Rad = point1.latitude * .pi / 180.0
        let lat2Rad = point2.latitude * .pi / 180.0
        let deltaLat = (point2.latitude - point1.latitude) * .pi / 180.0
        let deltaLon = (point2.longitude - point1.longitude) * .pi / 180.0

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    private func calculateTotalDistance(points: [LocationData]) -> Double {
        guard points.count >= 2 else { return 0.0 }

        var total: Double = 0.0
        for i in 1..<points.count {
            total += calculateDistance(point1: points[i-1], point2: points[i])
        }
        return total
    }

    private func averageDistanceToClosestPoint(from: [LocationData], to: [LocationData]) -> Double {
        guard !from.isEmpty && !to.isEmpty else { return 0.0 }

        var totalDistance: Double = 0.0

        for point in from {
            var minDistance = Double.infinity
            for otherPoint in to {
                let distance = calculateDistance(point1: point, point2: otherPoint)
                minDistance = min(minDistance, distance)
            }
            totalDistance += minDistance
        }

        return totalDistance / Double(from.count)
    }

    // Douglas-Peucker algorithm for path simplification
    private func douglasPeucker(points: [LocationData], epsilon: Double) -> [LocationData] {
        guard points.count > 2 else { return points }

        // Find the point with maximum distance
        var maxDistance: Double = 0.0
        var maxIndex: Int = 0
        let end = points.count - 1

        for i in 1..<end {
            let distance = perpendicularDistance(
                point: points[i],
                lineStart: points[0],
                lineEnd: points[end]
            )

            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance is greater than epsilon, recursively simplify
        if maxDistance > epsilon {
            let left = douglasPeucker(points: Array(points[0...maxIndex]), epsilon: epsilon)
            let right = douglasPeucker(points: Array(points[maxIndex...end]), epsilon: epsilon)

            // Combine results (remove duplicate middle point)
            return left + right.dropFirst()
        } else {
            // All points in between can be removed
            return [points[0], points[end]]
        }
    }

    private func perpendicularDistance(point: LocationData, lineStart: LocationData, lineEnd: LocationData) -> Double {
        // Calculate perpendicular distance from point to line
        let x0 = point.latitude
        let y0 = point.longitude
        let x1 = lineStart.latitude
        let y1 = lineStart.longitude
        let x2 = lineEnd.latitude
        let y2 = lineEnd.longitude

        let numerator = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(pow(y2 - y1, 2) + pow(x2 - x1, 2))

        if denominator == 0 {
            return calculateDistance(point1: point, point2: lineStart)
        }

        // Convert to meters (rough approximation)
        let degreesToMeters = 111319.9 // meters per degree at equator
        return (numerator / denominator) * degreesToMeters
    }
}

// MARK: - Spatial Grid for Efficient Proximity Queries

class SpatialGrid {
    private static let cellSize: Double = 50.0 // 50 meters per cell

    private var grid: [GridCell: [Int]] = [:]

    struct GridCell: Hashable {
        let x: Int
        let y: Int
    }

    func insert(point: LocationData, index: Int) {
        let cell = getCell(point: point)
        grid[cell, default: []].append(index)
    }

    func findNearbyPoints(point: LocationData, radius: Double) -> [Int] {
        let centerCell = getCell(point: point)
        var nearbyIndices: [Int] = []

        // Check 3x3 grid of cells
        for dx in -1...1 {
            for dy in -1...1 {
                let cell = GridCell(x: centerCell.x + dx, y: centerCell.y + dy)
                if let indices = grid[cell] {
                    nearbyIndices.append(contentsOf: indices)
                }
            }
        }

        return nearbyIndices
    }

    private func getCell(point: LocationData) -> GridCell {
        // Convert lat/lon to approximate meters (rough calculation)
        let metersPerDegree = 111319.9
        let x = Int(point.latitude * metersPerDegree / Self.cellSize)
        let y = Int(point.longitude * metersPerDegree / Self.cellSize)
        return GridCell(x: x, y: y)
    }
}
