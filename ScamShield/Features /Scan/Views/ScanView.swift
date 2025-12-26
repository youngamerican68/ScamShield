import SwiftUI
import UIKit

/// Check mode toggle
enum CheckMode: Int {
    case text = 0
    case email = 1
}

/// Main scan screen - MVP version with Text/Email tabs
struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @StateObject private var emailViewModel = EmailModeViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showHistory = false

    // Mode toggle
    @AppStorage("selectedCheckMode") private var selectedMode: Int = 0
    private var checkMode: CheckMode {
        CheckMode(rawValue: selectedMode) ?? .text
    }

    // Email mode state
    @AppStorage("hasSavedScamContact") private var hasSavedScamContact: Bool = false
    @AppStorage("emailHelpExpanded") private var emailHelpExpanded: Bool = true
    @State private var showBackupAddress: Bool = false
    @State private var contactSetupAttempted: Bool = false  // Track if user has tried setup

    // Computed: should steps be expanded by default?
    private var shouldExpandStepsByDefault: Bool {
        !hasSavedScamContact || !emailViewModel.hasEmailScans
    }

    // Text tab state - NO auto-paste, user-initiated only
    @State private var isPasting: Bool = false
    @State private var pasteError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundView

                // Content based on state
                Group {
                    switch viewModel.scanState {
                    case .idle:
                        scanInputView
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                    case .scanning(let phase):
                        ScanningView(phase: phase)
                            .transition(.opacity)

                    case .complete(let result):
                        ResultsView(result: result, onScanAnother: viewModel.reset)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                    case .error(let message):
                        errorView(message: message)
                            .transition(.opacity)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.cloud)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.cloud)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showHistory) {
                NavigationStack {
                    ScanHistoryView()
                }
            }
        }
        .onAppear {
            viewModel.checkContactsPermission()
            handleSharedContent()
        }
        .onChange(of: appState.sharedText) { newText in
            if newText != nil {
                handleSharedContent()
            }
        }
        // NOTE: Removed auto-paste on scene phase changes
        // Clipboard reading is now user-initiated only via "Paste message" button
    }

    // MARK: - Background

    private var backgroundView: some View {
        AppGradients.nocturneUpper
            .ignoresSafeArea()
    }

    // MARK: - Scan Input View

    private var scanInputView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header (owl logo + title)
                headerSection

                // Mode Toggle (Text | Email)
                modeToggle

                // Content based on mode
                if checkMode == .text {
                    textModeContent
                } else {
                    emailModeContent
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 8) {
            // Text tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMode = 0
                }
                HapticManager.shared.buttonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                    Text("Text")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(selectedMode == 0 ? .navy : .cloud)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedMode == 0 ? Color.sunrise : Color.navyLight)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cloud.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Email tab
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedMode = 1
                }
                HapticManager.shared.buttonTap()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 16))
                    Text("Email")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(selectedMode == 1 ? .navy : .cloud)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedMode == 1 ? Color.sunrise : Color.navyLight)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cloud.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Text Mode Content (State-Based)

    private var textModeContent: some View {
        VStack(spacing: 16) {
            if viewModel.messageText.isEmpty {
                // EMPTY STATE: Show "Paste message" as primary CTA
                textEmptyStateContent
            } else {
                // HAS TEXT STATE: Show message preview + "Check message" as primary CTA
                textHasContentState
            }

            // Trust Indicators (always at bottom)
            trustIndicators
        }
    }

    // MARK: - Text Tab Empty State

    private var textEmptyStateContent: some View {
        VStack(spacing: 16) {
            // Primary CTA: Paste message button
            pasteMessageButton

            // How it works (compact, not the main focus)
            howItWorksCard
        }
    }

    // MARK: - Text Tab Has Content State

    private var textHasContentState: some View {
        VStack(spacing: 16) {
            // Message preview
            messagePreviewBox

            // Primary CTA: Check message
            checkMessageButton

            // Secondary: Clear (text style, non-primary)
            // Already included in messagePreviewBox header
        }
    }

    // MARK: - Paste Message Button (Primary CTA when empty)

    private var pasteMessageButton: some View {
        VStack(spacing: 12) {
            // Primary button - user-initiated paste
            Button {
                pasteFromClipboard()
            } label: {
                HStack(spacing: 10) {
                    if isPasting {
                        ProgressView()
                            .tint(.midnight)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    Text(isPasting ? "Pasting..." : "Paste Message")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundColor(.midnight)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [Color.sunrise, Color.ember],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.ember.opacity(0.5), radius: 12, y: 6)
            }
            .disabled(isPasting)
            .accessibilityLabel("Paste message from clipboard")

            // Error message if paste failed
            if let error = pasteError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.verdictWarning)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Paste from Clipboard (user-initiated)

    private func pasteFromClipboard() {
        isPasting = true
        pasteError = nil

        // Small delay for visual feedback
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Read clipboard - this triggers iOS "Allow Paste" dialog if needed
            if let text = UIPasteboard.general.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.prePopulate(with: String(text.prefix(8000)), senderPhone: nil)
                HapticManager.shared.success()
            } else {
                pasteError = "Nothing to paste. Copy a message first."
                HapticManager.shared.error()
            }

            isPasting = false
        }
    }

    // MARK: - Check Message Button (Primary CTA when has text)

    private var checkMessageButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.startScan()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Check Message")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundColor(.midnight)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [Color.sunrise, Color.ember],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.ember.opacity(0.5), radius: 12, y: 6)
            }
            .accessibilityLabel("Check this message for scams")

            Text("We'll explain what looks risky and what to do next")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.cloud.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - How It Works Card (Compact instructions)

    private var howItWorksCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("HOW IT WORKS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cloud.opacity(0.6))
                    .tracking(0.5)

                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(number: "1", text: "Copy the suspicious message")
                    instructionRow(number: "2", text: "Come back to Scam Shield and tap 'Paste Message'")
                }

                // Note about iOS permission
                Text("If your iPhone asks permission to paste, tap Allow.")
                    .font(.system(size: 13))
                    .foregroundColor(.cloud.opacity(0.5))
                    .italic()
            }
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.midnight)
                .frame(width: 22, height: 22)
                .background(Color.sunrise)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: - Email Mode Content (State-Based Layout)

    private var emailModeContent: some View {
        VStack(spacing: 14) {
            if hasSavedScamContact {
                // SETUP DONE: Status first (with primary button), then collapsed steps
                emailStatusCardFull

                emailStepsCardCollapsible

            } else {
                // SETUP NEEDED: Setup first, steps second, compact status last
                emailSetupCard

                emailStepsCardExpanded

                emailStatusCardCompact
            }

            // Backup address link
            if !showBackupAddress {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBackupAddress = true
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 14))
                        Text("Need the scan address instead?")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.cloud.opacity(0.6))
                    .frame(height: 44)
                }
                .accessibilityLabel("Show backup email address")
            }

            if showBackupAddress {
                backupAddressCard
            }
        }
        .onAppear {
            Task {
                await emailViewModel.loadRecentScans()
            }
            // Sync contact saved state from ViewModel to AppStorage
            if emailViewModel.isScamShieldContactSaved && !hasSavedScamContact {
                hasSavedScamContact = true
            }
            // Set default expansion: collapsed when setup done, expanded when not
            if !hasSavedScamContact && !emailHelpExpanded {
                emailHelpExpanded = true
            } else if hasSavedScamContact && emailHelpExpanded && emailViewModel.hasEmailScans {
                // Auto-collapse steps after setup is done and user has scans
                emailHelpExpanded = false
            }
        }
    }

    // MARK: - Email Setup Card (ONE-TIME SETUP)

    private var emailSetupCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ONE-TIME SETUP")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.sunrise)
                    .tracking(0.5)

                Text("Add Scam Shield to your contacts so you can quickly forward emails.")
                    .font(.system(size: 15))
                    .foregroundColor(.cloud.opacity(0.8))

                // Primary save button (ONLY filled/orange button when setup not done)
                Button {
                    contactSetupAttempted = true
                    Task {
                        await emailViewModel.saveScamShieldContact()
                        if emailViewModel.isScamShieldContactSaved {
                            hasSavedScamContact = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if emailViewModel.isSavingContact {
                            ProgressView()
                                .tint(.midnight)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 18))
                        }
                        Text(emailViewModel.isSavingContact ? "Saving..." : "Add Scam Shield to Contacts")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.midnight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color.sunrise, Color.ember],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(emailViewModel.isSavingContact)
                .accessibilityLabel("Add Scam Shield to Contacts")

                // Error recovery UI - only shown AFTER user has attempted setup
                if contactSetupAttempted, let error = emailViewModel.contactSaveError {
                    contactsErrorRecoveryView(error: error)
                }
            }
        }
    }

    // MARK: - Contacts Error Recovery UI

    private func contactsErrorRecoveryView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Divider
            Rectangle()
                .fill(Color.cloud.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, 4)

            // Calm error message (not scary red)
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.verdictWarning)
                Text("Contacts access is off")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.verdictWarning)
            }

            // Open Settings button (secondary style)
            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                    Text("Open Settings")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.sunrise)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.sunrise.opacity(0.15))
                .cornerRadius(10)
            }
            .accessibilityLabel("Open Settings to allow Contacts access")

            // Fallback option
            VStack(alignment: .leading, spacing: 8) {
                Text("Prefer not to use Contacts?")
                    .font(.system(size: 13))
                    .foregroundColor(.cloud.opacity(0.6))

                // Scan address with copy button
                HStack {
                    Text(emailViewModel.emailScanAddress)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.cloud)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        emailViewModel.copyEmailAddress()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: emailViewModel.showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(emailViewModel.showCopiedConfirmation ? "Copied!" : "Copy")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.sunrise)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.sunrise.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
                .padding(10)
                .background(Color.midnight.opacity(0.3))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Email Steps Card (Expanded - for setup flow)

    private var emailStepsCardExpanded: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("EVERY TIME YOU FORWARD")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cloud.opacity(0.6))
                    .tracking(0.5)

                VStack(alignment: .leading, spacing: 10) {
                    emailStepRow(number: "1", text: "Tap Forward in your email")
                    emailStepRow(number: "2", text: "Type \"Scam\", select Scam Shield", highlight: "Scam")
                    emailStepRow(number: "3", text: "Tap Send, then come back here")
                }
            }
        }
    }

    // MARK: - Email Steps Card (Collapsible - for post-setup)

    private var emailStepsCardCollapsible: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                // Header with expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        emailHelpExpanded.toggle()
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15))
                            .foregroundColor(.cloud.opacity(0.5))

                        Text("How to forward an email")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.cloud.opacity(0.7))

                        Spacer()

                        Image(systemName: emailHelpExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.cloud.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emailHelpExpanded ? "Hide steps" : "Show steps")

                // Collapsible content
                if emailHelpExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        emailStepRow(number: "1", text: "Tap Forward in your email")
                        emailStepRow(number: "2", text: "Type \"Scam\", select Scam Shield", highlight: "Scam")
                        emailStepRow(number: "3", text: "Tap Send, then come back here")
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Message Preview Box (always visible)

    private var messagePreviewBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message to check:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if !viewModel.messageText.isEmpty {
                    Button {
                        viewModel.messageText = ""
                        HapticManager.shared.buttonTap()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.sunrise)
                    }
                }
            }

            GlassCard(padding: 16) {
                if viewModel.messageText.isEmpty {
                    Text("Your message will appear here...")
                        .font(.system(size: 17))
                        .foregroundColor(.cloud.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                } else {
                    Text(viewModel.messageText)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            // Animated Owl Logo with glow
            AnimatedOwlView(size: 160)
                .background(
                    Circle()
                        .fill(Color.sunrise.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 35)
                )
                .shadow(color: .sunrise.opacity(0.5), radius: 25, y: 4)

            // Title
            Text("Scam Shield")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, -8)
        }
    }

    // MARK: - Trust Indicators

    private var trustIndicators: some View {
        // Using flexible layout that wraps gracefully at large text sizes
        ViewThatFits {
            // Preferred: 2x2 grid
            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    trustBadge(icon: "lock.shield", text: "Checked securely")
                    trustBadge(icon: "xmark.circle", text: "No ads ever")
                }
                HStack(spacing: 16) {
                    trustBadge(icon: "hand.raised", text: "We never text back")
                    trustBadge(icon: "eye.slash", text: "Privacy-first")
                }
            }

            // Fallback for large text: vertical stack
            VStack(spacing: 4) {
                trustBadge(icon: "lock.shield", text: "Checked securely")
                trustBadge(icon: "xmark.circle", text: "No ads ever")
                trustBadge(icon: "hand.raised", text: "We never text back")
                trustBadge(icon: "eye.slash", text: "Privacy-first")
            }
        }
        .padding(.top, 8)
    }

    private func trustBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.sunrise)
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.verdictWarning)

            Text("Something went wrong")
                .font(AppTypography.cardTitle)
                .foregroundColor(.starlight)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(.cloud)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            PrimaryButton("Try Again", icon: "arrow.clockwise") {
                viewModel.scanState = .idle
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Handle Shared Content (from Share Extension)

    private func handleSharedContent() {
        guard let text = appState.sharedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Populate text field
        viewModel.prePopulate(with: String(text.prefix(8000)), senderPhone: nil)

        // Clear app state
        let shouldAutoScan = appState.shouldAutoScan
        appState.sharedText = nil
        appState.shouldAutoScan = false

        // Auto-scan only for share extension (not clipboard paste)
        if shouldAutoScan {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // Brief delay for UI
                await viewModel.startScan()
            }
        }
    }

    private func emailStepRow(number: String, text: String, highlight: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.midnight)
                .frame(width: 24, height: 24)
                .background(Color.sunrise)
                .clipShape(Circle())

            if let highlight = highlight, let range = text.range(of: highlight) {
                let before = String(text[..<range.lowerBound])
                let after = String(text[range.upperBound...])
                (Text(before).foregroundColor(.white) +
                 Text(highlight).foregroundColor(.sunrise).bold() +
                 Text(after).foregroundColor(.white))
                    .font(.system(size: 16, weight: .medium))
            } else {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Email Status Card (Full - with primary button, for post-setup)

    private var emailStatusCardFull: some View {
        GlassCard(padding: 16) {
            VStack(spacing: 14) {
                // Header
                Text("STATUS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cloud.opacity(0.5))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Status row
                HStack(spacing: 12) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(emailViewModel.isNewestScanProcessing ? Color.sunrise.opacity(0.2) : Color.glassWhite)
                            .frame(width: 44, height: 44)

                        if emailViewModel.isNewestScanProcessing {
                            ProgressView()
                                .tint(.sunrise)
                                .scaleEffect(0.9)
                        } else if emailViewModel.hasEmailScans {
                            if let newest = emailViewModel.newestEmailScan {
                                verdictIcon(for: newest.verdict)
                            }
                        } else {
                            Image(systemName: "envelope.badge.clock")
                                .font(.system(size: 20))
                                .foregroundColor(.cloud.opacity(0.6))
                        }
                    }

                    // Status text
                    VStack(alignment: .leading, spacing: 3) {
                        if emailViewModel.isNewestScanProcessing {
                            Text("Scanning your email...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.sunrise)
                            Text("This usually takes a moment.")
                                .font(.system(size: 13))
                                .foregroundColor(.cloud.opacity(0.6))
                        } else if emailViewModel.hasEmailScans, let newest = emailViewModel.newestEmailScan {
                            Text(verdictLabel(for: newest.verdict))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(verdictColor(for: newest.verdict))
                            Text("Received \(emailViewModel.newestScanRelativeTime)")
                                .font(.system(size: 13))
                                .foregroundColor(.cloud.opacity(0.6))
                        } else {
                            Text("Waiting for your email...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.cloud)
                            Text("After you send one, the result will show here.")
                                .font(.system(size: 13))
                                .foregroundColor(.cloud.opacity(0.6))
                        }
                    }

                    Spacer()
                }

                // Primary "Check for Results" button
                Button {
                    Task {
                        await emailViewModel.checkForNewScans()
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if emailViewModel.isLoadingScans {
                            ProgressView()
                                .tint(.midnight)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(emailViewModel.isLoadingScans ? "Checking..." : "Check for Results")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.midnight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.sunrise, Color.ember],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(emailViewModel.isLoadingScans)
                .accessibilityLabel("Check for results")
            }
        }
    }

    // MARK: - Email Status Card (Compact - with small refresh, for setup flow)

    private var emailStatusCardCompact: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                // Status icon (smaller)
                ZStack {
                    Circle()
                        .fill(emailViewModel.isNewestScanProcessing ? Color.sunrise.opacity(0.2) : Color.glassWhite)
                        .frame(width: 36, height: 36)

                    if emailViewModel.isNewestScanProcessing {
                        ProgressView()
                            .tint(.sunrise)
                            .scaleEffect(0.7)
                    } else if emailViewModel.hasEmailScans {
                        if let newest = emailViewModel.newestEmailScan {
                            verdictIcon(for: newest.verdict)
                                .scaleEffect(0.85)
                        }
                    } else {
                        Image(systemName: "envelope.badge.clock")
                            .font(.system(size: 16))
                            .foregroundColor(.cloud.opacity(0.5))
                    }
                }

                // Status text
                VStack(alignment: .leading, spacing: 2) {
                    if emailViewModel.hasEmailScans, let newest = emailViewModel.newestEmailScan {
                        Text(verdictLabel(for: newest.verdict))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(verdictColor(for: newest.verdict))
                        Text("Received \(emailViewModel.newestScanRelativeTime)")
                            .font(.system(size: 12))
                            .foregroundColor(.cloud.opacity(0.5))
                    } else {
                        Text("Waiting for your email...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.cloud.opacity(0.7))
                    }
                }

                Spacer()

                // Small refresh button (secondary)
                Button {
                    Task {
                        await emailViewModel.checkForNewScans()
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    if emailViewModel.isLoadingScans {
                        ProgressView()
                            .tint(.sunrise)
                            .scaleEffect(0.8)
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.sunrise)
                            .frame(width: 36, height: 36)
                            .background(Color.sunrise.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .disabled(emailViewModel.isLoadingScans)
                .accessibilityLabel("Refresh")
            }
        }
    }

    // Verdict display helpers
    private func verdictIcon(for verdict: String) -> some View {
        let (icon, color) = verdictIconAndColor(for: verdict)
        return Image(systemName: icon)
            .font(.system(size: 22))
            .foregroundColor(color)
    }

    private func verdictIconAndColor(for verdict: String) -> (String, Color) {
        switch verdict.lowercased() {
        case "safe", "low":
            return ("checkmark.shield.fill", .verdictSafe)
        case "caution", "medium", "warning":
            return ("exclamationmark.triangle.fill", .verdictWarning)
        case "danger", "high", "scam":
            return ("xmark.shield.fill", .verdictDanger)
        default:
            return ("questionmark.circle.fill", .cloud)
        }
    }

    private func verdictLabel(for verdict: String) -> String {
        switch verdict.lowercased() {
        case "safe", "low":
            return "✓ Looks Safe"
        case "caution", "medium", "warning":
            return "⚠ Be Careful"
        case "danger", "high", "scam":
            return "⛔ Likely a Scam"
        default:
            return verdict.capitalized
        }
    }

    private func verdictColor(for verdict: String) -> Color {
        switch verdict.lowercased() {
        case "safe", "low":
            return .verdictSafe
        case "caution", "medium", "warning":
            return .verdictWarning
        case "danger", "high", "scam":
            return .verdictDanger
        default:
            return .cloud
        }
    }

    // MARK: - Backup Address Card

    private var backupAddressCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BACKUP: EMAIL ADDRESS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cloud.opacity(0.5))
                    .tracking(0.5)

                Text("Forward suspicious emails to:")
                    .font(.system(size: 14))
                    .foregroundColor(.cloud.opacity(0.7))

                HStack {
                    Text(emailViewModel.emailScanAddress)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        emailViewModel.copyEmailAddress()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: emailViewModel.showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14))
                            Text(emailViewModel.showCopiedConfirmation ? "Copied!" : "Copy")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.sunrise)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.sunrise.opacity(0.15))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    ScanView()
        .environmentObject(AppState())
}
