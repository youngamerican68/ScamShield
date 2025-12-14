import Foundation
import Contacts
import ContactsUI

/// Manages contact lookups for known contact detection
class ContactsManager {
    static let shared = ContactsManager()

    private let store = CNContactStore()

    // Key for tracking if Scam Shield contact was saved
    private let scamShieldContactSavedKey = "scamShieldContactSaved"

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

// MARK: - Scam Shield Contact Saving

extension ContactsManager {

    /// Check if Scam Shield contact has been saved
    var isScamShieldContactSaved: Bool {
        UserDefaults.standard.bool(forKey: scamShieldContactSavedKey)
    }

    /// Create a CNMutableContact for Scam Shield with the email scan address
    func createScamShieldContact(emailAddress: String) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = "Scam Shield"
        contact.organizationName = "Scam Shield"
        contact.note = "Forward suspicious emails to this address for instant scam checking."

        // Add email address
        let email = CNLabeledValue(
            label: CNLabelWork,
            value: emailAddress as NSString
        )
        contact.emailAddresses = [email]

        return contact
    }

    /// Save the Scam Shield contact directly (requires permission)
    func saveScamShieldContact(emailAddress: String) async throws {
        guard hasPermission else {
            throw ContactSaveError.permissionDenied
        }

        let contact = createScamShieldContact(emailAddress: emailAddress)
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)

        try store.execute(saveRequest)

        // Mark as saved
        UserDefaults.standard.set(true, forKey: scamShieldContactSavedKey)
    }

    /// Check if a contact with email "scamshield.app" exists
    func checkScamShieldContactExists() -> Bool {
        guard hasPermission else { return false }

        let predicate = CNContact.predicateForContacts(matchingName: "Scam Shield")
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor
        ]

        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            for contact in contacts {
                for email in contact.emailAddresses {
                    let emailString = email.value as String
                    if emailString.contains("scamshield.app") {
                        // Found it - update our saved flag
                        UserDefaults.standard.set(true, forKey: scamShieldContactSavedKey)
                        return true
                    }
                }
            }
        } catch {
            #if DEBUG
            print("❌ Error checking for Scam Shield contact: \(error)")
            #endif
        }

        return false
    }

    /// Reset the saved flag (for testing)
    func resetScamShieldContactSaved() {
        UserDefaults.standard.set(false, forKey: scamShieldContactSavedKey)
    }
}

enum ContactSaveError: LocalizedError {
    case permissionDenied
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Please allow access to Contacts in Settings to save the Scam Shield contact."
        case .saveFailed(let error):
            return "Failed to save contact: \(error.localizedDescription)"
        }
    }
}

// MARK: - Contact Detection Result

struct ContactDetectionResult {
    let isKnownContact: Bool
    let contactName: String?

    static let unknown = ContactDetectionResult(isKnownContact: false, contactName: nil)
}
