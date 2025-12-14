import SwiftUI

/// ViewModel for the scan history screen
@MainActor
class ScanHistoryViewModel: ObservableObject {
    @Published var scans: [ScanHistoryItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMore = false
    @Published var total = 0

    private var currentOffset = 0
    private let pageSize = 20

    // MARK: - Public Methods

    /// Initial load of scan history
    func loadHistory() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let response = try await ScanHistoryService.shared.fetchHistory(limit: pageSize, offset: 0)
            scans = response.scans
            hasMore = response.hasMore
            total = response.total
            currentOffset = response.scans.count
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("❌ Failed to load history: \(error)")
            #endif
        }

        isLoading = false
    }

    /// Pull-to-refresh
    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil
        currentOffset = 0

        do {
            let response = try await ScanHistoryService.shared.fetchHistory(limit: pageSize, offset: 0)
            scans = response.scans
            hasMore = response.hasMore
            total = response.total
            currentOffset = response.scans.count
            HapticManager.shared.buttonTap()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }

        isRefreshing = false
    }

    /// Load more (pagination)
    func loadMore() async {
        guard hasMore, !isLoading, !isRefreshing else { return }

        isLoading = true

        do {
            let response = try await ScanHistoryService.shared.fetchHistory(limit: pageSize, offset: currentOffset)
            scans.append(contentsOf: response.scans)
            hasMore = response.hasMore
            total = response.total
            currentOffset += response.scans.count
        } catch {
            #if DEBUG
            print("❌ Failed to load more: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    var isEmpty: Bool {
        scans.isEmpty && !isLoading
    }

    var showEmptyState: Bool {
        isEmpty && errorMessage == nil
    }
}
