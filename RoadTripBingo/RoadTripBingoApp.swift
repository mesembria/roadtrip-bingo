import SwiftUI

@main
struct RoadTripBingoApp: App {
    @StateObject private var appState = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                        .task {
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showSplash = false
                            }
                        }
                }
            }
        }
    }
}
