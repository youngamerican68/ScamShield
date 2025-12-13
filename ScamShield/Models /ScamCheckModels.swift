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
