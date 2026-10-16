import CoreLocation
import Foundation

struct TrailCoordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: TrailCoordinate) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

struct SavedRoute: Codable, Identifiable {
    var id = UUID()
    var name = "Untitled hike"
    var waypoints: [TrailCoordinate] = []
    var points: [TrailCoordinate] = []
    var elevations: [ElevationSample] = []
    var updatedAt = Date()

    var distanceMeters: Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    var distanceKilometers: Double { distanceMeters / 1_000 }
    var waypointCount: Int { waypoints.isEmpty ? points.count : waypoints.count }
}

struct ElevationSample: Codable, Identifiable {
    var id = UUID()
    var distanceMeters: Double
    var elevationMeters: Double
}

struct OutdoorFeature: Identifiable, Hashable, Codable {
    enum Kind: String, CaseIterable, Codable {
        case campsite = "Campsites"
        case hut = "Huts"
        case water = "Water"
        case parking = "Parking"
        case viewpoint = "Viewpoints"
        case peak = "Peaks"
        case trail = "Trails"

        var symbol: String {
            switch self {
            case .campsite: return "tent.fill"
            case .hut: return "house.lodge.fill"
            case .water: return "drop.fill"
            case .parking: return "parkingsign.circle.fill"
            case .viewpoint: return "binoculars.fill"
            case .peak: return "mountain.2.fill"
            case .trail: return "figure.hiking"
            }
        }

        var color: String {
            switch self {
            case .campsite: return "#198754"
            case .hut: return "#A0522D"
            case .water: return "#2386C8"
            case .parking: return "#6B7280"
            case .viewpoint: return "#D97706"
            case .peak: return "#7654B5"
            case .trail: return "#B65032"
            }
        }
    }

    var id: String
    var name: String
    var kind: Kind
    var coordinate: TrailCoordinate?
    var path: [TrailCoordinate] = []
}

struct MapBounds {
    var north: Double
    var east: Double
    var south: Double
    var west: Double

    var overpassString: String { "\(south),\(west),\(north),\(east)" }
    var isRegional: Bool { north - south < 1.8 && east - west < 2.2 }

    var approximateTileCount: Int {
        func x(_ longitude: Double, _ zoom: Int) -> Int {
            Int(floor((longitude + 180) / 360 * pow(2, Double(zoom))))
        }
        func y(_ latitude: Double, _ zoom: Int) -> Int {
            let lat = min(85.0511, max(-85.0511, latitude)) * .pi / 180
            let value = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2
            return Int(floor(value * pow(2, Double(zoom))))
        }
        return (10...15).reduce(0) { total, zoom in
            let width = max(1, x(east, zoom) - x(west, zoom) + 1)
            let height = max(1, y(south, zoom) - y(north, zoom) + 1)
            return total + width * height
        }
    }
}

enum OutdoorMapStyle: String, CaseIterable, Identifiable {
    case liberty = "Outdoors"
    case bright = "Light"
    case positron = "Simple"
    case dark = "Dark"

    var id: String { rawValue }
    var url: URL { URL(string: "https://tiles.openfreemap.org/styles/\(styleID)")! }

    private var styleID: String {
        switch self {
        case .liberty: return "liberty"
        case .bright: return "bright"
        case .positron: return "positron"
        case .dark: return "dark"
        }
    }
}

