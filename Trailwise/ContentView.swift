import SwiftUI
import UniformTypeIdentifiers

private enum AppTab: String, CaseIterable {
    case explore = "Explore"
    case plan = "Plan"
    case saved = "Saved"
    case offline = "Offline"

    var symbol: String {
        switch self {
        case .explore: return "safari.fill"
        case .plan: return "point.topleft.down.curvedto.point.bottomright.up"
        case .saved: return "bookmark.fill"
        case .offline: return "arrow.down.circle.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @State private var selectedTab: AppTab = .explore
    @State private var showingLayers = false
    @State private var showingSearch = false
    @State private var isImportingGPX = false
    @State private var isExportingGPX = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.hikersBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .explore:
                    ExploreView(selectedTab: $selectedTab, showingLayers: $showingLayers, showingSearch: $showingSearch)
                case .plan:
                    PlanView(showingLayers: $showingLayers, isExportingGPX: $isExportingGPX)
                case .saved:
                    SavedView(selectedTab: $selectedTab, isImportingGPX: $isImportingGPX)
                case .offline:
                    OfflineView(showingLayers: $showingLayers, offline: model.offline)
                }
            }

            if let banner = model.banner {
                BannerView(text: banner) { model.banner = nil }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: $selectedTab)
        }
        .animation(.easeInOut(duration: 0.2), value: model.banner)
        .sheet(isPresented: $showingLayers) {
            LayersSheet(isPresented: $showingLayers)
                .environmentObject(model)
        }
        .sheet(isPresented: $showingSearch) {
            SearchSheet(isPresented: $showingSearch, selectedTab: $selectedTab)
                .environmentObject(model)
        }
        .fileImporter(isPresented: $isImportingGPX, allowedContentTypes: [.xml, .data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                try model.importGPX(Data(contentsOf: url))
                selectedTab = .saved
                model.banner = "GPX route imported"
            } catch {
                model.banner = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExportingGPX,
            document: GPXDocument(route: model.route),
            contentType: .xml,
            defaultFilename: model.route.name.replacingOccurrences(of: " ", with: "-")) { result in
                if case .failure(let error) = result { model.banner = error.localizedDescription }
            }
        .alert("Offline maps", isPresented: Binding(
            get: { !model.offline.status.isEmpty && !model.offline.isDownloading && model.offline.status != "Offline map ready" },
            set: { if !$0 { model.offline.status = "" } })) {
                Button("OK", role: .cancel) { model.offline.status = "" }
            } message: {
                Text(model.offline.status)
            }
        .task(id: model.route.updatedAt) {
            guard model.route.points.count > 1, model.route.elevations.isEmpty else { return }
            await model.loadElevation()
        }
    }
}

private struct ExploreView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var selectedTab: AppTab
    @Binding var showingLayers: Bool
    @Binding var showingSearch: Bool

    var body: some View {
        ZStack(alignment: .top) {
            TrailMapView(model: model).ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                ExploreHeader(showingSearch: $showingSearch)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                Spacer()
                mapControls(showingLayers: $showingLayers)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                ExploreCard(selectedTab: $selectedTab)
            }
        }
    }

    private func mapControls(showingLayers: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Spacer()
            CircleMapButton(symbol: "location.fill", label: "Show my location") {
                model.banner = "Location is shown when GPS is available"
            }
            CircleMapButton(symbol: "square.3.layers.3d", label: "Map layers") {
                showingLayers.wrappedValue = true
            }
        }
    }
}

private struct ExploreHeader: View {
    @Binding var showingSearch: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("HIKER'S DELIGHT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Color.hikersGreen)
                Text("Find your next line")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.hikersInk)
            }
            Spacer()
            Button { showingSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.hikersInk)
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Search places and trails")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 7)
    }
}

private struct ExploreCard: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explore outside")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Offline-ready maps for your next hike")
                        .font(.subheadline)
                        .foregroundStyle(Color.hikersMuted)
                }
                Spacer()
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.hikersGreen)
                    .frame(width: 42, height: 42)
                    .background(Color.hikersMint, in: Circle())
            }

            HStack(spacing: 10) {
                QuickAction(title: "Plan a route", symbol: "figure.hiking") {
                    model.isPlanning = true
                    selectedTab = .plan
                }
                QuickAction(title: "Get trails", symbol: "arrow.clockwise") {
                    Task { await model.fetchOutdoorData() }
                }
                QuickAction(title: "Download", symbol: "arrow.down.to.line.compact") {
                    selectedTab = .offline
                }
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 22, y: 5)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct PlanView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var showingLayers: Bool
    @Binding var isExportingGPX: Bool

    var body: some View {
        ZStack(alignment: .top) {
            TrailMapView(model: model).ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                HStack {
                    Text(model.isPlanning ? "Plan your hike" : "Route preview")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                    CircleMapButton(symbol: "square.3.layers.3d", label: "Map layers") { showingLayers = true }
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 9)
                .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 18, y: 7)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
                PlannerCard(isExportingGPX: $isExportingGPX)
            }
        }
        .onAppear { model.isPlanning = true }
    }
}

