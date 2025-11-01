//
//  GpxWriter.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation
import CoreLocation

class GpxWriter {
    private static let gpxFileName = "snowteeth_track.gpx"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private var gpxFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(Self.gpxFileName)
    }

    // Track statistics
    private var previousLocation: LocationData?
    private var secondPreviousLocation: LocationData?
    private var downhillDistance: Double = 0.0  // meters
    private var downhillVelocitySum: Double = 0.0  // m/s
    private var downhillMovingPointCount: Int = 0  // Only points with speed > threshold
    private var uphillDistance: Double = 0.0  // meters
    private var uphillVelocitySum: Double = 0.0  // m/s
    private var uphillMovingPointCount: Int = 0  // Only points with speed > threshold

    // Minimum speed threshold to be considered "moving" (0.5 m/s ≈ 1.1 mph ≈ 1.8 km/h)
    private let minimumMovingSpeed: Double = 0.5

    /// Starts a new GPX track file
    func startNewTrack() throws {
        // Reset statistics
        previousLocation = nil
        secondPreviousLocation = nil
        downhillDistance = 0.0
        downhillVelocitySum = 0.0
        downhillMovingPointCount = 0
        uphillDistance = 0.0
        uphillVelocitySum = 0.0
        uphillMovingPointCount = 0

        let header = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="SnowTeeth"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <trk>
            <name>SnowTeeth Track</name>
            <trkseg>

        """
        try header.write(to: gpxFileURL, atomically: true, encoding: .utf8)
    }

    /// Appends a location point to the GPX file
    /// If the new point is at the same lat/lon as the two previous points,
    /// removes the previous point (middle of three identical points)
    func appendPoint(location: LocationData) throws {
        let fileURL = gpxFileURL

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try startNewTrack()
        }

        // Check if we should remove the previous point (redundant stationary point)
        let shouldRemovePrevious = previousLocation != nil &&
                                   secondPreviousLocation != nil &&
                                   location.latitude == previousLocation!.latitude &&
                                   location.longitude == previousLocation!.longitude &&
                                   previousLocation!.latitude == secondPreviousLocation!.latitude &&
                                   previousLocation!.longitude == secondPreviousLocation!.longitude

        // Calculate statistics if we have a previous location
        if let prev = previousLocation {
            // Calculate distance between points using Haversine formula
            let prevCLLocation = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
            let currCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = currCLLocation.distance(from: prevCLLocation) // meters

            // Determine if downhill or uphill
            let elevationChange = location.altitude - prev.altitude

            if elevationChange < 0 {
                // Downhill
                downhillDistance += distance
                // Only include velocity in average if moving (speed > threshold)
                if Double(location.speed) > minimumMovingSpeed {
                    downhillVelocitySum += Double(location.speed)
                    downhillMovingPointCount += 1
                }
            } else {
                // Uphill (includes flat)
                uphillDistance += distance
                // Only include velocity in average if moving (speed > threshold)
                if Double(location.speed) > minimumMovingSpeed {
                    uphillVelocitySum += Double(location.speed)
                    uphillMovingPointCount += 1
                }
            }
        }

        // Update location history
        secondPreviousLocation = previousLocation
        previousLocation = location

        // Read existing content
        var content = try String(contentsOf: fileURL, encoding: .utf8)

        // Remove closing tags
        content = content
            .replacingOccurrences(of: "    </trkseg>", with: "")
            .replacingOccurrences(of: "  </trk>", with: "")
            .replacingOccurrences(of: "</gpx>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If we should remove the previous point, find and remove the last <trkpt>...</trkpt> block
        if shouldRemovePrevious {
            if let lastTrkptStart = content.range(of: "<trkpt", options: .backwards)?.lowerBound {
                if let lastTrkptEnd = content.range(of: "</trkpt>", options: [], range: lastTrkptStart..<content.endIndex)?.upperBound {
                    // Remove the last trkpt block
                    content = String(content[..<lastTrkptStart]) + String(content[lastTrkptEnd...])
                    content = content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Create new point
        let date = Date(timeIntervalSince1970: TimeInterval(location.timestamp) / 1000.0)
        let timestamp = Self.dateFormatter.string(from: date)
        let newPoint = """
              <trkpt lat="\(location.latitude)" lon="\(location.longitude)">
                <ele>\(location.altitude)</ele>
                <time>\(timestamp)</time>
              </trkpt>
        """

        // Write back with new point and closing tags
        let updatedContent = content + "\n" + newPoint + "\n" + """
                </trkseg>
              </trk>
            </gpx>
        """

        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Finalizes the GPX file
    func finalizeTrack() {
        // File is already properly formatted with closing tags after each append
        // This method exists for API completeness
    }

    /// Returns the GPX file URL for reading
    func getGpxFileURL() -> URL {
        return gpxFileURL
    }

    /// Checks if a GPX file exists
    func hasTrack() -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: gpxFileURL.path) else {
            return false
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: gpxFileURL.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            return fileSize > 0
        } catch {
            return false
        }
    }

    /// Deletes the current GPX file
    func deleteTrack() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: gpxFileURL.path) {
            try fileManager.removeItem(at: gpxFileURL)
        }
    }

    /// Generates a statistics summary for sharing
    func getStatisticsSummary(useMetric: Bool) -> String {
        // Calculate average velocity only from moving points (excludes stationary periods)
        let downhillAvgVelocity = downhillMovingPointCount > 0 ? downhillVelocitySum / Double(downhillMovingPointCount) : 0.0
        let uphillAvgVelocity = uphillMovingPointCount > 0 ? uphillVelocitySum / Double(uphillMovingPointCount) : 0.0

        if useMetric {
            // Convert to km and km/h
            let downhillDistanceKm = downhillDistance / 1000.0
            let uphillDistanceKm = uphillDistance / 1000.0
            let downhillAvgVelocityKph = downhillAvgVelocity * 3.6
            let uphillAvgVelocityKph = uphillAvgVelocity * 3.6

            return String(format: "Downhill: %.2f km @ %.1f km/h\nUphill: %.2f km @ %.1f km/h",
                          downhillDistanceKm, downhillAvgVelocityKph,
                          uphillDistanceKm, uphillAvgVelocityKph)
        } else {
            // Convert to miles and mph
            let downhillDistanceMiles = downhillDistance / 1609.34
            let uphillDistanceMiles = uphillDistance / 1609.34
            let downhillAvgVelocityMph = downhillAvgVelocity * 2.23694
            let uphillAvgVelocityMph = uphillAvgVelocity * 2.23694

            return String(format: "Downhill: %.2f mi @ %.1f mph\nUphill: %.2f mi @ %.1f mph",
                          downhillDistanceMiles, downhillAvgVelocityMph,
                          uphillDistanceMiles, uphillAvgVelocityMph)
        }
    }
}
