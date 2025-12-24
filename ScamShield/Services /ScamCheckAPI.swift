import Foundation

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code, let message):
            return message ?? "Server error (code: \(code))"
        case .decodingError:
            return "Failed to process server response"
        case .networkError(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return "No internet connection. Please check your network."
            }
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out. Please try again."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .timeout:
            return "The server is taking too long. Try again in a moment."
        case .serverError:
            return "There may be an issue with our servers. Please try again later."
        default:
            return "Please try again."
        }
    }
}

// MARK: - API Service

/// Service for interacting with the Scam Check API
actor ScamCheckAPI {
    static let shared = ScamCheckAPI()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.requestTimeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Analyze a message for scam indicators (uses /api/check-scam)
    /// - Parameter input: The scam check input containing the message and context
    /// - Returns: The analysis result with verdict and recommendations
    func checkScam(input: ScamCheckInput) async throws -> ScamCheckResult {
        let url = APIConfig.checkScamURL

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ScamShield-iOS/1.0", forHTTPHeaderField: "User-Agent")

        // Encode request body
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        // Make request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response
            var errorMessage: String?
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                errorMessage = errorResponse.message
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ScamCheckResult.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Create a text scan - analyzes and stores the result in history
    /// Uses POST /api/scans endpoint which runs AI analysis and persists
    /// - Parameter input: The scam check input containing the message and context
    /// - Returns: The stored scan record (includes id, timestamp, etc.)
    func createTextScan(input: ScamCheckInput) async throws -> ScanHistoryItem {
        let url = APIConfig.scanHistoryURL  // POST /api/scans

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ScamShield-iOS/1.0", forHTTPHeaderField: "User-Agent")

        // Build request body
        let body: [String: Any] = [
            "text": input.text,
            "fromKnownContact": input.fromKnownContact,
            "contextWhoFor": input.contextWhoFor.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("Creating text scan at: \(url)")
        #endif

        // Make request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        print("Text scan response status: \(httpResponse.statusCode)")
        if let json = String(data: data, encoding: .utf8) {
            print("Text scan response: \(json.prefix(500))")
        }
        #endif

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorMessage: String?
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                errorMessage = errorResponse.message
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode response as ScanHistoryItem
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ScanHistoryItem.self, from: data)
        } catch {
            #if DEBUG
            print("Decode error: \(error)")
            #endif
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Error Response Model

private struct ErrorResponse: Codable {
    let message: String?
    let error: String?
    let errorCode: String?
}

// MARK: - Preview Helper

#if DEBUG
extension ScamCheckAPI {
    /// Mock result for SwiftUI previews
    static var mockSafeResult: ScamCheckResult {
        ScamCheckResult(
            verdict: .noObviousScam,
            confidence: 0.92,
            summary: "This message appears to be from a legitimate source with no obvious scam indicators.",
            tactics: [],
            safeSteps: [
                "Continue the conversation normally",
                "Stay vigilant for any unusual requests",
                "Trust your instincts if something feels off later"
            ],
            rawModelReasoning: nil
        )
    }

    static var mockSuspiciousResult: ScamCheckResult {
        ScamCheckResult(
            verdict: .suspicious,
            confidence: 0.75,
            summary: "This message contains some elements commonly seen in phishing attempts.",
            tactics: [
                "Creating urgency",
                "Requesting personal information"
            ],
            safeSteps: [
                "Do not click any links in the message",
                "Verify the sender through official channels",
                "Contact the company directly using their official website"
            ],
            rawModelReasoning: nil
        )
    }

    static var mockDangerResult: ScamCheckResult {
        ScamCheckResult(
            verdict: .highScam,
            confidence: 0.95,
            summary: "This message exhibits multiple strong indicators of a scam attempt targeting your personal and financial information.",
            tactics: [
                "Impersonating a trusted authority (bank)",
                "Creating artificial urgency",
                "Requesting sensitive financial information",
                "Using threatening language about account closure"
            ],
            safeSteps: [
                "Do NOT reply to this message",
                "Do NOT click any links",
                "Do NOT provide any personal information",
                "Block the sender",
                "Report as spam/phishing"
            ],
            rawModelReasoning: nil
        )
    }
}
#endif
