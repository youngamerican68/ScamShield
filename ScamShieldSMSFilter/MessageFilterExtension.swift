import IdentityLookup
import Contacts

/// SMS Filter Extension - Automatically filters incoming SMS from unknown senders
final class MessageFilterExtension: ILMessageFilterExtension {}

extension MessageFilterExtension: ILMessageFilterQueryHandling {

    /// Handle incoming SMS query from iOS
    func handle(_ queryRequest: ILMessageFilterQueryRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterQueryResponse) -> Void) {

        let response = ILMessageFilterQueryResponse()

        // Get sender and message body
        guard let sender = queryRequest.sender,
              let messageBody = queryRequest.messageBody else {
            response.action = .allow
            completion(response)
            return
        }

        // Check if sender is in trusted contacts
        if isKnownContact(phoneNumber: sender) {
            // Trusted contact - always allow
            response.action = .allow
            completion(response)
            return
        }

        // Analyze message content for scam patterns
        let scamScore = analyzeForScamPatterns(messageBody)

        if scamScore >= 0.7 {
            // High confidence scam
            response.action = .junk
            response.subAction = .none
        } else if scamScore >= 0.4 {
            // Suspicious - let through but could flag
            response.action = .allow
        } else {
            // Likely legitimate
            response.action = .allow
        }

        completion(response)
    }

    // MARK: - Contact Checking

    /// Check if phone number is in user's contacts
    private func isKnownContact(phoneNumber: String) -> Bool {
        // First check our cached trusted contacts from App Group
        if isTrustedContact(phoneNumber: phoneNumber) {
            return true
        }

        // Fallback: direct contacts lookup (if permission granted)
        return lookupInContacts(phoneNumber: phoneNumber)
    }

    /// Check against cached trusted contacts in App Group
    private func isTrustedContact(phoneNumber: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: "group.com.scamshield.shared"),
              let trustedNumbers = defaults.array(forKey: "trustedPhoneNumbers") as? [String] else {
            return false
        }

        let normalized = normalizePhoneNumber(phoneNumber)
        return trustedNumbers.contains { normalizePhoneNumber($0) == normalized }
    }

    /// Direct lookup in Contacts (requires permission)
    private func lookupInContacts(phoneNumber: String) -> Bool {
        let store = CNContactStore()

        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return false
        }

        let normalized = normalizePhoneNumber(phoneNumber)
        guard !normalized.isEmpty else { return false }

        let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: normalized))
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey as CNKeyDescriptor]

        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)
            return !contacts.isEmpty
        } catch {
            return false
        }
    }

    /// Normalize phone number for comparison
    private func normalizePhoneNumber(_ number: String) -> String {
        return number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    // MARK: - Scam Pattern Detection

    /// Analyze message for scam patterns (returns 0.0 - 1.0 score)
    private func analyzeForScamPatterns(_ message: String) -> Double {
        var score: Double = 0.0
        let lowercased = message.lowercased()

        // Urgency indicators
        let urgencyPatterns = [
            "urgent", "immediately", "act now", "expire", "limited time",
            "don't delay", "right away", "asap", "hurry"
        ]
        for pattern in urgencyPatterns {
            if lowercased.contains(pattern) {
                score += 0.15
            }
        }

        // Money/financial requests
        let moneyPatterns = [
            "send money", "wire transfer", "gift card", "bitcoin",
            "cash app", "venmo", "zelle", "bank account", "credit card",
            "ssn", "social security", "$"
        ]
        for pattern in moneyPatterns {
            if lowercased.contains(pattern) {
                score += 0.2
            }
        }

        // Threat/fear indicators
        let threatPatterns = [
            "arrested", "lawsuit", "warrant", "irs", "suspended",
            "locked", "compromised", "hacked", "illegal activity"
        ]
        for pattern in threatPatterns {
            if lowercased.contains(pattern) {
                score += 0.25
            }
        }

        // Prize/reward scams
        let prizePatterns = [
            "won", "winner", "congratulations", "prize", "lottery",
            "selected", "reward", "free"
        ]
        for pattern in prizePatterns {
            if lowercased.contains(pattern) {
                score += 0.15
            }
        }

        // Suspicious links
        let linkPatterns = [
            "click here", "click below", "click this", "bit.ly",
            "tinyurl", "verify your", "confirm your", "update your"
        ]
        for pattern in linkPatterns {
            if lowercased.contains(pattern) {
                score += 0.2
            }
        }

        // Impersonation attempts
        let impersonationPatterns = [
            "this is your bank", "amazon", "apple", "microsoft",
            "tech support", "customer service", "from your"
        ]
        for pattern in impersonationPatterns {
            if lowercased.contains(pattern) {
                score += 0.15
            }
        }

        // Cap at 1.0
        return min(score, 1.0)
    }
}
