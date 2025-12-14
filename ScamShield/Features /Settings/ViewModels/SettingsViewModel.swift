import SwiftUI
import Contacts
import ContactsUI

/// ViewModel for Settings screen
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isSMSFilterEnabled: Bool = false
    @Published var trustedContactCount: Int = 0
    @Published var contactsPermissionGranted: Bool = false
    @Published var isSyncing: Bool = false

    // Email scanning state
    @Published var isScamShieldContactSaved: Bool = false
    @Published var isSavingContact: Bool = false
    @Published var contactSaveError: String?
    @Published var showContactSaveSuccess: Bool = false

    private let sharedDefaults = UserDefaults(suiteName: "group.com.scamshield.shared")

    /// The user's unique email scan address
    var emailScanAddress: String {
        APIConfig.emailScanAddress
    }

    // MARK: - SMS Filter Status

    func checkSMSFilterStatus() {
        // We can't directly check if our SMS filter is enabled
        // We store a flag when user confirms they've enabled it
        isSMSFilterEnabled = sharedDefaults?.bool(forKey: "smsFilterEnabled") ?? false
    }

    // MARK: - Contacts Permission

    func requestContactsPermission() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsPermissionGranted = granted
            if granted {
                await syncTrustedContacts()
            }
        } catch {
            contactsPermissionGranted = false
        }
    }

    // MARK: - Trusted Contacts

    func loadTrustedContacts() {
        contactsPermissionGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized

        if let numbers = sharedDefaults?.array(forKey: "trustedPhoneNumbers") as? [String] {
            trustedContactCount = numbers.count
        }
    }

    func syncTrustedContacts() async {
        guard contactsPermissionGranted else { return }

        isSyncing = true
        defer { isSyncing = false }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]

        var allPhoneNumbers: [String] = []

        do {
            let request = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: request) { contact, _ in
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let normalized = self.normalizePhoneNumber(number)
                    if !normalized.isEmpty && !allPhoneNumbers.contains(normalized) {
                        allPhoneNumbers.append(normalized)
                    }
                }
            }

            // Save to App Group
            sharedDefaults?.set(allPhoneNumbers, forKey: "trustedPhoneNumbers")
            sharedDefaults?.set(Date(), forKey: "trustedContactsLastSync")

            trustedContactCount = allPhoneNumbers.count

            HapticManager.shared.success()
        } catch {
            HapticManager.shared.error()
        }
    }

    private func normalizePhoneNumber(_ number: String) -> String {
        return number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    // MARK: - Open Settings

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }

        // Mark that user has been guided to enable SMS filter
        // They'll need to confirm when they return
        sharedDefaults?.set(true, forKey: "smsFilterSetupStarted")
    }

    func confirmSMSFilterEnabled() {
        sharedDefaults?.set(true, forKey: "smsFilterEnabled")
        isSMSFilterEnabled = true
        HapticManager.shared.success()
    }

    // MARK: - Email Scanning / Scam Shield Contact

    /// Check if the Scam Shield contact is already saved
    func checkScamShieldContactStatus() {
        // First check our flag
        isScamShieldContactSaved = ContactsManager.shared.isScamShieldContactSaved

        // If permission granted, also verify the contact actually exists
        if contactsPermissionGranted && !isScamShieldContactSaved {
            isScamShieldContactSaved = ContactsManager.shared.checkScamShieldContactExists()
        }
    }

    /// Save the Scam Shield contact to the user's contacts
    func saveScamShieldContact() async {
        isSavingContact = true
        contactSaveError = nil

        defer { isSavingContact = false }

        // First ensure we have permission
        if !contactsPermissionGranted {
            let granted = await requestContactsPermissionForSave()
            if !granted {
                contactSaveError = "Please allow Contacts access to save the Scam Shield contact."
                HapticManager.shared.error()
                return
            }
        }

        // Save the contact
        do {
            try await ContactsManager.shared.saveScamShieldContact(emailAddress: emailScanAddress)
            isScamShieldContactSaved = true
            showContactSaveSuccess = true
            HapticManager.shared.success()

            // Auto-dismiss success message after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showContactSaveSuccess = false
        } catch {
            contactSaveError = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    /// Request contacts permission specifically for saving the contact
    private func requestContactsPermissionForSave() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsPermissionGranted = granted
            return granted
        } catch {
            return false
        }
    }

    /// Copy the email scan address to clipboard
    func copyEmailAddress() {
        UIPasteboard.general.string = emailScanAddress
        HapticManager.shared.buttonTap()
    }
}
