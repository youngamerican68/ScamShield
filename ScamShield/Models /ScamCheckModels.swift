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

/// Source of the scan - unified to text or email
enum ScanSource: String, Codable {
    case text = "text"
    case email = "email"
    // Legacy support for old records
    case emailForward = "email_forward"
    case clipboard = "clipboard"
    case shareExtension = "share_extension"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .text, .clipboard, .shareExtension, .manual:
            return "Text"
        case .email, .emailForward:
            return "Email"
        }
    }

    var icon: String {
        switch self {
        case .text, .clipboard, .shareExtension, .manual:
            return "message.fill"
        case .email, .emailForward:
            return "envelope.fill"
        }
    }

    /// Whether this is an email source (for filtering)
    var isEmail: Bool {
        switch self {
        case .email, .emailForward: return true
        default: return false
        }
    }
}

/// Status of a scan (processing or complete)
enum ScanStatus: String, Codable {
    case processing = "processing"
    case complete = "complete"

    /// Default to complete if not specified (backward compatibility)
    static var defaultValue: ScanStatus { .complete }
}

/// A scan record from the history API (unified model)
struct ScanHistoryItem: Codable, Identifiable {
    let id: String
    let userId: String
    let source: ScanSource
    // New unified fields
    let title: String?          // Display title (subject for email, snippet for text)
    let subtitle: String?       // "Pasted text" or fromDomain
    // Legacy fields (for backward compatibility)
    let subjectSnippet: String?
    let fromDomain: String?
    let messageId: String?
    // Common fields
    let verdict: String
    let summary: String
    let tactics: [String]
    let safeSteps: [String]
    let confidence: Double
    let createdAt: String
    // Status field (defaults to complete for backward compatibility)
    let status: ScanStatus?

    /// Computed status with default
    var scanStatus: ScanStatus {
        status ?? .complete
    }

    /// Parse verdict string to ScamVerdict enum
    var verdictEnum: ScamVerdict {
        ScamVerdict(rawValue: verdict) ?? .suspicious
    }

    /// Parse createdAt string to Date (for relative time formatting)
    var createdAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) {
            return date
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
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

    /// Display title - uses new title field or falls back to legacy subjectSnippet
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if let snippet = subjectSnippet, !snippet.isEmpty {
            return snippet
        }
        return source.isEmail ? "No subject" : "Pasted text"
    }

    /// Display subtitle - uses new subtitle field or falls back to legacy fromDomain
    var displaySubtitle: String {
        if let subtitle = subtitle, !subtitle.isEmpty {
            return subtitle
        }
        if source.isEmail, let domain = fromDomain, !domain.isEmpty {
            return domain
        }
        return source.displayName
    }

    /// Short preview of the subject/content (legacy compatibility)
    var previewText: String {
        displayTitle
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
