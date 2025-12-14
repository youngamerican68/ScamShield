import Foundation

/// Service to fetch scan history from the API
class ScanHistoryService {
    static let shared = ScanHistoryService()

    private init() {}

    /// Fetch scan history for the current user
    func fetchHistory(limit: Int = 50, offset: Int = 0) async throws -> ScanHistoryResponse {
        var components = URLComponents(url: APIConfig.scanHistoryURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw ScanHistoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.requestTimeout

        #if DEBUG
        print("📥 Fetching scan history from: \(url)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScanHistoryError.invalidResponse
        }

        #if DEBUG
        print("📥 Response status: \(httpResponse.statusCode)")
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Response: \(jsonString.prefix(500))")
        }
        #endif

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw ScanHistoryError.unauthorized
            }
            throw ScanHistoryError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let historyResponse = try decoder.decode(ScanHistoryResponse.self, from: data)
            return historyResponse
        } catch {
            #if DEBUG
            print("❌ Decode error: \(error)")
            #endif
            throw ScanHistoryError.decodingFailed(error)
        }
    }
}

enum ScanHistoryError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Please sign in to view scan history"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .decodingFailed:
            return "Failed to parse scan history"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
