import SwiftUI
import Combine

// MARK: - Share Payload Types

enum ShareSource: String, Codable {
    case shareExtension
    case clipboard
}

struct SharePayload: Codable {
    let id: String
    let text: String
    let createdAt: Date
    let source: ShareSource
}

enum ShareStore {
    static let appGroupID = "group.com.scamshield.shared"
    static let payloadsKey = "sharePayloadsById"

    static func consume(id: String, maxAgeSeconds: TimeInterval = 300) -> SharePayload? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              var dict = defaults.dictionary(forKey: payloadsKey) as? [String: Data],
              let data = dict[id],
              let payload = try? JSONDecoder().decode(SharePayload.self, from: data)
        else { return nil }

        // Expiry check
        let age = Date().timeIntervalSince(payload.createdAt)
        guard age <= maxAgeSeconds else {
            dict.removeValue(forKey: id)
            defaults.set(dict, forKey: payloadsKey)
            defaults.synchronize()
            return nil
        }

        // One-time consumption
        dict.removeValue(forKey: id)
        defaults.set(dict, forKey: payloadsKey)
        defaults.synchronize()
        return payload
    }

    static func cleanupExpired(maxAgeSeconds: TimeInterval = 300) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              var dict = defaults.dictionary(forKey: payloadsKey) as? [String: Data]
        else { return }

        let now = Date()
        var changed = false

        for (id, data) in dict {
            if let payload = try? JSONDecoder().decode(SharePayload.self, from: data) {
                if now.timeIntervalSince(payload.createdAt) > maxAgeSeconds {
                    dict.removeValue(forKey: id)
                    changed = true
                }
            }
        }

        if changed {
            defaults.set(dict, forKey: payloadsKey)
            defaults.synchronize()
        }
    }
}

// MARK: - App

@main
struct ScamShieldApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Print environment info in debug builds
        APIConfig.printCurrentEnvironment()

        // Cleanup any expired payloads on launch
        ShareStore.cleanupExpired()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    // MARK: - URL Handling (for Share Extension)

    private func handleIncomingURL(_ url: URL) {
        // Handle scamshield://scan?id=...
        guard url.scheme == "scamshield",
              url.host == "scan" else {
            return
        }

        // Parse ID from query string
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value else {
            return
        }

        // Consume payload by ID (one-time use, 5 minute expiry)
        guard let payload = ShareStore.consume(id: id, maxAgeSeconds: 300) else {
            return
        }

        // Set app state
        appState.sharedText = payload.text
        appState.shouldAutoScan = (payload.source == .shareExtension)
    }
}

// MARK: - App State

/// Global app state for handling shared data and navigation
class AppState: ObservableObject {
    /// Text shared from Share Extension or clipboard
    @Published var sharedText: String?

    /// Whether to automatically start scanning (only for share extension, not clipboard)
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
            .respectHighContrast()  // Apply high contrast mode app-wide
        // }
    }
}
