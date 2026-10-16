import CoreLocation
import Foundation
import MapLibre

enum TrailServiceError: LocalizedError {
    case invalidResponse
    case noElevation
    case noMapArea

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The outdoor data service returned an unreadable response. Try again in a moment."
        case .noElevation: return "Elevation data is unavailable for this route right now. The route is still saved."
        case .noMapArea: return "Move and zoom the map to the area you want to download, then try again."
        }
    }
}

enum OutdoorDataService {
    private struct Response: Decodable {
        var elements: [Element]
    }

    private struct Element: Decodable {
        var type: String
        var id: Int64
        var lat: Double?
        var lon: Double?
        var center: Center?
        var geometry: [Point]?
        var tags: [String: String]?
    }

    private struct Center: Decodable { var lat: Double; var lon: Double }
    private struct Point: Decodable { var lat: Double; var lon: Double }

    static func fetch(bounds: MapBounds) async throws -> [OutdoorFeature] {
        let box = bounds.overpassString
        let query = """
        [out:json][timeout:25];
        (
          node["tourism"="camp_site"](\(box)); way["tourism"="camp_site"](\(box)); relation["tourism"="camp_site"](\(box));
          node["tourism"="alpine_hut"](\(box)); way["tourism"="alpine_hut"](\(box));
          node["amenity"="drinking_water"](\(box)); node["natural"="spring"](\(box));
          node["amenity"="parking"](\(box)); way["amenity"="parking"](\(box));
          node["tourism"="viewpoint"](\(box)); node["natural"="peak"](\(box));
          way["highway"~"^(path|footway|track|steps)$"]["access"!="private"](\(box));
        );
        out center geom;
        """
        var request = URLRequest(url: URL(string: "https://overpass-api.de/api/interpreter")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let formCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: formCharacters) ?? "")".data(using: .utf8)
        request.timeoutInterval = 35
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw TrailServiceError.invalidResponse }
        let result = try JSONDecoder().decode(Response.self, from: data)
        return result.elements.compactMap { element in
            let tags = element.tags ?? [:]
            let kind: OutdoorFeature.Kind?
            if tags["tourism"] == "camp_site" { kind = .campsite }
            else if tags["tourism"] == "alpine_hut" { kind = .hut }
            else if tags["amenity"] == "drinking_water" || tags["natural"] == "spring" { kind = .water }
            else if tags["amenity"] == "parking" { kind = .parking }
            else if tags["tourism"] == "viewpoint" { kind = .viewpoint }
            else if tags["natural"] == "peak" { kind = .peak }
            else if tags["highway"] != nil { kind = .trail }
            else { kind = nil }
            guard let kind else { return nil }

            let center = element.center ?? (element.lat != nil && element.lon != nil ? Center(lat: element.lat!, lon: element.lon!) : nil)
            let coordinate = center.map { TrailCoordinate(latitude: $0.lat, longitude: $0.lon) }
            let path = (element.geometry ?? []).map { TrailCoordinate(latitude: $0.lat, longitude: $0.lon) }
            guard coordinate != nil || path.count > 1 else { return nil }
            let name = tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback: String
            switch kind {
            case .campsite: fallback = "Campsite"
            case .hut: fallback = "Hut"
            case .water: fallback = "Water"
            case .parking: fallback = "Parking"
            case .viewpoint: fallback = "Viewpoint"
            case .peak: fallback = "Peak"
            case .trail: fallback = "Mapped trail"
            }
            return OutdoorFeature(id: "\(element.type)-\(element.id)", name: (name?.isEmpty == false ? name! : fallback), kind: kind, coordinate: coordinate, path: path)
        }
    }
}

