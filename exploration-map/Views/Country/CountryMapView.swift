import MapKit
import SwiftUI

struct CountryMapView: UIViewRepresentable {
    var store: CountryStore
    @Binding var selectedCountry: CountrySelection?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = true
        mapView.isRotateEnabled = false

        let world = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
        )
        mapView.setRegion(world, animated: false)
        mapView.addOverlays(store.overlays)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapRecognizer)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if context.coordinator.lastRevision != store.revision {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlays(store.overlays)
            context.coordinator.lastRevision = store.revision
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CountryMapView
        var lastRevision: Int = -1

        init(parent: CountryMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let status = parent.store.status(for: polygon.title ?? "")
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = parent.store.fillColor(for: status)
            renderer.strokeColor = parent.store.strokeColor(for: status)
            renderer.lineWidth = 1.0
            return renderer
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended,
                  let mapView = gesture.view as? MKMapView else {
                return
            }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)

            for overlay in mapView.overlays {
                guard let polygon = overlay as? MKPolygon else { continue }
                if polygonContains(mapPoint, in: polygon) {
                    let countryId = polygon.title ?? "Unknown"
                    let name = parent.store.displayName(for: countryId)
                    Haptics.mediumImpact()
                    parent.selectedCountry = CountrySelection(id: countryId, name: name)
                    return
                }
            }
        }

        private func polygonContains(_ mapPoint: MKMapPoint, in polygon: MKPolygon) -> Bool {
            guard pointInPolygon(polygon, mapPoint: mapPoint) else { return false }
            if let interiors = polygon.interiorPolygons {
                for interior in interiors where pointInPolygon(interior, mapPoint: mapPoint) {
                    return false
                }
            }
            return true
        }

        private func pointInPolygon(_ polygon: MKPolygon, mapPoint: MKMapPoint) -> Bool {
            let count = polygon.pointCount
            guard count > 2 else { return false }

            let points = polygon.points()
            var isInside = false
            var j = count - 1

            for i in 0..<count {
                let pi = points[i]
                let pj = points[j]
                let dy = pj.y - pi.y
                guard abs(dy) > 1e-10 else { j = i; continue }
                let intersects = ((pi.y > mapPoint.y) != (pj.y > mapPoint.y)) &&
                    (mapPoint.x < (pj.x - pi.x) * (mapPoint.y - pi.y) / dy + pi.x)

                if intersects {
                    isInside.toggle()
                }
                j = i
            }

            return isInside
        }
    }
}
