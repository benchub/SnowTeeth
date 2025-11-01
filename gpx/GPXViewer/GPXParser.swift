import Foundation
import CoreLocation

class GPXParser: NSObject, XMLParserDelegate {
    private var points: [GPXPoint] = []
    private var currentElement = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var trackName: String?

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    func parse(data: Data) -> GPXData? {
        points = []
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            return nil
        }

        // Calculate speeds between consecutive points
        var pointsWithSpeed: [GPXPoint] = []
        for (index, point) in points.enumerated() {
            var speed: Double? = nil

            if index > 0 {
                let prevPoint = points[index - 1]
                let distance = calculateDistance(
                    from: prevPoint.coordinate,
                    to: point.coordinate
                )
                let timeDiff = point.time.timeIntervalSince(prevPoint.time)

                if timeDiff > 0 {
                    speed = distance / timeDiff // meters per second
                }
            }

            pointsWithSpeed.append(GPXPoint(
                coordinate: point.coordinate,
                elevation: point.elevation,
                time: point.time,
                speed: speed,
                cleanedSpeed: nil, // Will be calculated next
                smoothedSpeed: nil // Will be calculated after that
            ))
        }

        // Smooth velocities using spike rejection and EMA
        let rawSpeeds = pointsWithSpeed.map { $0.speed }
        let velocitySmootherConfig = TimeSeriesSmoothing.VelocitySmootherConfig(
            absoluteMaxValue: 30.0, // 30 m/s = 108 km/h = 67 mph (realistic max for skiing)
            spikeMultiplier: 3.0,   // Allow 3× speed increases before rejection
            minValueThreshold: 0.45, // ~1 mph (1.6 km/h) - preserve stops
            alpha: 0.6              // 60% weight to new reading, 40% to history
        )
        let smoothedSpeeds = TimeSeriesSmoothing.smoothVelocities(rawSpeeds, config: velocitySmootherConfig)

        // Estimate vertical accuracy based on elevation variance in surrounding points
        let verticalAccuracies: [Double?] = pointsWithSpeed.enumerated().map { index, point in
            return estimateVerticalAccuracy(at: index, in: pointsWithSpeed)
        }

        // Smooth elevations using accuracy filtering and adaptive EMA
        let rawElevations = pointsWithSpeed.map { Optional($0.elevation) }
        let elevationSmootherConfig = TimeSeriesSmoothing.ElevationSmootherConfig(
            verticalAccuracyThreshold: 20.0, // Reject only obvious spikes (marked as 25+ by our detector)
            alphaMin: 0.25,                   // Moderate smoothing for noise
            alphaMax: 0.75,                   // Responsive for trends but not too aggressive
            trendWindow: 5                    // Look at 5 recent readings for trend detection
        )
        let smoothedElevations = TimeSeriesSmoothing.smoothElevations(
            rawElevations,
            verticalAccuracies: verticalAccuracies,
            config: elevationSmootherConfig
        )

        // Store points with both raw and smoothed speeds/elevations
        var finalPoints: [GPXPoint] = []
        for (index, point) in pointsWithSpeed.enumerated() {
            finalPoints.append(GPXPoint(
                coordinate: point.coordinate,
                elevation: point.elevation,
                time: point.time,
                speed: point.speed,
                cleanedSpeed: nil, // No longer used
                smoothedSpeed: smoothedSpeeds[index],
                smoothedElevation: smoothedElevations[index]
            ))
        }

        let gpxData = GPXData(points: finalPoints, name: trackName)

        return gpxData
    }

    /// Estimates vertical accuracy based on the pattern of elevation changes.
    /// Distinguishes between GPS spikes (sudden changes that reverse) vs real hills (consistent trends).
    ///
    /// - Parameters:
    ///   - index: Index of the point to estimate accuracy for
    ///   - points: Array of all GPX points
    /// - Returns: Estimated vertical accuracy in meters
    private func estimateVerticalAccuracy(at index: Int, in points: [GPXPoint]) -> Double {
        // Edge cases: start and end of track often have poor accuracy
        if index < 3 || index >= points.count - 3 {
            return 20.0
        }

        // Look at recent elevation changes to detect spikes vs trends
        let prevElevations = [
            points[max(0, index - 3)].elevation,
            points[max(0, index - 2)].elevation,
            points[index - 1].elevation,
            points[index].elevation
        ]

        // Calculate changes
        var changes: [Double] = []
        for i in 1..<prevElevations.count {
            changes.append(prevElevations[i] - prevElevations[i-1])
        }

        // Detect spike pattern: large change that reverses
        // Example: [+10, -9, +1] = spike up then back down
        if changes.count >= 2 {
            let lastChange = changes[changes.count - 1]
            let secondLastChange = changes[changes.count - 2]

            // Large change (>3m) that reverses direction (opposite sign)
            if abs(lastChange) > 3.0 && abs(secondLastChange) > 3.0 {
                if (lastChange > 0 && secondLastChange < 0) || (lastChange < 0 && secondLastChange > 0) {
                    return 30.0  // GPS spike detected
                }
            }
        }

        // Check for oscillating pattern (back and forth)
        if changes.count >= 3 {
            let signs = changes.map { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }
            // If signs alternate (1, -1, 1) or (-1, 1, -1), it's oscillating noise
            if signs[0] != 0 && signs[1] != 0 && signs[2] != 0 {
                if signs[0] != signs[1] && signs[1] != signs[2] {
                    return 25.0  // Oscillating noise
                }
            }
        }

        // Look at small local window for micro-jitter
        let smallWindow = 5
        let start = max(0, index - smallWindow / 2)
        let end = min(points.count, index + smallWindow / 2 + 1)
        let localElevations = Array(points[start..<end]).map { $0.elevation }

        if localElevations.count > 2 {
            let mean = localElevations.reduce(0, +) / Double(localElevations.count)
            let deviations = localElevations.map { abs($0 - mean) }
            let maxDeviation = deviations.max() ?? 0

            // Small oscillations around a point (< 1m) suggest stationary jitter
            if maxDeviation < 1.0 && deviations.filter({ $0 > 0.5 }).count > 2 {
                return 15.0  // Minor jitter
            }
        }

        // If we get here, the pattern looks like legitimate elevation change
        return 8.0  // Good accuracy - accept the reading
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "trkpt":
            if let latStr = attributeDict["lat"], let lat = Double(latStr),
               let lonStr = attributeDict["lon"], let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
            }
        case "name":
            break
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "ele":
            currentEle = Double(trimmed)
        case "time":
            currentTime = dateFormatter.date(from: trimmed)
        case "name":
            if trackName == nil {
                trackName = trimmed
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trkpt" {
            if let lat = currentLat, let lon = currentLon,
               let ele = currentEle, let time = currentTime {
                let point = GPXPoint(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    elevation: ele,
                    time: time,
                    speed: nil, // Will be calculated after parsing
                    cleanedSpeed: nil, // Will be calculated after parsing
                    smoothedSpeed: nil // Will be calculated after parsing
                )
                points.append(point)
            }

            // Reset current values
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentTime = nil
        }

        currentElement = ""
    }
}
