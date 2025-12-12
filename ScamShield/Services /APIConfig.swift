import Foundation

// MARK: - Environment Configuration

/// API environments for the app
/// Switch between dev/staging/prod easily
enum APIEnvironment {
    case dev        // localhost:3001 (simulator only)
    case staging    // Mac LAN IP (physical device testing)
    case prod       // Production server (future)

    var baseURL: URL {
        switch self {
        case .dev:
            return URL(string: "http://localhost:3001")!
        case .staging:
            // Replace with your Mac's local IP when testing on device
            // Find via: System Settings → Wi-Fi → Details → IP Address
            return URL(string: "http://192.168.1.100:3000")!
        case .prod:
            // Future production URL
            return URL(string: "https://api.scamshield.app")!
        }
    }

    var name: String {
        switch self {
        case .dev: return "Development"
        case .staging: return "Staging"
        case .prod: return "Production"
        }
    }
}

/// Global API configuration
struct APIConfig {
    /// Current environment - automatically switches based on build
    #if DEBUG
    static let current: APIEnvironment = .dev
    #else
    static let current: APIEnvironment = .prod
    #endif

    /// Base URL for the current environment
    static var baseURL: URL {
        current.baseURL
    }

    /// Check scam endpoint
    static var checkScamURL: URL {
        baseURL.appendingPathComponent("/api/check-scam")
    }

    /// Request timeout in seconds
    static let requestTimeout: TimeInterval = 30

    /// For debugging - prints the current environment on app launch
    static func printCurrentEnvironment() {
        #if DEBUG
        print("🌐 API Environment: \(current.name)")
        print("🔗 Base URL: \(baseURL)")
        #endif
    }
}
