import SwiftUI
import Combine

@main
struct ScamShieldApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Print environment info in debug builds
        APIConfig.printCurrentEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    checkForSharedContent()
                }
        }
    }

    // MARK: - URL Handling (for Share Extension)

    private func handleIncomingURL(_ url: URL) {
        // Handle scamshield://scan
        guard url.scheme == "scamshield",
              url.host == "scan" else {
            return
        }

        // Check App Group for pending text (Share Extension saves it there)
        checkForSharedContent()
    }

    private func checkForSharedContent() {
        let defaults = UserDefaults(suiteName: "group.com.scamshield.shared")

        if let text = defaults?.string(forKey: "pendingScanText"),
           let timestamp = defaults?.object(forKey: "pendingScanTimestamp") as? Date,
           Date().timeIntervalSince(timestamp) < 60 { // Within last minute

            appState.sharedText = text
            appState.shouldAutoScan = true

            // Clear after reading
            defaults?.removeObject(forKey: "pendingScanText")
            defaults?.removeObject(forKey: "pendingScanTimestamp")
        }
    }
}

// MARK: - App State

/// Global app state for handling shared data and navigation
class AppState: ObservableObject {
    /// Text shared from Share Extension
    @Published var sharedText: String?

    /// Whether to automatically start scanning (from Share Extension)
    @Published var shouldAutoScan: Bool = false

    /// Whether onboarding has been completed
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        // TODO: Add onboarding check
        // if !appState.hasCompletedOnboarding {
        //     OnboardingView()
        // } else {
        ScanView()
        // }
    }
}
