//
//  StatsCalculator.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation

struct TrackStats {
    let verticalFeetUp: Double
    let verticalFeetDown: Double
    let horizontalDistance: Double
    let avgDownhillPace: Double  // Average velocity in display units (mph or km/h)
    let avgUphillPace: Double    // Average velocity in display units (mph or km/h)
    let movingTimeSeconds: Double

    /// Format moving time as HH:MM:SS (always shows hours for clarity)
    func formattedMovingTime() -> String {
        let hours = Int(movingTimeSeconds) / 3600
        let minutes = (Int(movingTimeSeconds) % 3600) / 60
        let secs = Int(movingTimeSeconds) % 60

        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
}

class StatsCalculator {
    // Conversion constants
    private static let metersToFeet: Double = 3.28084
    private static let metersToMiles: Double = 0.000621371
    private static let metersToKm: Double = 0.001
    private static let earthRadiusMeters: Double = 6371000.0
    private static let mpsToMph: Double = 2.23694
    private static let mpsToKph: Double = 3.6

    // Moving time threshold (speed above this is considered "moving")
    private static let movingSpeedThresholdMPH: Double = 1.0
    private static let movingSpeedThresholdKPH: Double = 1.6

    /// Calculates statistics from a list of location points
    func calculateStats(points: [LocationData], useMetric: Bool) -> TrackStats {
        if points.count < 2 {
            return TrackStats(verticalFeetUp: 0, verticalFeetDown: 0, horizontalDistance: 0, avgDownhillPace: 0, avgUphillPace: 0, movingTimeSeconds: 0)
        }

        var totalUp: Double = 0.0
        var totalDown: Double = 0.0
        var totalDistance: Double = 0.0

        // Track downhill and uphill distance and time for velocity calculation
        var downhillDistance: Double = 0.0  // meters
        var downhillTime: Double = 0.0      // seconds
        var uphillDistance: Double = 0.0    // meters
        var uphillTime: Double = 0.0        // seconds

        // Track moving time
        var movingTimeSeconds: Double = 0.0
        let movingSpeedThreshold = useMetric ? Self.movingSpeedThresholdKPH : Self.movingSpeedThresholdMPH

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]

            // Calculate horizontal distance
            let segmentDistance = calculateDistance(point1: prev, point2: curr)
            totalDistance += segmentDistance

            // Calculate time elapsed (timestamps are in milliseconds)
            let timeDelta = Double(curr.timestamp - prev.timestamp) / 1000.0  // seconds

            // Calculate elevation change
            let elevationChange = curr.altitude - prev.altitude

            // Calculate instantaneous speed for this segment
            let instantaneousSpeedMPS = timeDelta > 0 ? segmentDistance / timeDelta : 0.0
            let instantaneousSpeedDisplay = useMetric ? instantaneousSpeedMPS * Self.mpsToKph : instantaneousSpeedMPS * Self.mpsToMph

            // Track moving time (exclude stationary periods)
            if instantaneousSpeedDisplay > movingSpeedThreshold {
                movingTimeSeconds += timeDelta
            }

            // Track vertical gain/loss and velocity by direction
            if elevationChange < 0 {
                // Downhill
                totalDown += abs(elevationChange)
                downhillDistance += segmentDistance
                downhillTime += timeDelta
            } else {
                // Uphill (includes flat)
                totalUp += elevationChange
                uphillDistance += segmentDistance
                uphillTime += timeDelta
            }
        }

        // Calculate average velocities (distance / time) and convert to display units
        let avgDownhillVelocityMPS = downhillTime > 0 ? downhillDistance / downhillTime : 0.0
        let avgUphillVelocityMPS = uphillTime > 0 ? uphillDistance / uphillTime : 0.0

        // Convert m/s to mph or km/h
        let avgDownhillPace = useMetric ? avgDownhillVelocityMPS * Self.mpsToKph : avgDownhillVelocityMPS * Self.mpsToMph
        let avgUphillPace = useMetric ? avgUphillVelocityMPS * Self.mpsToKph : avgUphillVelocityMPS * Self.mpsToMph

        // Convert to appropriate units
        let verticalUp = totalUp * Self.metersToFeet
        let verticalDown = totalDown * Self.metersToFeet
        let horizontalDist = useMetric ? totalDistance * Self.metersToKm : totalDistance * Self.metersToMiles

        return TrackStats(
            verticalFeetUp: verticalUp,
            verticalFeetDown: verticalDown,
            horizontalDistance: horizontalDist,
            avgDownhillPace: avgDownhillPace,
            avgUphillPace: avgUphillPace,
            movingTimeSeconds: movingTimeSeconds
        )
    }

    /// Calculates distance between two points using Haversine formula
    private func calculateDistance(point1: LocationData, point2: LocationData) -> Double {
        let lat1Rad = point1.latitude * .pi / 180.0
        let lat2Rad = point2.latitude * .pi / 180.0
        let deltaLat = (point2.latitude - point1.latitude) * .pi / 180.0
        let deltaLon = (point2.longitude - point1.longitude) * .pi / 180.0

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return Self.earthRadiusMeters * c
    }

    /// Parses GPX file and returns list of location points
    func parseGpxFile(gpxContent: String) -> [LocationData] {
        var points: [LocationData] = []

        let trkptPattern = #"<trkpt lat="([^"]+)" lon="([^"]+)">"#
        let elePattern = #"<ele>([^<]+)</ele>"#
        let timePattern = #"<time>([^<]+)</time>"#

        guard let trkptRegex = try? NSRegularExpression(pattern: trkptPattern, options: []),
              let eleRegex = try? NSRegularExpression(pattern: elePattern, options: []),
              let timeRegex = try? NSRegularExpression(pattern: timePattern, options: []) else {
            return points
        }

        let lines = gpxContent.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            if let trkptMatch = trkptRegex.firstMatch(in: line, options: [], range: range) {
                let lat = Double(nsLine.substring(with: trkptMatch.range(at: 1))) ?? 0.0
                let lon = Double(nsLine.substring(with: trkptMatch.range(at: 2))) ?? 0.0

                var ele: Double = 0.0
                var time: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

                // Look ahead for ele and time tags
                for j in (i + 1)..<min(i + 5, lines.count) {
                    let lookAheadLine = lines[j]
                    let nsLookAhead = lookAheadLine as NSString
                    let lookAheadRange = NSRange(location: 0, length: nsLookAhead.length)

                    if let eleMatch = eleRegex.firstMatch(in: lookAheadLine, options: [], range: lookAheadRange) {
                        ele = Double(nsLookAhead.substring(with: eleMatch.range(at: 1))) ?? 0.0
                    }

                    if let timeMatch = timeRegex.firstMatch(in: lookAheadLine, options: [], range: lookAheadRange) {
                        let timeString = nsLookAhead.substring(with: timeMatch.range(at: 1))
                        time = parseIso8601(timestamp: timeString)
                    }
                }

                points.append(LocationData(latitude: lat, longitude: lon, altitude: ele, timestamp: time, speed: 0))
            }
            i += 1
        }

        return points
    }

    private func parseIso8601(timestamp: String) -> Int64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")

        if let date = formatter.date(from: timestamp) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }

        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
