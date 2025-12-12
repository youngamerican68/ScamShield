import SwiftUI
import Combine

/// ViewModel for the scan flow
@MainActor
class ScanViewModel: ObservableObject {
    // MARK: - Input State

    @Published var messageText: String = ""
    @Published var contextWhoFor: ContextWhoFor = .selfUser
    @Published var fromKnownContact: Bool = false

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
        scanState = .idle
    }

    /// Pre-populate with text (from Share Extension)
    func prePopulate(with text: String) {
        messageText = text
    }
}
