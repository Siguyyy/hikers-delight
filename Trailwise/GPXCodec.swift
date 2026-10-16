import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum GPXCodec {
    static func encode(_ route: SavedRoute) -> Data {
        let title = escape(route.name)
        let points = route.points.map { point in
            String(format: "      <trkpt lat=\"%.7f\" lon=\"%.7f\"></trkpt>", point.latitude, point.longitude)
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Trailwise" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><name>\(title)</name><trkseg>
        \(points)
          </trkseg></trk>
        </gpx>
        """
        return Data(xml.utf8)
    }

    static func decode(_ data: Data) throws -> [TrailCoordinate] {
        let parser = XMLParser(data: data)
        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        guard parser.parse(), delegate.points.count > 1 else {
            throw NSError(domain: "Trailwise.GPX", code: 1, userInfo: [NSLocalizedDescriptionKey: "This GPX file does not contain a usable route."])
        }
        return delegate.points
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    var points: [TrailCoordinate] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        guard ["trkpt", "rtept"].contains(elementName),
              let latitude = Double(attributes["lat"] ?? ""),
              let longitude = Double(attributes["lon"] ?? "") else { return }
        points.append(TrailCoordinate(latitude: latitude, longitude: longitude))
    }
}

struct GPXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }
    var route: SavedRoute

    init(route: SavedRoute) { self.route = route }

    init(configuration: ReadConfiguration) throws {
        let points = try GPXCodec.decode(configuration.file.regularFileContents ?? Data())
        route = SavedRoute(name: "Imported hike", points: points)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: GPXCodec.encode(route))
    }
}
