import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @State private var showingLayers = false
    @State private var showingRoutes = false
    @State private var isImportingGPX = false
    @State private var isExportingGPX = false

    var body: some View {
        ZStack(alignment: .top) {
            TrailMapView(model: model).ignoresSafeArea()

            VStack(spacing: 10) {
                header
                if let banner = model.banner {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                        Text(banner).lineLimit(2)
                        Spacer(minLength: 0)
                        Button { model.banner = nil } label: { Image(systemName: "xmark") }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(11)
                    .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 14))
                }
                Spacer()
                routePanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingLayers) { layerSheet }
        .sheet(isPresented: $showingRoutes) { routeLibrary }
        .fileImporter(isPresented: $isImportingGPX, allowedContentTypes: [.xml, .data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                try model.importGPX(Data(contentsOf: url))
                showingRoutes = false
                model.banner = "GPX route imported"
            } catch { model.banner = error.localizedDescription }
        }
        .fileExporter(isPresented: $isExportingGPX, document: GPXDocument(route: model.route), contentType: .xml, defaultFilename: model.route.name.replacingOccurrences(of: " ", with: "-")) { result in
            if case .failure(let error) = result { model.banner = error.localizedDescription }
        }
        .alert("Offline maps", isPresented: Binding(get: { !model.offline.status.isEmpty && !model.offline.isDownloading && model.offline.status != "Offline map ready" }, set: { if !$0 { model.offline.status = "" } })) {
            Button("OK", role: .cancel) { model.offline.status = "" }
        } message: { Text(model.offline.status) }
        .task(id: model.route.points.count) {
            guard model.route.points.count > 1, model.route.elevations.isEmpty else { return }
            await model.loadElevation()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRAILWISE").font(.caption2.weight(.black)).tracking(1.5).foregroundStyle(Color(red: 0.18, green: 0.43, blue: 0.31))
                Text("Explore outside").font(.headline.weight(.bold)).foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.15))
            }
            Spacer()
            Button { showingRoutes = true } label: {
                Image(systemName: "bookmark").font(.system(size: 16, weight: .semibold)).frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .background(.white, in: Circle())
            Button { showingLayers = true } label: {
                Image(systemName: "square.3.layers.3d").font(.system(size: 16, weight: .semibold)).frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .background(.white, in: Circle())
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 5)
    }

    private var routePanel: some View {
        VStack(spacing: 12) {
            Capsule().fill(Color.black.opacity(0.12)).frame(width: 36, height: 4).padding(.top, 3)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.isPlanning ? "Plan your hike" : "Map & routes").font(.headline.weight(.bold))
                    Text(model.isPlanning ? "Tap the map to add route points" : "Open map data or sketch a route").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingRoutes = true } label: { Label("Saved", systemImage: "bookmark.fill").font(.caption.weight(.semibold)) }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.18, green: 0.43, blue: 0.31))
            }

            if model.route.points.count > 1 {
                HStack(spacing: 0) {
                    metric(title: "DISTANCE", value: String(format: "%.2f mi", model.route.distanceMeters / 1609.344))
                    Divider().frame(height: 34)
                    metric(title: "WAYPOINTS", value: "\(model.route.points.count)")
                    Divider().frame(height: 34)
                    metric(title: "ELEVATION", value: model.route.elevations.isEmpty ? (model.isLoadingElevation ? "Loading" : "—") : String(format: "+%.0f ft", elevationGainFeet))
                }
                .padding(.vertical, 2)
                if !model.route.elevations.isEmpty {
                    ElevationProfileView(samples: model.route.elevations)
                        .frame(height: 92)
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.isPlanning.toggle()
                    if model.isPlanning && model.route.points.isEmpty { model.banner = "Route builder on · tap anywhere on the map to place a point" }
                } label: {
                    Label(model.isPlanning ? "Done" : "Plan route", systemImage: model.isPlanning ? "checkmark" : "point.topleft.down.curvedto.point.bottomright.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.43, blue: 0.31))

                if model.route.points.count > 0 {
                    Button { model.undoPoint() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 38, height: 34) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Undo last point")
                }

                Button {
                    guard let bounds = model.visibleBounds else { model.banner = "Move the map to the area to save offline"; return }
                    model.offline.download(bounds: bounds, styleURL: model.selectedStyle.url)
                } label: {
                    if model.offline.isDownloading { ProgressView().frame(width: 38, height: 34) }
                    else { Image(systemName: "arrow.down.to.line.compact").frame(width: 38, height: 34) }
                }
                .buttonStyle(.bordered)
                .disabled(model.offline.isDownloading)
                .accessibilityLabel("Download visible map for offline use")

                if model.route.points.count > 1 {
                    Button { model.saveRoute() } label: { Image(systemName: "square.and.arrow.down").frame(width: 38, height: 34) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Save route")
                    Button { isExportingGPX = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 38, height: 34) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Export route as GPX")
                }
            }
            if model.offline.isDownloading || model.offline.status == "Offline map ready" {
                Text(model.offline.status).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .background(.white.opacity(0.97), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 3)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var elevationGainFeet: Double {
        zip(model.route.elevations, model.route.elevations.dropFirst()).reduce(0) { total, pair in
            total + max(0, pair.1.elevationMeters - pair.0.elevationMeters)
        } * 3.28084
    }

    private var layerSheet: some View {
        NavigationStack {
            List {
                Section("Map appearance") {
                    ForEach(OutdoorMapStyle.allCases) { style in
                        Button {
                            model.selectedStyle = style
                            showingLayers = false
                        } label: {
                            HStack {
                                Text(style.rawValue).foregroundStyle(.primary)
                                Spacer()
                                if model.selectedStyle == style { Image(systemName: "checkmark").foregroundStyle(.green) }
                            }
                        }
                    }
                }
                Section("Outdoor layers") {
                    ForEach(OutdoorFeature.Kind.allCases, id: \.self) { kind in
                        Toggle(isOn: Binding(get: { model.enabledKinds.contains(kind) }, set: { visible in
                            if visible { model.enabledKinds.insert(kind) } else { model.enabledKinds.remove(kind) }
                        })) {
                            Label(kind.rawValue, systemImage: kind.symbol)
                        }
                        .tint(Color(red: 0.18, green: 0.43, blue: 0.31))
                    }
                    Button {
                        Task { await model.fetchOutdoorData() }
                    } label: {
                        HStack {
                            Label("Load trails & places here", systemImage: "arrow.clockwise")
                            Spacer()
                            if model.isLoadingFeatures { ProgressView() }
                        }
                    }
                    .disabled(model.isLoadingFeatures)
                }
                Section {
                    Text("Camp and trail names come from OpenStreetMap. Coverage depends on local mapping. Offline maps save the visible area; OpenFreeMap allows up to 3,000 tiles or 50 MB per download.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("© OpenStreetMap contributors · © OpenMapTiles · OpenFreeMap")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Map layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showingLayers = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var routeLibrary: some View {
        NavigationStack {
            Group {
                if model.routes.isEmpty {
                    ContentUnavailableView("No saved routes", systemImage: "map", description: Text("Plan a hike, then save it here."))
                } else {
                    List(model.routes) { saved in
                        Button {
                            model.open(saved)
                            showingRoutes = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up").foregroundStyle(.green).frame(width: 34, height: 34).background(.green.opacity(0.1), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(saved.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text("\(String(format: "%.2f", saved.distanceMeters / 1609.344)) mi · \(saved.points.count) points")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { isImportingGPX = true } label: { Label("Import GPX", systemImage: "square.and.arrow.down") } }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { showingRoutes = false } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