private struct PlannerCard: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var isExportingGPX: Bool

    private var elevationGainFeet: Double {
        zip(model.route.elevations, model.route.elevations.dropFirst()).reduce(0) { total, pair in
            total + max(0, pair.1.elevationMeters - pair.0.elevationMeters)
        } * 3.28084
    }

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Color.black.opacity(0.12)).frame(width: 38, height: 4)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.route.points.count > 1 ? "Your route" : "Build a route")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                    Text(model.isPlanning ? "Tap the map to add trail points" : "Load a route or start planning")
                        .font(.caption)
                        .foregroundStyle(Color.hikersMuted)
                }
                Spacer()
                if model.route.points.count > 1 {
                    Text(String(format: "%.2f mi", model.route.distanceMeters / 1609.344))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            if model.route.points.count > 1 {
                HStack(spacing: 0) {
                    PlannerMetric(title: "WAYPOINTS", value: "\(model.route.waypointCount)")
                    Divider().frame(height: 32)
                    PlannerMetric(title: "ELEVATION", value: model.route.elevations.isEmpty ? "—" : String(format: "+%.0f ft", elevationGainFeet))
                    Divider().frame(height: 32)
                    PlannerMetric(title: "STATUS", value: model.isPlanning ? "Editing" : "Ready")
                }
                if !model.route.elevations.isEmpty {
                    ElevationProfileView(samples: model.route.elevations).frame(height: 76)
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.isPlanning.toggle()
                    if model.isPlanning && model.route.points.isEmpty {
                        model.banner = "Route builder on · tap anywhere on the map"
                    }
                } label: {
                    Label(model.isPlanning ? "Finish route" : "Plan route", systemImage: model.isPlanning ? "checkmark" : "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hikersGreen)

                if !model.route.waypoints.isEmpty {
                    SmallActionButton(symbol: "arrow.uturn.backward", label: "Undo") { model.undoPoint() }
                }
                if model.route.points.count > 1 {
                    SmallActionButton(symbol: "square.and.arrow.down", label: "Save") { model.saveRoute() }
                    SmallActionButton(symbol: "square.and.arrow.up", label: "Export") { isExportingGPX = true }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 9)
        .padding(.bottom, 16)
        .background(.white.opacity(0.98), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 5)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

private struct SavedView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var selectedTab: AppTab
    @Binding var isImportingGPX: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Saved adventures")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Routes and GPX tracks stored on this iPhone")
                            .foregroundStyle(Color.hikersMuted)
                    }

                    if model.routes.isEmpty {
                        EmptyRoutesCard(selectedTab: $selectedTab, isImportingGPX: $isImportingGPX)
                    } else {
                        ForEach(model.routes) { saved in
                            SavedRouteCard(route: saved) {
                                model.open(saved)
                                selectedTab = .plan
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.hikersBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isImportingGPX = true } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import GPX")
                }
            }
        }
    }
}

private struct OfflineView: View {
    @EnvironmentObject private var model: TrailwiseModel
    @ObservedObject var offline: OfflineMapService
    @Binding var showingLayers: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offline maps")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Take the trail with you")
                        .foregroundStyle(Color.hikersMuted)
                }
                Spacer()
                Button { showingLayers = true } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.headline)
                        .foregroundStyle(Color.hikersInk)
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ZStack(alignment: .bottom) {
                TrailMapView(model: model)
                Text("Move and zoom the map to choose a download area")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(.bottom, 14)
            }
            .frame(height: 315)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 14) {
                Label("Selected map area", systemImage: "map.fill")
                    .font(.headline)
                Text("Download the visible hiking map before you leave service. Maps stay on-device and work without a connection.")
                    .font(.subheadline)
                    .foregroundStyle(Color.hikersMuted)

                Button {
                    guard let bounds = model.visibleBounds else {
                        offline.status = "Move the map to the area you want to download, then try again."
                        return
                    }
                    offline.download(bounds: bounds, styleURL: model.selectedStyle.url)
                } label: {
                    HStack {
                        if offline.isDownloading { ProgressView().tint(.white) }
                        Text(offline.isDownloading ? offline.status : "Download this area")
                        Spacer()
                        if !offline.isDownloading { Image(systemName: "arrow.down.to.line.compact") }
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.hikersGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(offline.isDownloading)

                if offline.status == "Offline map ready" {
                    Label("Offline map ready on this iPhone", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hikersGreen)
                }

                Text("OpenStreetMap · OpenMapTiles · OpenFreeMap")
                    .font(.caption2)
                    .foregroundStyle(Color.hikersMuted)
            }
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 3)
            .padding(14)
            Spacer(minLength: 0)
        }
        .background(Color.hikersBackground)
    }
}

