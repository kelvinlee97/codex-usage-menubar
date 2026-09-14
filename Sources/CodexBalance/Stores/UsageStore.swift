import Combine
import Foundation
import OSLog

@MainActor
final class UsageStore: ObservableObject {
    private let logger = Logger(subsystem: "com.kelvin.codexbalance", category: "usage")
    private let client = CodexUsageClient()
    private var pollingTask: Task<Void, Never>?

    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false

    var menuBarText: String {
        snapshot?.primary.map { "\($0.remainingPercent)%" } ?? (isRefreshing ? "…" : "—")
    }

    var accessibilityLabel: String {
        snapshot?.primary.map { "Codex 5 hour usage, \($0.remainingPercent) percent remaining" }
            ?? (isRefreshing ? "Loading Codex usage" : "Codex usage unavailable")
    }

    func start() {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            await refresh()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
                await refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await client.fetchUsage()
            errorMessage = nil
            logger.info("Codex usage refreshed successfully")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Codex usage refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
