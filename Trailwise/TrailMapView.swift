import CoreLocation
import MapLibre
import SwiftUI

struct TrailMapView: UIViewRepresentable {
    @ObservedObject var model: TrailwiseModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: model.selectedStyle.url)
        map.setCenter(CLLocationCoordinate2D(latitude: 39, longitude: -98), zoomLevel: 3.6, animated: false)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.logoView.isHidden = false
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(map)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: TrailMapView
        weak var map: MLNMapView?

        init(_ parent: TrailMapView) { self.parent = parent }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let map, parent.model.isPlanning, recognizer.state == .ended else { return }
            let point = recognizer.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            parent.model.addPoint(TrailCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) { render(mapView) }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let bounds = mapView.visibleCoordinateBounds
            parent.model.updateBounds(MapBounds(north: bounds.ne.latitude, east: bounds.ne.longitude, south: bounds.sw.latitude, west: bounds.sw.longitude))
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? { nil }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            if let line = annotation as? MLNPolyline, line.title == "trail" { return UIColor(red: 0.72, green: 0.30, blue: 0.18, alpha: 0.78) }
            return UIColor(red: 0.13, green: 0.48, blue: 0.83, alpha: 0.98)
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
            annotation.title == "trail" ? 2.4 : 5
        }

        func render(_ mapView: MLNMapView) {
            guard mapView.style != nil else { return }
            if mapView.styleURL != parent.model.selectedStyle.url { mapView.styleURL = parent.model.selectedStyle.url; return }
            mapView.removeAnnotations(mapView.annotations ?? [])
            mapView.removeOverlays(mapView.overlays)

            let features = parent.model.features.filter { parent.model.enabledKinds.contains($0.kind) }
            for feature in features {
                if feature.kind == .trail, feature.path.count > 1, let line = makePolyline(feature.path) {
                    line.title = "trail"
                    mapView.add(line)
                }
                if let coordinate = feature.coordinate {
                    let pin = MLNPointAnnotation()
                    pin.coordinate = coordinate.clLocation
                    pin.title = feature.name
                    pin.subtitle = feature.kind.rawValue
                    mapView.addAnnotation(pin)
                }
            }

            if parent.model.route.points.count > 1, let line = makePolyline(parent.model.route.points) {
                line.title = "route"
                mapView.add(line)
            }
            for (index, point) in parent.model.route.points.enumerated() {
                let pin = MLNPointAnnotation()
                pin.coordinate = point.clLocation
                pin.title = index == 0 ? "Start" : (index == parent.model.route.points.count - 1 ? "Finish" : "Waypoint \(index + 1)")
                mapView.addAnnotation(pin)
            }
        }

        private func makePolyline(_ points: [TrailCoordinate]) -> MLNPolyline? {
            let coordinates = points.map(\.clLocation)
            guard coordinates.count > 1 else { return nil }
            return coordinates.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return nil }
                return MLNPolyline(coordinates: baseAddress, count: UInt(buffer.count))
            }
        }
    }
}

