import Foundation
import CoreLocation

enum UnitSystem {
    case metric
    case imperial

    func convertElevation(_ meters: Double) -> Double {
        switch self {
        case .metric:
            return meters
        case .imperial:
            return meters * 3.28084 // meters to feet
        }
    }

    func convertSpeed(_ metersPerSecond: Double) -> Double {
        switch self {
        case .metric:
            return metersPerSecond * 3.6 // m/s to km/h
        case .imperial:
            return metersPerSecond * 2.23694 // m/s to mph
        }
    }

    var elevationUnit: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }

    var speedUnit: String {
        switch self {
        case .metric: return "km/h"
        case .imperial: return "mph"
        }
    }
}

struct GPXPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let elevation: Double // in meters (raw)
    let time: Date
    let speed: Double? // in meters per second (raw/instantaneous)
    let cleanedSpeed: Double? // Deprecated - no longer used
    var smoothedSpeed: Double? // in meters per second (spike rejection + EMA)
    var smoothedElevation: Double? // in meters (accuracy filtering + EMA)
}

struct GPXData {
    var points: [GPXPoint]
    let name: String?

    var elevationRange: ClosedRange<Double> {
        guard !points.isEmpty else { return 0...0 }
        let elevations = points.map { $0.elevation }
        return (elevations.min() ?? 0)...(elevations.max() ?? 0)
    }

    var speedRange: ClosedRange<Double> {
        let speeds = points.compactMap { $0.speed }
        guard !speeds.isEmpty else { return 0...0 }
        return (speeds.min() ?? 0)...(speeds.max() ?? 0)
    }

    var timeRange: ClosedRange<Date> {
        guard !points.isEmpty else {
            let now = Date()
            return now...now
        }
        return points.first!.time...points.last!.time
    }

    var bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !points.isEmpty else { return (0, 0, 0, 0) }
        let lats = points.map { $0.coordinate.latitude }
        let lons = points.map { $0.coordinate.longitude }
        return (
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLon: lons.min() ?? 0,
            maxLon: lons.max() ?? 0
        )
    }

}
