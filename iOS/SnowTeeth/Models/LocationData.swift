//
//  LocationData.swift
//  SnowTeeth
//
//  Created by SnowTeeth
//

import Foundation
import CoreLocation

struct LocationData: Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Int64
    let speed: Float // meters per second
    let horizontalAccuracy: Double // meters
    let verticalAccuracy: Double // meters

    init(latitude: Double, longitude: Double, altitude: Double, timestamp: Int64, speed: Float, horizontalAccuracy: Double = -1.0, verticalAccuracy: Double = -1.0) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
    }

    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = Int64(location.timestamp.timeIntervalSince1970 * 1000) // Convert to milliseconds
        self.speed = Float(max(0, location.speed)) // Ensure non-negative
        self.horizontalAccuracy = location.horizontalAccuracy
        self.verticalAccuracy = location.verticalAccuracy
    }
}
