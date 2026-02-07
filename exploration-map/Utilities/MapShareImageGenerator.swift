import MapKit
import UIKit

enum MapShareImageGenerator {
    private static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
    )

    private static let imageSize = CGSize(width: 1200, height: 800)
    private static let scale: CGFloat = 2
    private static let statsBarHeight: CGFloat = 160

    @MainActor
    static func generate(store: CountryStore) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = worldRegion
        options.size = imageSize
        options.scale = scale
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, error in
                Task { @MainActor in
                    guard let snapshot, error == nil else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let image = drawShareImage(snapshot: snapshot, store: store)
                    continuation.resume(returning: image)
                }
            }
        }
    }

    @MainActor
    static func generatePDF(store: CountryStore) async -> URL? {
        guard let image = await generate(store: store) else { return nil }
        let size = image.size
        let bounds = CGRect(origin: .zero, size: size)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ExplorationMap-\(UUID().uuidString).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        do {
            try renderer.writePDF(to: tempURL) { context in
                context.beginPage()
                image.draw(in: bounds)
            }
            return tempURL
        } catch {
            return nil
        }
    }

    @MainActor
    private static func drawShareImage(snapshot: MKMapSnapshotter.Snapshot, store: CountryStore) -> UIImage? {
        let snapshotSize = snapshot.image.size
        let size = (snapshotSize.width > 0 && snapshotSize.height > 0)
            ? snapshotSize
            : imageSize
        var format = UIGraphicsImageRendererFormat.default()
        format.scale = (snapshotSize.width > 0 && snapshotSize.height > 0) ? scale : 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            if snapshotSize.width > 0, snapshotSize.height > 0 {
                snapshot.image.draw(in: rect)
                for overlay in store.overlays {
                    guard let polygon = overlay as? MKPolygon else { continue }
                    let countryId = polygon.title ?? ""
                    let status = store.status(for: countryId)
                    drawPolygon(polygon, on: snapshot, in: context.cgContext, fillColor: store.fillColor(for: status), strokeColor: store.strokeColor(for: status))
                }
            } else {
                UIColor.systemGray.withAlphaComponent(0.25).setFill()
                context.fill(rect)
            }
            drawStatsBar(in: rect, context: context.cgContext, store: store)
        }
    }

    private static func drawPolygon(_ polygon: MKPolygon, on snapshot: MKMapSnapshotter.Snapshot, in ctx: CGContext, fillColor: UIColor, strokeColor: UIColor) {
        let points = polygon.points()
        let count = polygon.pointCount
        guard count > 2 else { return }

        let path = CGMutablePath()
        let firstCoord = MKMapPoint(x: points[0].x, y: points[0].y).coordinate
        let firstPoint = snapshot.point(for: firstCoord)
        path.move(to: firstPoint)

        for i in 1..<count {
            let coord = MKMapPoint(x: points[i].x, y: points[i].y).coordinate
            let point = snapshot.point(for: coord)
            path.addLine(to: point)
        }
        path.closeSubpath()

        if let interiors = polygon.interiorPolygons {
            for interior in interiors {
                let innerPoints = interior.points()
                let innerCount = interior.pointCount
                guard innerCount > 2 else { continue }
                let innerFirst = MKMapPoint(x: innerPoints[0].x, y: innerPoints[0].y).coordinate
                path.move(to: snapshot.point(for: innerFirst))
                for i in 1..<innerCount {
                    let coord = MKMapPoint(x: innerPoints[i].x, y: innerPoints[i].y).coordinate
                    path.addLine(to: snapshot.point(for: coord))
                }
                path.closeSubpath()
            }
        }

        ctx.addPath(path)
        ctx.setFillColor(fillColor.cgColor)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(1)
        ctx.drawPath(using: .eoFillStroke)
    }

    private static func drawStatsBar(in rect: CGRect, context ctx: CGContext, store: CountryStore) {
        let barRect = CGRect(x: 0, y: rect.maxY - statsBarHeight, width: rect.width, height: statsBarHeight)
        let gradientColors = [UIColor.black.withAlphaComponent(0.75).cgColor, UIColor.black.withAlphaComponent(0.9).cgColor]
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors as CFArray, locations: [0, 1]) else { return }
        ctx.saveGState()
        ctx.clip(to: barRect)
        ctx.drawLinearGradient(gradient, start: CGPoint(x: barRect.midX, y: barRect.minY), end: CGPoint(x: barRect.midX, y: barRect.maxY), options: [])
        ctx.restoreGState()

        let center = NSMutableParagraphStyle()
        center.alignment = .center
        let lineSpacing: CGFloat = 6

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white,
            .paragraphStyle: center
        ]
        let title = "Exploration map"
        let titleSize = (title as NSString).size(withAttributes: titleAttrs)

        let mainFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let mainAttrs: [NSAttributedString.Key: Any] = [
            .font: mainFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            .paragraphStyle: center
        ]
        let mainText = "\(store.visitedCount) visited · \(String(format: "%.1f", store.visitedPercentage * 100))% of world · \(store.wantToVisitCount) want to visit"
        let mainSize = (mainText as NSString).size(withAttributes: mainAttrs)

        let subFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: subFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            .paragraphStyle: center
        ]
        let subText = "\(store.totalCountries) countries total"
        let subSize = (subText as NSString).size(withAttributes: subAttrs)

        let continentParts = store.continentStats.map { "\($0.name) \(String(format: "%.1f", $0.percentage * 100))%" }
        let continentText = continentParts.joined(separator: " · ")
        let continentFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let continentAttrs: [NSAttributedString.Key: Any] = [
            .font: continentFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.8),
            .paragraphStyle: center
        ]
        let continentSize = continentText.isEmpty ? .zero : (continentText as NSString).size(withAttributes: continentAttrs)

        var totalTextHeight = titleSize.height + lineSpacing + mainSize.height + lineSpacing + subSize.height
        if !continentText.isEmpty {
            totalTextHeight += lineSpacing + continentSize.height
        }
        var y = barRect.midY - totalTextHeight / 2

        (title as NSString).draw(in: CGRect(x: barRect.minX, y: y, width: barRect.width, height: titleSize.height), withAttributes: titleAttrs)
        y += titleSize.height + lineSpacing
        (mainText as NSString).draw(in: CGRect(x: barRect.minX, y: y, width: barRect.width, height: mainSize.height), withAttributes: mainAttrs)
        y += mainSize.height + lineSpacing
        (subText as NSString).draw(in: CGRect(x: barRect.minX, y: y, width: barRect.width, height: subSize.height), withAttributes: subAttrs)
        if !continentText.isEmpty {
            y += subSize.height + lineSpacing
            (continentText as NSString).draw(in: CGRect(x: barRect.minX, y: y, width: barRect.width, height: continentSize.height), withAttributes: continentAttrs)
        }
    }
}
