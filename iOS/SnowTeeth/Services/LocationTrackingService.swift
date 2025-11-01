//
//  LocationTrackingService.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation
import CoreLocation
import Combine

class LocationTrackingService: NSObject, ObservableObject {
    @Published var currentLocation: LocationData?
    @Published var currentBucket: VelocityBucket = .idle
    @Published var isTracking: Bool = false

    private let locationManager = CLLocationManager()
    private let gpxWriter = GpxWriter()
    private var velocityCalculator: VelocityCalculator
    private let prefs: AppPreferences
    private var velocitySmoother: VelocitySmoother
    private var elevationSmoother: ElevationSmoother

    var previousLocation: LocationData?
    private var locationUpdateCounter = 0
    private var locationUpdateTimer: Timer?
    private var velocityLogTimer: Timer?
    private var smoothedVelocityMPS: Float = 0.0

    private static let gpxWriteInterval = 1 // Write every location update for 1-second resolution

    init(prefs: AppPreferences) {
        self.prefs = prefs
        self.velocityCalculator = VelocityCalculator(prefs: prefs)
        self.velocitySmoother = VelocitySmoother(config: .skiing(useMetric: prefs.useMetric))
        // Elevation smoother uses adaptive smoothing: conservative for noise, responsive for trends
        self.elevationSmoother = ElevationSmoother(config: .standard())
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone  // Report all updates, don't filter by distance
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }

    func requestLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking(resetData: Bool = true) {
        guard !isTracking else { return }

        isTracking = true
        prefs.isTracking = true
        locationUpdateCounter = 0

        // Only reset the GPX file if requested
        if resetData {
            do {
                try gpxWriter.startNewTrack()
            } catch {
                errorLog("Error starting GPX track: \(error)")
            }
            // Reset velocity and elevation smoothers for new tracking session
            velocitySmoother.reset()
            elevationSmoother.reset()
        } else {
            // Continuing with existing data - ensure file exists
            if !gpxWriter.hasTrack() {
                do {
                    try gpxWriter.startNewTrack()
                } catch {
                    errorLog("Error creating GPX track: \(error)")
                }
            }
        }

        locationManager.startUpdatingLocation()
        startVelocityLogging()
    }

    func stopTracking() {
        guard isTracking else { return }

        isTracking = false
        prefs.isTracking = false

        locationManager.stopUpdatingLocation()
        gpxWriter.finalizeTrack()
        stopVelocityLogging()
    }

    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    func hasGpxTrack() -> Bool {
        return gpxWriter.hasTrack()
    }

    func getGpxFileURL() -> URL {
        return gpxWriter.getGpxFileURL()
    }

    func getGpxStatisticsSummary() -> String {
        return gpxWriter.getStatisticsSummary(useMetric: prefs.useMetric)
    }

    func resetGpxTrack() throws {
        try gpxWriter.deleteTrack()
    }

