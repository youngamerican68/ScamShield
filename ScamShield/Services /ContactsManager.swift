import Foundation
import Contacts

/// Manages contact lookups for known contact detection
class ContactsManager {
    static let shared = ContactsManager()

    private let store = CNContactStore()

    private init() {}

    // MARK: - Permission

    /// Current authorization status
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Whether we have permission to access contacts
    var hasPermission: Bool {
        authorizationStatus == .authorized
    }

    /// Request permission to access contacts
    func requestPermission() async -> Bool {
        // Already authorized
        if authorizationStatus == .authorized {
            return true
        }

        // Already denied - can't ask again
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            return false
        }

        // Request access
        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted
        } catch {
            #if DEBUG
            print("❌ Contacts permission error: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Contact Lookup

    /// Check if a phone number exists in the user's contacts
    /// Returns the contact name if found, nil otherwise
    func lookupContact(phoneNumber: String) -> String? {
        guard hasPermission else { return nil }

        // Normalize the phone number (remove non-digits)
        let normalizedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        guard !normalizedNumber.isEmpty else { return nil }

        // Search for contacts with this phone number
        let predicate = CNContact.predicateForContacts(matching: CNPhoneNumber(stringValue: normalizedNumber))
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactNicknameKey as CNKeyDescriptor
        ]

        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

            if let contact = contacts.first {
                // Return the best available name
                if !contact.nickname.isEmpty {
                    return contact.nickname
                } else if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                    return "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                }
                return "Saved Contact"
            }
        } catch {
            #if DEBUG
            print("❌ Contact lookup error: \(error)")
            #endif
        }

        return nil
    }

    /// Check if a phone number is from a known contact
    func isKnownContact(phoneNumber: String) -> Bool {
        return lookupContact(phoneNumber: phoneNumber) != nil
    }

    /// Extract phone number from a message string (basic extraction)
    /// This tries to find phone number patterns in the text
    func extractPhoneNumber(from text: String) -> String? {
        // Common phone number patterns
        let patterns = [
            // International format: +1 234 567 8900
            "\\+?\\d{1,3}[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}",
            // Simple 10-digit: 2345678900
            "\\d{10}",
            // With area code: (234) 567-8900
            "\\(\\d{3}\\)\\s?\\d{3}[-.\\s]?\\d{4}"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }

        return nil
    }
}

// MARK: - Contact Detection Result

struct ContactDetectionResult {
    let isKnownContact: Bool
    let contactName: String?

    static let unknown = ContactDetectionResult(isKnownContact: false, contactName: nil)
}
