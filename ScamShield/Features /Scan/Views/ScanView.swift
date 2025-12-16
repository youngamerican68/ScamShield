import SwiftUI
import UIKit

/// Main scan screen - MVP version
struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isTextFieldFocused: Bool
    @State private var showSettings = false
    @State private var showHistory = false

    // Clipboard tracking - persist across launches to avoid repeat prompting
    @AppStorage("pasteboardLastHandledChangeCount") private var lastHandledChangeCount: Int = 0
    @AppStorage("pasteboardLastDismissedChangeCount") private var lastDismissedChangeCount: Int = 0
    @State private var showClipboardBanner = false
    @State private var clipboardBannerState: ClipboardBannerState = .ready
    @State private var hasEnteredBackground = false
    @State private var clipboardHasText = false  // Reactive clipboard state

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
            // Update clipboard availability (non-invasive check)
            updateClipboardAvailability()
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
                // Update clipboard availability when app becomes active
                updateClipboardAvailability()

                // Only auto-scan clipboard when RETURNING from background, not on initial launch
                if hasEnteredBackground {
                    checkClipboardAvailability()
                }
            }
        }
        .onChange(of: viewModel.scanState) { newState in
            // Re-check clipboard when returning to idle (after "Scan Another")
            if case .idle = newState {
                updateClipboardAvailability()
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
                // Clipboard Banner (shown above header when available)
                if showClipboardBanner {
                    clipboardBannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Header
                headerSection

                // Permanent Paste from Clipboard button (always visible for elderly users)
                pasteFromClipboardButton

                // Divider
                orTypeBelowDivider

                // Message Input
                messageInputSection

                // Scan Button
                scanButtonSection

                // Trust Indicators
                trustIndicators
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 40) // Extra padding for safe area
        }
        .scrollBounceBehavior(.basedOnSize)
        .onTapGesture {
            isTextFieldFocused = false
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

    // MARK: - Permanent Paste Button (Always Visible for Elderly Users)

    private var pasteFromClipboardButton: some View {
        Button {
            pasteFromClipboardAction()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 24))
                Text("Paste from Clipboard")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.midnight)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.sunrise)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.sunrise.opacity(0.3), radius: 8, y: 4)
        }
        .opacity(clipboardHasText ? 1.0 : 0.4)
        .disabled(!clipboardHasText)
        .accessibilityLabel("Paste from Clipboard")
        .accessibilityHint(clipboardHasText ? "Double tap to paste copied text" : "No text in clipboard")
    }

    private func pasteFromClipboardAction() {
        if let text = UIPasteboard.general.string {
            // Trim whitespace and limit to 8000 chars
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            viewModel.messageText = String(trimmed.prefix(8000))
            HapticManager.shared.buttonTap()  // Soft haptic, less jarring for seniors

            // Hide the auto-scan banner if showing
            showClipboardBanner = false
            lastHandledChangeCount = UIPasteboard.general.changeCount
        }
    }

    // MARK: - Divider

    private var orTypeBelowDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.cloud.opacity(0.4))
                .frame(height: 1)
            Text("Or type it here")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.cloud.opacity(0.9))
                .fixedSize()  // Prevent wrapping
            Rectangle()
                .fill(Color.cloud.opacity(0.4))
                .frame(height: 1)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            // Owl Logo with glow
            Image("LaunchLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(Color.sunrise.opacity(0.15))
                        .frame(width: 180, height: 180)
                        .blur(radius: 40)
                )
                .shadow(color: .sunrise.opacity(0.5), radius: 30, y: 5)

            // Title
            Text("Scam Shield")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.starlight)
                .padding(.top, -12)

            // Simplified instruction (one line since we have paste button)
            Text("Copy a message, then tap Paste")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.cloud.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Message Input

    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label above text box
            Text("Message to check")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.cloud)

            GlassCard(padding: 0) {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextEditor(text: $viewModel.messageText)
                            .focused($isTextFieldFocused)
                            .frame(minHeight: 100, maxHeight: 180)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .font(AppTypography.body)
                            .foregroundColor(.starlight)
                            .padding()
                            .padding(.trailing, 40) // Make room for paste button
                            .onChange(of: viewModel.messageText) { newText in
                                // Auto-detect contacts when text is pasted
                                if !newText.isEmpty {
                                    Task {
                                        await viewModel.checkForKnownContact(messageText: newText)
                                    }
                                }
                            }

                        // Character count
                        HStack {
                            Spacer()
                            Text("\(viewModel.characterCount)/8000")
                                .font(AppTypography.caption)
                                .foregroundColor(viewModel.isOverLimit ? .verdictDanger : .cloud.opacity(0.5))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    // Small paste chip inside text area (top right) - clearer than icon alone
                    if viewModel.messageText.isEmpty && clipboardHasText {
                        Button {
                            pasteFromClipboardAction()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12))
                                Text("Paste")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.sunrise)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.glassWhite)
                            .clipShape(Capsule())
                        }
                        .contentShape(Rectangle())  // Expand tap target
                        .frame(minWidth: 44, minHeight: 44)  // iOS minimum tap target
                        .padding(8)
                    }
                }
            }
            .overlay(
                Group {
                    if viewModel.messageText.isEmpty {
                        Text("Paste the message…")
                            .font(AppTypography.body)
                            .foregroundColor(.cloud.opacity(0.8))  // Higher contrast for older eyes + glare
                            .padding()
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
        }
        // Subtly dim when clipboard banner is showing to focus attention on primary CTA
        .opacity(showClipboardBanner ? 0.6 : 1.0)
    }

    // MARK: - Scan Button

    private var scanButtonSection: some View {
        VStack(spacing: 8) {
            // More prominent Check Message button
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
                .foregroundColor(viewModel.canScan ? .midnight : .cloud.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 58)  // Slightly taller than paste button
                .background(
                    LinearGradient(
                        colors: viewModel.canScan
                            ? [Color.sunrise, Color.ember]  // Bright when enabled
                            : [Color.cloud.opacity(0.3), Color.cloud.opacity(0.2)],  // Muted when disabled
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: viewModel.canScan ? Color.ember.opacity(0.5) : Color.clear, radius: 12, y: 6)
            }
            .disabled(!viewModel.canScan)
            // Dim when clipboard banner is showing to reduce competing CTAs
            .opacity(showClipboardBanner ? 0.4 : 1.0)

            // Helper text - changes based on state to guide user
            Text(viewModel.canScan
                ? "We'll explain what looks risky and what to do next"
                : "Paste or type a message to check")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.cloud.opacity(viewModel.canScan ? 0.7 : 0.85))  // Higher contrast when guiding
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
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.sunrise)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.cloud)
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

    // MARK: - Clipboard State (Reactive)

    /// Updates the clipboard availability state (non-invasive, doesn't read content)
    private func updateClipboardAvailability() {
        clipboardHasText = UIPasteboard.general.hasStrings
    }

    // MARK: - Clipboard Detection (auto-scan after paste permission granted)

    private func checkClipboardAvailability() {
        // Don't check if we're not in idle state or already have text
        guard case .idle = viewModel.scanState,
              viewModel.messageText.isEmpty else {
            showClipboardBanner = false
            return
        }

        // Non-invasive check: does pasteboard have strings? (doesn't read content)
        guard UIPasteboard.general.hasStrings else {
            showClipboardBanner = false
            return
        }

        // Check change count to avoid repeat prompts
        let currentChangeCount = UIPasteboard.general.changeCount
        if currentChangeCount == lastHandledChangeCount ||
           currentChangeCount == lastDismissedChangeCount {
            showClipboardBanner = false
            return
        }

        // Read clipboard - if user allows paste, auto-scan immediately
        guard let clipboardText = UIPasteboard.general.string,
              looksLikeScannableContent(clipboardText) else {
            showClipboardBanner = false
            return
        }

        // User allowed paste and content looks like a message - auto-scan!
        lastHandledChangeCount = currentChangeCount
        viewModel.prePopulate(with: String(clipboardText.prefix(8000)), senderPhone: nil)

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay to show text
            await viewModel.startScan()
        }
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
}

// MARK: - Preview

#Preview {
    ScanView()
        .environmentObject(AppState())
}