enum ElevationService {
    static func profile(for points: [TrailCoordinate]) async throws -> [ElevationSample] {
        guard points.count > 1 else { throw TrailServiceError.noElevation }
        let coordinates = sampleRoute(points, maximumSamples: 60)
        var samples: [ElevationSample] = []
        for start in stride(from: 0, to: coordinates.count, by: 4) {
            let end = min(start + 4, coordinates.count)
            let chunk = Array(coordinates[start..<end])
            let results = await withTaskGroup(of: (SamplePoint, Double?).self, returning: [(SamplePoint, Double?)].self) { group in
                for point in chunk { group.addTask { (point, try? await elevation(at: point)) } }
                var values: [(SamplePoint, Double?)] = []
                for await value in group { values.append(value) }
                return values
            }
            for (point, value) in results {
                if let value { samples.append(ElevationSample(id: UUID(), distanceMeters: point.distanceAlong, elevationMeters: value)) }
            }
        }
        samples.sort { $0.distanceMeters < $1.distanceMeters }
        guard samples.count > 1 else { throw TrailServiceError.noElevation }
        return samples
    }

    private struct SamplePoint {
        var coordinate: TrailCoordinate
        var distanceAlong: Double
    }

    private static func sampleRoute(_ points: [TrailCoordinate], maximumSamples: Int) -> [SamplePoint] {
        var raw: [(TrailCoordinate, Double)] = []
        var distance = 0.0
        for (start, end) in zip(points, points.dropFirst()) {
            let segment = start.distance(to: end)
            let steps = max(1, Int(ceil(segment / 250)))
            for index in 0..<steps {
                let fraction = Double(index) / Double(steps)
                raw.append((TrailCoordinate(latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                                            longitude: start.longitude + (end.longitude - start.longitude) * fraction), distance + segment * fraction))
            }
            distance += segment
        }
        if let last = points.last { raw.append((last, distance)) }
        let strideSize = max(1, Int(ceil(Double(raw.count) / Double(maximumSamples))))
        return raw.enumerated().compactMap { index, item in
            index % strideSize == 0 || index == raw.count - 1 ? SamplePoint(coordinate: item.0, distanceAlong: item.1) : nil
        }
    }

    private static func elevation(at coordinate: SamplePoint) async throws -> Double {
        var components = URLComponents(string: "https://epqs.nationalmap.gov/v1/json")!
        components.queryItems = [
            URLQueryItem(name: "x", value: String(coordinate.coordinate.longitude)),
            URLQueryItem(name: "y", value: String(coordinate.coordinate.latitude)),
            URLQueryItem(name: "wkid", value: "4326"),
            URLQueryItem(name: "units", value: "Meters"),
            URLQueryItem(name: "includeDate", value: "false")
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = Double(String(describing: json["value"] ?? "")), value > -1000 else {
            throw TrailServiceError.noElevation
        }
        return value
    }
}

@MainActor
final class OfflineMapService: ObservableObject {
    @Published var status = ""
    @Published var isDownloading = false
    private var observer: NSObjectProtocol?
    private var activePack: MLNOfflinePack?

    func download(bounds: MapBounds?, styleURL: URL) {
        guard let bounds, bounds.north > bounds.south, bounds.east > bounds.west else {
            status = TrailServiceError.noMapArea.localizedDescription
            return
        }
        guard bounds.approximateTileCount <= 2_700 else {
            status = "Zoom in to a smaller area. This download is over the 3,000 tile limit."
            return
        }
        let coordinateBounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.west),
            ne: CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.east))
        let region = MLNTilePyramidOfflineRegion(styleURL: styleURL, bounds: coordinateBounds, fromZoomLevel: 10, toZoomLevel: 15)
        let context = (try? NSKeyedArchiver.archivedData(withRootObject: ["name": "Hiking area", "source": "OpenFreeMap"], requiringSecureCoding: false)) ?? Data()
        status = "Preparing offline map…"
        isDownloading = true
        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            Task { @MainActor in
                guard let self else { return }
                guard let pack else {
                    self.status = error?.localizedDescription ?? "Could not start the map download."
                    self.isDownloading = false
                    return
                }
                self.activePack = pack
                self.status = "Downloading offline map…"
                pack.resume()
                self.observeProgress()
            }
        }
    }

    private func observeProgress() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = NotificationCenter.default.addObserver(forName: .MLNOfflinePackProgressChanged, object: activePack, queue: .main) { [weak self] note in
            guard let self, let pack = note.object as? MLNOfflinePack else { return }
            let progress = pack.progress
            let complete = progress.countOfResourcesCompleted
            let required = progress.countOfResourcesExpected
            Task { @MainActor in
                if required > 0 && complete >= required {
                    self.status = "Offline map ready"
                    self.isDownloading = false
                } else if required > 0 {
                    self.status = "Downloading map · \(Int(Double(complete) / Double(required) * 100))%"
                }
            }
        }
    }
}

