import SwiftUI
import MapKit

struct MapView: View {
    let gpxData: GPXData
    @ObservedObject var coordinator: HoverCoordinator
    let unitSystem: UnitSystem
    @State private var mapRegion: MKCoordinateRegion
    @State private var hoverLocation: CGPoint?

    init(gpxData: GPXData, coordinator: HoverCoordinator, unitSystem: UnitSystem) {
        self.gpxData = gpxData
        self.coordinator = coordinator
        self.unitSystem = unitSystem

        // Calculate initial region
        let bounds = gpxData.bounds
        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLat + bounds.maxLat) / 2,
            longitude: (bounds.minLon + bounds.maxLon) / 2
        )

        let latDelta = (bounds.maxLat - bounds.minLat) * 1.2 // Add 20% padding
        let lonDelta = (bounds.maxLon - bounds.minLon) * 1.2

        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 0.01),
                longitudeDelta: max(lonDelta, 0.01)
            )
        ))
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))

            VStack(alignment: .leading, spacing: 4) {
                Text("Map")
                    .font(.headline)
                    .padding([.top, .leading], 8)

                MapViewRepresentable(
                    gpxData: gpxData,
                    region: $mapRegion,
                    hoveredPointIndex: coordinator.hoveredPointIndex,
                    unitSystem: unitSystem
                )
                .cornerRadius(6)
                .padding(8)
            }
        }
    }
}

// MARK: - MapKit Representable

struct MapViewRepresentable: NSViewRepresentable {
    let gpxData: GPXData
    @Binding var region: MKCoordinateRegion
    let hoveredPointIndex: Int?
    let unitSystem: UnitSystem

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .satellite
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)

        // Enable zoom and pan gestures
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true

        // Add the GPX path as an overlay
        let coordinates = gpxData.points.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Store initial point count
        context.coordinator.currentPointCount = gpxData.points.count

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Check if GPX data has changed
        if context.coordinator.currentPointCount != gpxData.points.count {
            // Remove old overlays
            mapView.removeOverlays(mapView.overlays)

            // Add new GPX path
            let coordinates = gpxData.points.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)

            // Calculate and set the new region directly from gpxData
            let bounds = (
                minLat: coordinates.map { $0.latitude }.min() ?? 0,
                maxLat: coordinates.map { $0.latitude }.max() ?? 0,
                minLon: coordinates.map { $0.longitude }.min() ?? 0,
                maxLon: coordinates.map { $0.longitude }.max() ?? 0
            )

            let center = CLLocationCoordinate2D(
                latitude: (bounds.minLat + bounds.maxLat) / 2,
                longitude: (bounds.minLon + bounds.maxLon) / 2
            )

            let latDelta = (bounds.maxLat - bounds.minLat) * 1.2
            let lonDelta = (bounds.maxLon - bounds.minLon) * 1.2

            let newRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(
                    latitudeDelta: max(latDelta, 0.01),
                    longitudeDelta: max(lonDelta, 0.01)
                )
            )

            // Update the region to show the new path
            mapView.setRegion(newRegion, animated: true)

            // Update stored point count
            context.coordinator.currentPointCount = gpxData.points.count
        }

        // Remove existing annotations
        mapView.removeAnnotations(mapView.annotations)

        // Add marker for hovered point
        if let index = hoveredPointIndex, index < gpxData.points.count {
            let point = gpxData.points[index]
            let annotation = MKPointAnnotation()
            annotation.coordinate = point.coordinate

            let convertedElevation = unitSystem.convertElevation(point.elevation)
            let convertedSpeed = unitSystem.convertSpeed(point.speed ?? 0)
            annotation.title = String(format: "%.0f%@, %.1f %@",
                                     convertedElevation,
                                     unitSystem.elevationUnit,
                                     convertedSpeed,
                                     unitSystem.speedUnit)
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentPointCount: Int = 0

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemRed
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "HoverMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = NSColor.systemRed
            }

            return annotationView
        }
    }
}
