import SwiftUI

@main
struct HikersDelightApp: App {
    @StateObject private var model = TrailwiseModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}