@MainActor
final class TrailwiseModel: ObservableObject {
    @Published var routes: [SavedRoute] = []
    @Published var route = SavedRoute()
    @Published var features: [OutdoorFeature] = []
    @Published var visibleBounds: MapBounds?
    @Published var selectedStyle: OutdoorMapStyle = .liberty
    @Published var enabledKinds = Set(OutdoorFeature.Kind.allCases)
    @Published var isPlanning = false
    @Published var isLoadingFeatures = false
    @Published var isLoadingElevation = false
    @Published var banner: String?
    @Published var offline = OfflineMapService()

    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Trailwise", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("routes.json")
    }()
    private let featuresURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Trailwise", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("outdoor-features.json")
    }()

    init() {
        if let data = try? Data(contentsOf: saveURL), let saved = try? JSONDecoder().decode([SavedRoute].self, from: data) {
            routes = saved
        }
        if let data = try? Data(contentsOf: featuresURL), let saved = try? JSONDecoder().decode([OutdoorFeature].self, from: data) {
            features = saved
        }
    }

    func updateBounds(_ bounds: MapBounds) { visibleBounds = bounds }

    func fetchOutdoorData() async {
        guard let visibleBounds, !isLoadingFeatures else { return }
        guard visibleBounds.isRegional else {
            banner = "Zoom in to a local area before loading trail and campsite data."
            return
        }
        isLoadingFeatures = true
        defer { isLoadingFeatures = false }
        do {
            let newFeatures = try await OutdoorDataService.fetch(bounds: visibleBounds)
            features = newFeatures
            if let data = try? JSONEncoder().encode(newFeatures) { try? data.write(to: featuresURL, options: .atomic) }
            if route.waypoints.count > 1 { rebuildRoute() }
            banner = "Loaded \(newFeatures.count) mapped outdoor features · OpenStreetMap"
        } catch {
            banner = error.localizedDescription
        }
    }

    func addPoint(_ coordinate: TrailCoordinate) {
        guard isPlanning else { return }
        route.waypoints.append(coordinate)
        rebuildRoute()
        route.updatedAt = Date()
        route.elevations = []
    }

    func undoPoint() {
        guard !route.waypoints.isEmpty else { return }
        route.waypoints.removeLast()
        rebuildRoute()
        route.elevations = []
    }

    func clearRoute() {
        route = SavedRoute()
        isPlanning = false
    }

    func loadElevation() async {
        guard route.points.count > 1 else { return }
        isLoadingElevation = true
        defer { isLoadingElevation = false }
        do {
            route.elevations = try await ElevationService.profile(for: route.points)
        } catch {
            banner = error.localizedDescription
        }
    }

    func saveRoute() {
        guard route.points.count > 1 else { return }
        if route.name == "Untitled hike" { route.name = "Hike · \(Date.now.formatted(date: .abbreviated, time: .omitted))" }
        route.updatedAt = Date()
        routes.removeAll { $0.id == route.id }
        routes.insert(route, at: 0)
        persist()
        banner = "Route saved on this iPhone"
    }

    func open(_ saved: SavedRoute) {
        route = saved
        isPlanning = false
    }

    func importGPX(_ data: Data) throws {
        let points = try GPXCodec.decode(data)
        route = SavedRoute(name: "Imported hike", waypoints: points, points: points)
        isPlanning = false
        saveRoute()
    }

    private func rebuildRoute() {
        let result = TrailRouter.plan(through: route.waypoints, trails: features.filter { $0.kind == .trail })
        route.points = result.points
        route.updatedAt = Date()
        if result.snappedSegmentCount > 0 {
            banner = "Route follows mapped trails for \(result.snappedSegmentCount) of \(result.segmentCount) segments"
        } else if result.segmentCount > 0 {
            banner = "Straight line used · load trail data here to follow mapped paths"
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }
}