    private func startVelocityLogging() {
        #if DEBUG
        velocityLogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let location = self.currentLocation else { return }

            let rawSpeedMPS = location.speed
            let rawVelocityMPH = rawSpeedMPS * 2.23694
            let rawVelocityKPH = rawSpeedMPS * 3.6

            let smoothedSpeedMPS = Double(self.smoothedVelocityMPS)
            let smoothedVelocityMPH = smoothedSpeedMPS * 2.23694
            let smoothedVelocityKPH = smoothedSpeedMPS * 3.6

            // Calculate direction
            let direction: String
            if let prevLocation = self.previousLocation {
                let elevationChange = location.altitude - prevLocation.altitude
                direction = elevationChange < 0 ? "downhill" : "uphill"
            } else {
                direction = "unknown"
            }

            // Calculate bucket percentage (where in the bucket range we are)
            let bucketInfo: String
            if self.prefs.visualizationStyle == .flame {
                let bucket = self.currentBucket
                let speedMph = Float(smoothedSpeedMPS) / 0.44704

                let lowerThreshold: Float
                let upperThreshold: Float

                switch bucket {
                case .idle:
                    bucketInfo = "IDLE (0%)"
                case .downhillEasy, .uphillEasy:
                    lowerThreshold = direction == "downhill" ? self.prefs.downhillEasyThreshold : self.prefs.uphillEasyThreshold
                    upperThreshold = direction == "downhill" ? self.prefs.downhillMediumThreshold : self.prefs.uphillMediumThreshold
                    let percentage = max(0, min(100, (speedMph - lowerThreshold) / (upperThreshold - lowerThreshold) * 100.0))
                    bucketInfo = "EASY (\(String(format: "%.0f", percentage))%)"
                case .downhillMedium, .uphillMedium:
                    lowerThreshold = direction == "downhill" ? self.prefs.downhillMediumThreshold : self.prefs.uphillMediumThreshold
                    upperThreshold = direction == "downhill" ? self.prefs.downhillHardThreshold : self.prefs.uphillHardThreshold
                    let percentage = max(0, min(100, (speedMph - lowerThreshold) / (upperThreshold - lowerThreshold) * 100.0))
                    bucketInfo = "MEDIUM (\(String(format: "%.0f", percentage))%)"
                case .downhillHard, .uphillHard:
                    bucketInfo = "HARD (100%)"
                }
            } else {
                bucketInfo = "N/A"
            }

            if self.prefs.useMetric {
                debugLog("Velocity: raw=\(String(format: "%.1f", rawVelocityKPH)) km/h, smoothed=\(String(format: "%.1f", smoothedVelocityKPH)) km/h, direction=\(direction), bucket=\(bucketInfo)")
            } else {
                debugLog("Velocity: raw=\(String(format: "%.1f", rawVelocityMPH)) mph, smoothed=\(String(format: "%.1f", smoothedVelocityMPH)) mph, direction=\(direction), bucket=\(bucketInfo)")
            }
        }
        #endif
    }

    private func stopVelocityLogging() {
        velocityLogTimer?.invalidate()
        velocityLogTimer = nil
    }
}

extension LocationTrackingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let rawLocationData = LocationData(from: location)

        // Apply velocity smoothing
        let rawSpeedMPS = rawLocationData.speed
        let rawSpeedInDisplayUnit = prefs.useMetric ? rawSpeedMPS * 3.6 : rawSpeedMPS * 2.23694
        let smoothedSpeed = velocitySmoother.addReading(Float(rawSpeedInDisplayUnit))
        // Convert back to m/s for internal use
        smoothedVelocityMPS = prefs.useMetric ? smoothedSpeed / 3.6 : smoothedSpeed / 2.23694

        // Apply adaptive elevation smoothing with accuracy filtering
        // The smoother handles both accuracy filtering and adaptive EMA internally
        let smoothedElevation = elevationSmoother.addReading(
            rawLocationData.altitude,
            verticalAccuracy: rawLocationData.verticalAccuracy
        )

        // Create location data with smoothed velocity and elevation for visualizations
        let smoothedLocationData = LocationData(
            latitude: rawLocationData.latitude,
            longitude: rawLocationData.longitude,
            altitude: smoothedElevation,  // Use smoothed elevation
            timestamp: rawLocationData.timestamp,
            speed: Float(smoothedVelocityMPS),
            horizontalAccuracy: rawLocationData.horizontalAccuracy,
            verticalAccuracy: rawLocationData.verticalAccuracy
        )

        // Store smoothed location data for use by visualizations
        currentLocation = smoothedLocationData

        // Calculate velocity bucket using smoothed velocity
        currentBucket = velocityCalculator.calculateBucket(
            currentLocation: smoothedLocationData,
            previousLocation: previousLocation
        )

        // Write to GPX file every N seconds (use raw data for accurate GPS tracks)
        if isTracking {
            locationUpdateCounter += 1
            if locationUpdateCounter >= Self.gpxWriteInterval {
                do {
                    try gpxWriter.appendPoint(location: rawLocationData)  // Raw data with raw elevation
                    locationUpdateCounter = 0
                } catch {
                    errorLog("Error appending point to GPX: \(error)")
                }
            }
        }

        previousLocation = smoothedLocationData
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorLog("Location manager failed with error: \(error)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break // Permission granted
        case .denied, .restricted:
            warningLog("Location permission denied")
        case .notDetermined:
            break // Not determined yet
        @unknown default:
            break
        }
    }
}