private struct LayersSheet: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Map style") {
                    ForEach(OutdoorMapStyle.allCases) { style in
                        Button {
                            model.selectedStyle = style
                            isPresented = false
                        } label: {
                            HStack {
                                Text(style.rawValue).foregroundStyle(.primary)
                                Spacer()
                                if model.selectedStyle == style { Image(systemName: "checkmark").foregroundStyle(Color.hikersGreen) }
                            }
                        }
                    }
                }
                Section("Hiking layers") {
                    ForEach(OutdoorFeature.Kind.allCases, id: \.self) { kind in
                        Toggle(isOn: Binding(
                            get: { model.enabledKinds.contains(kind) },
                            set: { visible in
                                if visible { model.enabledKinds.insert(kind) } else { model.enabledKinds.remove(kind) }
                            })) {
                                Label(kind.rawValue, systemImage: kind.symbol)
                            }
                            .tint(Color.hikersGreen)
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
                    Text("Trail and place data comes from OpenStreetMap. Downloaded map packs are available without service; live trail refreshes and elevation lookups need a connection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("© OpenStreetMap contributors · © OpenMapTiles · OpenFreeMap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Map layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { isPresented = false } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SearchSheet: View {
    @EnvironmentObject private var model: TrailwiseModel
    @Binding var isPresented: Bool
    @Binding var selectedTab: AppTab
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.hikersMuted)
                    TextField("Search mountains, parks & trails", text: $query)
                        .textInputAutocapitalization(.words)
                }
                .padding(14)
                .background(Color.hikersBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Start with an area")
                    .font(.headline)
                VStack(spacing: 10) {
                    SearchSuggestion(title: "Load trails around the map", symbol: "figure.hiking") {
                        isPresented = false
                        Task { await model.fetchOutdoorData() }
                    }
                    SearchSuggestion(title: "Plan a hike here", symbol: "point.topleft.down.curvedto.point.bottomright.up") {
                        isPresented = false
                        model.isPlanning = true
                        selectedTab = .plan
                    }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Find outside")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { isPresented = false } } }
        }
        .presentationDetents([.medium])
    }
}

private struct EmptyRoutesCard: View {
    @Binding var selectedTab: AppTab
    @Binding var isImportingGPX: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.hikersGreen)
                .frame(width: 64, height: 64)
                .background(Color.hikersMint, in: Circle())
            Text("Your adventures live here")
                .font(.headline)
            Text("Plan a route or import a GPX track before heading out.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(Color.hikersMuted)
            HStack(spacing: 10) {
                Button("Plan a route") { selectedTab = .plan }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.hikersGreen)
                Button("Import GPX") { isImportingGPX = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SavedRouteCard: View {
    let route: SavedRoute
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "figure.hiking")
                    .foregroundStyle(Color.hikersGreen)
                    .frame(width: 48, height: 48)
                    .background(Color.hikersMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                        .foregroundStyle(Color.hikersInk)
                    Text("\(String(format: "%.2f", route.distanceMeters / 1609.344)) mi · \(route.waypointCount) waypoints")
                        .font(.caption)
                        .foregroundStyle(Color.hikersMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.hikersMuted)
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AppTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? Color.hikersGreen : Color.hikersMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 7)
        .padding(.bottom, 4)
        .background(.white.opacity(0.98))
        .overlay(alignment: .top) { Divider() }
    }
}

private struct QuickAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.hikersGreen)
                    .frame(width: 42, height: 42)
                    .background(Color.hikersMint, in: Circle())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hikersInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct CircleMapButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.hikersInk)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.13), radius: 10, y: 3)
        }
        .accessibilityLabel(label)
    }
}

private struct SmallActionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 36, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

private struct PlannerMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(Color.hikersMuted)
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SearchSuggestion: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(Color.hikersGreen)
                Text(title).foregroundStyle(Color.hikersInk)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.hikersMuted)
            }
            .padding(14)
            .background(Color.hikersBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct BannerView: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "info.circle.fill")
            Text(text).font(.caption.weight(.semibold)).lineLimit(2)
            Spacer(minLength: 0)
            Button(action: dismiss) { Image(systemName: "xmark") }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(Color.hikersInk.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }
}

private extension Color {
    static let hikersGreen = Color(red: 0.18, green: 0.43, blue: 0.31)
    static let hikersMint = Color(red: 0.88, green: 0.95, blue: 0.87)
    static let hikersBackground = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let hikersInk = Color(red: 0.10, green: 0.14, blue: 0.12)
    static let hikersMuted = Color(red: 0.37, green: 0.42, blue: 0.39)
}

