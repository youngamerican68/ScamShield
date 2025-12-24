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
    @State private var showBackupAddress: Bool = false

    // Clipboard tracking - persist across launches to avoid repeat prompting
    @AppStorage("pasteboardLastHandledChangeCount") private var lastHandledChangeCount: Int = 0
    @AppStorage("pasteboardLastDismissedChangeCount") private var lastDismissedChangeCount: Int = 0
    @State private var showClipboardBanner = false
    @State private var clipboardBannerState: ClipboardBannerState = .ready
    @State private var hasEnteredBackground = false

    private enum ClipboardBannerState {
        case ready
        case scanning
        case error
    }

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
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                hasEnteredBackground = true
            } else if newPhase == .active {
                // Only auto-scan clipboard when RETURNING from background, not on initial launch
                if hasEnteredBackground {
                    checkClipboardAvailability()
                }
            }
        }
        .onChange(of: viewModel.scanState) { newState in
            // Re-check clipboard when returning to idle (after "Scan Another")
            if case .idle = newState {
                checkClipboardAvailability()
            }
        }
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
                // Clipboard Banner (shown above header when available) - Text mode only
                if showClipboardBanner && checkMode == .text {
                    clipboardBannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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

    // MARK: - Text Mode Content

    private var textModeContent: some View {
        VStack(spacing: 16) {
            // Step-by-step instructions in a card
            howToCopySection

            // Message preview box (always visible so user sees where text goes)
            messagePreviewBox

            // Check Message button (shown after paste)
            if !viewModel.messageText.isEmpty {
                scanButtonSection
            }

            // Trust Indicators
            trustIndicators
        }
    }

    // MARK: - Email Mode Content

    private var emailModeContent: some View {
        VStack(spacing: 16) {
            // Combined setup + steps card
            emailInstructionsCard

            // Status card
            emailStatusCard

            // Backup address link
            if !showBackupAddress {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBackupAddress = true
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                        Text("Can't find the contact? Use email address instead")
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

            // Recent Email Scans (only if there are scans)
            if emailViewModel.hasEmailScans {
                recentEmailScansSection
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
        }
    }

    // MARK: - Clipboard Banner (Primary CTA for elderly users)

    private var clipboardBannerView: some View {
        VStack(spacing: 14) {
            // Main scan button - BIG and obvious for elderly users
            // Minimum 56-64pt height for easy tapping
            Button {
                scanFromClipboard()
            } label: {
                HStack(spacing: 14) {
                    switch clipboardBannerState {
                    case .ready:
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 28))
                        Text("Scan Copied Message")
                            .font(.system(size: 20, weight: .bold))

                    case .scanning:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .midnight))
                            .scaleEffect(1.2)
                        Text("Scanning...")
                            .font(.system(size: 20, weight: .bold))

                    case .error:
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 28))
                        Text("Try Again")
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .foregroundColor(.midnight)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60) // Minimum 60pt for elderly accessibility
                .padding(.vertical, 4)
                .background(clipboardBannerState == .error ? Color.verdictWarning : Color.sunrise)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: (clipboardBannerState == .error ? Color.verdictWarning : Color.sunrise).opacity(0.4), radius: 8, y: 4)
            }
            .disabled(clipboardBannerState == .scanning)
            .accessibilityLabel(clipboardBannerState == .ready ? "Scan Message I Copied" : clipboardBannerState == .scanning ? "Scanning in progress" : "Try again")
            .accessibilityHint("Double tap to scan the message you copied")


            // "Not now" option (friendlier than "Dismiss") - hidden during scanning
            if clipboardBannerState != .scanning {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        lastDismissedChangeCount = UIPasteboard.general.changeCount
                        showClipboardBanner = false
                        clipboardBannerState = .ready
                    }
                } label: {
                    Text("Not now")
                        .font(.system(size: 14))
                        .foregroundColor(.cloud.opacity(0.5))
                }
                .accessibilityLabel("Not now")
                .accessibilityHint("Hide this prompt. It will reappear when you copy a new message.")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.midnight.opacity(0.6))
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke((clipboardBannerState == .error ? Color.verdictWarning : Color.sunrise).opacity(0.5), lineWidth: 1.5)
                )
        )
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

    // MARK: - How To Copy Instructions

    private var howToCopySection: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                Text("HOW TO CHECK A MESSAGE:")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.sunrise)
                    .tracking(0.5)

                // Step 1
                HStack(alignment: .top, spacing: 12) {
                    Text("1️⃣")
                        .font(.system(size: 24))
                    Text("Hold your finger on the suspicious message")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Step 2
                HStack(alignment: .top, spacing: 12) {
                    Text("2️⃣")
                        .font(.system(size: 24))
                    Text("Tap \"Copy\" when menu appears")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Step 3
                HStack(alignment: .top, spacing: 12) {
                    Text("3️⃣")
                        .font(.system(size: 24))
                    Text("Come back here and tap Allow Paste")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Scan Button

    private var scanButtonSection: some View {
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

            Text("We'll explain what looks risky and what to do next")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.cloud.opacity(0.7))
                .multilineTextAlignment(.center)
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

        // Hide clipboard banner since we have content
        showClipboardBanner = false

        // Auto-scan only for share extension (not clipboard)
        if shouldAutoScan {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // Brief delay for UI
                await viewModel.startScan()
            }
        }
    }

    // MARK: - Clipboard Detection (triggers "Allow Paste" immediately)

    private func checkClipboardAvailability() {
        // Don't check if we're not in idle state or already have text
        guard case .idle = viewModel.scanState,
              viewModel.messageText.isEmpty else {
            showClipboardBanner = false
            return
        }

        // Non-invasive check first
        guard UIPasteboard.general.hasStrings else {
            showClipboardBanner = false
            return
        }

        // Check change count to avoid repeat prompts for same clipboard content
        let currentChangeCount = UIPasteboard.general.changeCount
        if currentChangeCount == lastHandledChangeCount ||
           currentChangeCount == lastDismissedChangeCount {
            showClipboardBanner = false
            return
        }

        // Read clipboard - this triggers iOS "Allow Paste" dialog
        guard let clipboardText = UIPasteboard.general.string else {
            showClipboardBanner = false
            return
        }

        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showClipboardBanner = false
            return
        }

        // User allowed paste - populate text field (don't auto-scan, let user tap button)
        lastHandledChangeCount = currentChangeCount
        viewModel.prePopulate(with: String(trimmed.prefix(8000)), senderPhone: nil)
    }

    /// Check if clipboard content looks like a message or email worth scanning
    private func looksLikeScannableContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Minimum length - filter out single words, but allow short messages
        guard trimmed.count >= 15 else { return false }

        // Must have at least 2 words (filters out URLs, single words)
        let words = trimmed.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard words.count >= 3 else { return false }

        // If it has 3+ words and 15+ chars, it's probably a message worth scanning
        return true
    }

    // MARK: - Scan from Clipboard (reads content only when user taps)

    private func scanFromClipboard() {
        // If in error state, user tapped "Try Again" - reset to ready first
        if clipboardBannerState == .error {
            withAnimation(.easeOut(duration: 0.15)) {
                clipboardBannerState = .ready
            }
            return
        }

        // Immediate visual feedback - show scanning state BEFORE any work
        withAnimation(.easeOut(duration: 0.15)) {
            clipboardBannerState = .scanning
        }

        // Use Task to ensure UI updates before clipboard read
        Task { @MainActor in
            // Small delay to let "Scanning..." state render
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            let pb = UIPasteboard.general
            lastHandledChangeCount = pb.changeCount

            // Read clipboard content ONLY after user explicitly taps
            guard let text = pb.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                // Show error state with friendly message
                withAnimation(.easeOut(duration: 0.2)) {
                    clipboardBannerState = .error
                }
                return
            }

            // Populate text field
            viewModel.prePopulate(with: String(text.prefix(8000)), senderPhone: nil)

            // Hide banner to reveal the populated text field
            withAnimation {
                showClipboardBanner = false
                clipboardBannerState = .ready
            }

            // Give user 1.5 seconds to see their message before scanning
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await viewModel.startScan()
        }
    }

    // MARK: - Email Instructions Card

    private var emailInstructionsCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // ONE-TIME SETUP section
                VStack(alignment: .leading, spacing: 12) {
                    Text("ONE-TIME SETUP")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.sunrise)
                        .tracking(0.5)

                    if hasSavedScamContact {
                        // Compact done state
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.verdictSafe)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Contact added")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.verdictSafe)
                                Text("Now type \"Scam\" in the To: field")
                                    .font(.system(size: 13))
                                    .foregroundColor(.cloud.opacity(0.6))
                            }

                            Spacer()

                            Button {
                                Task {
                                    await emailViewModel.saveScamShieldContact()
                                }
                            } label: {
                                Text("Add again")
                                    .font(.system(size: 13))
                                    .foregroundColor(.cloud.opacity(0.5))
                            }
                            .accessibilityLabel("Add contact again")
                        }
                    } else {
                        // Setup needed
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add Scam Shield to your contacts so you can quickly forward emails.")
                                .font(.system(size: 15))
                                .foregroundColor(.cloud.opacity(0.8))

                            if let error = emailViewModel.contactSaveError {
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.verdictDanger)
                            }

                            // Primary save button
                            Button {
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
                        }
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.glassBorder)
                    .frame(height: 1)

                // EVERY TIME section
                VStack(alignment: .leading, spacing: 10) {
                    Text("EVERY TIME")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.cloud.opacity(0.5))
                        .tracking(0.5)

                    emailStepRow(number: "1", text: "In your email, tap Forward (the arrow)")

                    VStack(alignment: .leading, spacing: 2) {
                        emailStepRow(number: "2", text: "Where it says \"To:\", type Scam", highlight: "Scam")
                        Text("Scam Shield will appear from your contacts")
                            .font(.system(size: 13))
                            .foregroundColor(.cloud.opacity(0.6))
                            .padding(.leading, 36)
                    }

                    emailStepRow(number: "3", text: "Tap Send, then reopen Scam Shield")
                }
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

    // MARK: - Email Status Card

    private var emailStatusCard: some View {
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

                // Check for Results button
                Button {
                    Task {
                        await emailViewModel.checkForNewScans()
                        HapticManager.shared.buttonTap()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if emailViewModel.isLoadingScans {
                            ProgressView()
                                .tint(hasSavedScamContact ? .midnight : .sunrise)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(emailViewModel.isLoadingScans ? "Checking..." : "Check for Results")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(hasSavedScamContact ? .midnight : .sunrise)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Group {
                            if hasSavedScamContact {
                                LinearGradient(
                                    colors: [Color.sunrise, Color.ember],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .overlay(
                        Group {
                            if !hasSavedScamContact {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.sunrise, lineWidth: 2)
                            }
                        }
                    )
                    .cornerRadius(12)
                }
                .disabled(emailViewModel.isLoadingScans)
                .accessibilityLabel("Check for results")
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

    // MARK: - Recent Email Scans Section

    private var recentEmailScansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Email Scans")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            ForEach(emailViewModel.recentEmailScans.prefix(3), id: \.id) { scan in
                GlassCard(padding: 12) {
                    HStack(spacing: 12) {
                        verdictIcon(for: scan.verdict)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(scan.title ?? "Email scan")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(scan.subtitle ?? scan.fromDomain ?? "Email")
                                .font(.system(size: 13))
                                .foregroundColor(.cloud.opacity(0.6))
                        }

                        Spacer()
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
