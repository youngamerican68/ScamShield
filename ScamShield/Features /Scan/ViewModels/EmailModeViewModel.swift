// EmailModeViewModel.swift
// ViewModel for Email mode in the unified Check screen
//
// Handles:
// - Loading recent email scans from history
// - Save "Scam Shield" contact functionality
// - Copy scan address to clipboard
// - Contact status tracking
// - STATUS card state (waiting/processing/last received)

import SwiftUI
import Contacts

@MainActor
class EmailModeViewModel: ObservableObject {
    // MARK: - Published State

    // Recent scans
    @Published var recentEmailScans: [ScanHistoryItem] = []
    @Published var isLoadingScans: Bool = false
    @Published var selectedScan: ScanHistoryItem?

    // Contact save state
    @Published var isScamShieldContactSaved: Bool = false
    @Published var isSavingContact: Bool = false
    @Published var contactSaveError: String?

    // Copy feedback
    @Published var showCopiedConfirmation: Bool = false

    // MARK: - Computed Properties

    /// The user's unique email scan address
    var emailScanAddress: String {
        APIConfig.emailScanAddress
    }

    /// Whether there are any email scans
    var hasEmailScans: Bool {
        !recentEmailScans.isEmpty
    }

    /// The newest email scan (for STATUS card)
    var newestEmailScan: ScanHistoryItem? {
        recentEmailScans.first
    }

    /// Whether the newest scan is still processing
    var isNewestScanProcessing: Bool {
        guard let newest = newestEmailScan else { return false }
        return newest.scanStatus == .processing
    }

    /// Relative time string for the newest scan
    var newestScanRelativeTime: String {
        guard let newest = newestEmailScan,
              let date = newest.createdAtDate else {
            return "Unknown"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Initialization

    init() {
        // Check if contact is already saved
        checkScamShieldContactStatus()
    }

    // MARK: - Recent Scans

    /// Load recent email scans from the API (filtered to email source only)
    func loadRecentScans() async {
        isLoadingScans = true
        defer { isLoadingScans = false }

        do {
            // Fetch scans filtered to email source
            let response = try await fetchEmailScans(limit: 10)
            recentEmailScans = response.scans
        } catch {
            #if DEBUG
            print("Failed to load email scans: \(error)")
            #endif
            // Don't show error to user, just show empty state
            recentEmailScans = []
        }
    }

    /// Fetch email scans from the API
    private func fetchEmailScans(limit: Int) async throws -> ScanHistoryResponse {
        var components = URLComponents(url: APIConfig.scanHistoryURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "source", value: "email")  // Filter to email only
        ]

        guard let url = components?.url else {
            throw ScanHistoryError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.requestTimeout

        #if DEBUG
        print("Fetching email scans from: \(url)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScanHistoryError.invalidResponse
        }

        return try JSONDecoder().decode(ScanHistoryResponse.self, from: data)
    }

    // MARK: - Contact Management

    /// Check if the Scam Shield contact is already saved
    func checkScamShieldContactStatus() {
        isScamShieldContactSaved = ContactsManager.shared.isScamShieldContactSaved

        // Also check if permission is granted and verify contact exists
        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            if !isScamShieldContactSaved {
                isScamShieldContactSaved = ContactsManager.shared.checkScamShieldContactExists()
            }
        }
    }

    /// Save the Scam Shield contact to the user's contacts
    func saveScamShieldContact() async {
        isSavingContact = true
        contactSaveError = nil

        defer { isSavingContact = false }

        // Request permission if needed
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            if !granted {
                contactSaveError = "Please allow Contacts access to save the Scam Shield contact."
                HapticManager.shared.error()
                return
            }
        } catch {
            contactSaveError = "Could not access Contacts."
            HapticManager.shared.error()
            return
        }

        // Save the contact
        do {
            try await ContactsManager.shared.saveScamShieldContact(emailAddress: emailScanAddress)
            isScamShieldContactSaved = true
            HapticManager.shared.success()
        } catch {
            contactSaveError = error.localizedDescription
            HapticManager.shared.error()
        }
    }

    /// Copy the email scan address to clipboard with confirmation
    func copyEmailAddress() {
        UIPasteboard.general.string = emailScanAddress
        HapticManager.shared.buttonTap()

        // Show confirmation briefly
        withAnimation(.easeOut(duration: 0.2)) {
            showCopiedConfirmation = true
        }

        // Auto-hide after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedConfirmation = false
            }
        }
    }

    /// Refresh scans with completion callback for "Check now" button
    func checkForNewScans() async {
        await loadRecentScans()
    }
}
