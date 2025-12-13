import SwiftUI
import Contacts

/// ViewModel for Settings screen
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isSMSFilterEnabled: Bool = false
    @Published var trustedContactCount: Int = 0
    @Published var contactsPermissionGranted: Bool = false
    @Published var isSyncing: Bool = false

    private let sharedDefaults = UserDefaults(suiteName: "group.com.scamshield.shared")

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
}
