import SwiftUI

// MARK: - Input Models

/// Context for who the scan is for
enum ContextWhoFor: String, Codable, CaseIterable {
    case selfUser = "self"
    case parent = "parent"
    case other = "other"

    var displayName: String {
        switch self {
        case .selfUser: return "Myself"
        case .parent: return "My Parent/Grandparent"
        case .other: return "Someone Else"
        }
    }

    var icon: String {
        switch self {
        case .selfUser: return "person.fill"
        case .parent: return "figure.2.and.child.holdinghands"
        case .other: return "person.2.fill"
        }
    }
}

/// Input payload for the scam check API
struct ScamCheckInput: Codable {
    let text: String
    let contextWhoFor: ContextWhoFor
    let fromKnownContact: Bool
    let imageBase64: String?

    init(text: String, contextWhoFor: ContextWhoFor = .selfUser, fromKnownContact: Bool = false, imageBase64: String? = nil) {
        self.text = text
        self.contextWhoFor = contextWhoFor
        self.fromKnownContact = fromKnownContact
        self.imageBase64 = imageBase64
    }
}

// MARK: - Result Models

/// Verdict from the AI analysis
enum ScamVerdict: String, Codable {
    case highScam = "high_scam"
    case suspicious = "suspicious"
    case noObviousScam = "no_obvious_scam"

    // MARK: - Display Properties

    var title: String {
        switch self {
        case .highScam:
            return "High Likelihood This Is a Scam"
        case .suspicious:
            return "Suspicious - Proceed With Caution"
        case .noObviousScam:
            return "No Obvious Scam Signals"
        }
    }

    var shortTitle: String {
        switch self {
        case .highScam: return "Danger"
        case .suspicious: return "Suspicious"
        case .noObviousScam: return "Likely Safe"
        }
    }

    var icon: String {
        switch self {
        case .highScam: return "exclamationmark.octagon.fill"
        case .suspicious: return "exclamationmark.triangle.fill"
        case .noObviousScam: return "checkmark.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .highScam: return .verdictDanger
        case .suspicious: return .verdictWarning
        case .noObviousScam: return .verdictSafe
        }
    }

    var backgroundColor: Color {
        switch self {
        case .highScam: return .verdictDangerLight
        case .suspicious: return .verdictWarningLight
        case .noObviousScam: return .verdictSafeLight
        }
    }

    var warningMessage: String? {
        switch self {
        case .highScam:
            return "DO NOT INTERACT - Do not reply, click links, call, or send money"
        case .suspicious:
            return "PROCEED WITH CAUTION - Verify through official channels"
        case .noObviousScam:
            return nil
        }
    }
}

/// Result payload from the scam check API
struct ScamCheckResult: Codable {
    let verdict: ScamVerdict
    let confidence: Double
    let summary: String
    let tactics: [String]
    let safeSteps: [String]
    let rawModelReasoning: String?

    /// Confidence as a percentage string (e.g., "85%")
    var confidencePercent: String {
        "\(Int(confidence * 100))%"
    }
}

// MARK: - Scan State

/// Current state of the scanning process
enum ScanState: Equatable {
    case idle
    case scanning(phase: ScanPhase)
    case complete(ScamCheckResult)
    case error(String)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning(let a), .scanning(let b)): return a == b
        case (.complete, .complete): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

/// Phases during the scanning animation
enum ScanPhase: String, CaseIterable {
    case searching = "Shield activating..."
    case analyzing = "Guardian angel on duty..."
    case verifying = "Scanning for red flags..."
    case finalizing = "Locking in your verdict..."

    var icon: String {
        switch self {
        case .searching: return "shield.fill"
        case .analyzing: return "sparkles"
        case .verifying: return "eye.fill"
        case .finalizing: return "lock.shield.fill"
        }
    }
}

// MARK: - Scan History Models

/// Source of the scan
enum ScanSource: String, Codable {
    case emailForward = "email_forward"
    case clipboard = "clipboard"
    case shareExtension = "share_extension"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .emailForward: return "Email Forward"
        case .clipboard: return "Clipboard"
        case .shareExtension: return "Share"
        case .manual: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .emailForward: return "envelope.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .shareExtension: return "square.and.arrow.up.fill"
        case .manual: return "keyboard.fill"
        }
    }
}

/// A scan record from the history API
struct ScanHistoryItem: Codable, Identifiable {
    let id: String
    let userId: String
    let source: ScanSource
    let subjectSnippet: String
    let fromDomain: String
    let messageId: String
    let verdict: String
    let summary: String
    let tactics: [String]
    let safeSteps: [String]
    let confidence: Double
    let createdAt: String

    /// Parse verdict string to ScamVerdict enum
    var verdictEnum: ScamVerdict {
        ScamVerdict(rawValue: verdict) ?? .suspicious
    }

    /// Format the date for display
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.doesRelativeDateFormatting = true
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.doesRelativeDateFormatting = true
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return createdAt
    }

    /// Short preview of the subject/content
    var previewText: String {
        if subjectSnippet.isEmpty {
            return "No subject"
        }
        return subjectSnippet
    }
}

/// Response from the scan history API
struct ScanHistoryResponse: Codable {
    let scans: [ScanHistoryItem]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}
