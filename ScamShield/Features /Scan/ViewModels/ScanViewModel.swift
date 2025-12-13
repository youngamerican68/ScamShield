import SwiftUI
import Combine
import WidgetKit

/// ViewModel for the scan flow
@MainActor
class ScanViewModel: ObservableObject {
    // MARK: - Input State

    @Published var messageText: String = ""
    @Published var contextWhoFor: ContextWhoFor = .selfUser
    @Published var fromKnownContact: Bool = false

    // MARK: - Contact Detection State

    @Published var detectedContactName: String?
    @Published var contactsPermissionStatus: ContactsPermissionStatus = .notDetermined
    @Published var senderPhoneNumber: String?

    enum ContactsPermissionStatus {
        case notDetermined
        case authorized
        case denied
    }

    // MARK: - Scan State

    @Published var scanState: ScanState = .idle

    // MARK: - Computed Properties

    var canScan: Bool {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 8000
    }

    var characterCount: Int {
        messageText.count
    }

    var isOverLimit: Bool {
        messageText.count > 8000
    }

    var isScanning: Bool {
        if case .scanning = scanState { return true }
        return false
    }

    var result: ScamCheckResult? {
        if case .complete(let result) = scanState { return result }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = scanState { return message }
        return nil
    }

    // MARK: - Actions

    /// Start scanning the message
    func startScan() async {
        guard canScan else { return }

        // Trigger haptic
        HapticManager.shared.scanStart()

        // Set scanning state
        scanState = .scanning(phase: .searching)

        // Build input (don't log full text for privacy)
        let input = ScamCheckInput(
            text: messageText,
            contextWhoFor: contextWhoFor,
            fromKnownContact: fromKnownContact
        )

        #if DEBUG
        print("📤 Starting scan - length: \(messageText.count), context: \(contextWhoFor.rawValue), knownContact: \(fromKnownContact)")
        #endif

        // Simulate phase changes for UX (actual API call runs in parallel)
        let phaseTask = Task {
            for phase in ScanPhase.allCases.dropFirst() {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if !Task.isCancelled {
                    HapticManager.shared.scanPhaseChange()
                    scanState = .scanning(phase: phase)
                }
            }
        }

        // Make API call
        do {
            let result = try await ScamCheckAPI.shared.checkScam(input: input)

            // Cancel phase animation
            phaseTask.cancel()

            // Small delay for satisfaction
            try? await Task.sleep(nanoseconds: 300_000_000)

            // Reveal result with haptic
            HapticManager.shared.verdictReveal(result.verdict)
            scanState = .complete(result)

            // Save to shared UserDefaults for widget
            saveResultForWidget(result)

            #if DEBUG
            print("✅ Scan complete - verdict: \(result.verdict.rawValue), confidence: \(result.confidencePercent)")
            #endif

        } catch {
            phaseTask.cancel()

            HapticManager.shared.error()
            scanState = .error(error.localizedDescription)

            #if DEBUG
            print("❌ Scan failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Reset to scan another message
    func reset() {
        messageText = ""
        contextWhoFor = .selfUser
        fromKnownContact = false
        detectedContactName = nil
        senderPhoneNumber = nil
        scanState = .idle
    }

    /// Pre-populate with text (from Share Extension)
    func prePopulate(with text: String) {
        messageText = text
        // Try to detect contact from the message
        Task {
            await checkForKnownContact(phoneNumber: nil, messageText: text)
        }
    }

    /// Pre-populate with text and sender phone number (from Share Extension)
    func prePopulate(with text: String, senderPhone: String?) {
        messageText = text
        senderPhoneNumber = senderPhone
        // Try to detect contact
        Task {
            await checkForKnownContact(phoneNumber: senderPhone, messageText: text)
        }
    }

    // MARK: - Contact Detection

    /// Check contacts permission status on launch
    func checkContactsPermission() {
        let status = ContactsManager.shared.authorizationStatus
        switch status {
        case .authorized:
            contactsPermissionStatus = .authorized
        case .denied, .restricted:
            contactsPermissionStatus = .denied
        default:
            contactsPermissionStatus = .notDetermined
        }
    }

    /// Request contacts permission
    func requestContactsPermission() async -> Bool {
        let granted = await ContactsManager.shared.requestPermission()
        contactsPermissionStatus = granted ? .authorized : .denied
        return granted
    }

    /// Check if message is from a known contact
    func checkForKnownContact(phoneNumber: String? = nil, messageText: String? = nil) async {
        // First ensure we have permission
        var hasPermission = ContactsManager.shared.hasPermission
        if !hasPermission {
            // Try to request permission
            hasPermission = await requestContactsPermission()
        }

        guard hasPermission else { return }

        // Try the provided phone number first
        if let phone = phoneNumber, !phone.isEmpty {
            if let name = ContactsManager.shared.lookupContact(phoneNumber: phone) {
                detectedContactName = name
                fromKnownContact = true
                #if DEBUG
                print("📱 Detected known contact: \(name)")
                #endif
                return
            }
        }

        // Try to extract phone number from message text
        if let text = messageText ?? self.messageText.nilIfEmpty,
           let extractedPhone = ContactsManager.shared.extractPhoneNumber(from: text) {
            if let name = ContactsManager.shared.lookupContact(phoneNumber: extractedPhone) {
                detectedContactName = name
                fromKnownContact = true
                #if DEBUG
                print("📱 Detected known contact from message: \(name)")
                #endif
                return
            }
        }

        // No contact found
        detectedContactName = nil
        // Don't auto-set fromKnownContact to false - let user control it
    }

    /// Clear contact detection
    func clearContactDetection() {
        detectedContactName = nil
        senderPhoneNumber = nil
    }

    // MARK: - Widget Support

    /// Saves the last scan result to shared UserDefaults for the widget
    private func saveResultForWidget(_ result: ScamCheckResult) {
        guard let defaults = UserDefaults(suiteName: "group.com.scamshield.shared") else {
            #if DEBUG
            print("⚠️ Could not access shared UserDefaults")
            #endif
            return
        }

        // Create a simple struct that matches what the widget expects
        let widgetResult = [
            "verdict": result.verdict.rawValue,
            "summary": result.summary,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let data = try? JSONEncoder().encode(widgetResult) {
            defaults.set(data, forKey: "lastScanResult")
            #if DEBUG
            print("📱 Saved result for widget")
            #endif
        }

        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - String Extension

extension String {
    /// Returns nil if the string is empty or whitespace-only
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
