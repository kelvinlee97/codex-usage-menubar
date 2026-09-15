import AppKit
import Combine
import Foundation
import OSLog

@MainActor
final class UsageStore: ObservableObject {
    private let logger = Logger(subsystem: "com.kelvin.codexbalance", category: "usage")
    private let client = CodexUsageClient()
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var sleepObservers: [NSObjectProtocol] = []

    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var consecutiveFailures = 0

    /// A snapshot is on screen but the most recent refresh failed, so the numbers may have moved.
    var isShowingStaleData: Bool {
        snapshot != nil && errorMessage != nil
    }

    var menuBarText: String {
        snapshot?.primary.map { "\($0.remainingPercent)%" } ?? (isRefreshing ? "…" : "—")
    }

    var accessibilityLabel: String {
        guard let primary = snapshot?.primary else {
            return isRefreshing ? "Loading Codex usage" : "Codex usage unavailable"
        }
        let base = "Codex 5 hour usage, \(primary.remainingPercent) percent remaining"
        return isShowingStaleData ? base + ", last refresh failed" : base
    }

    func start() {
        observeSleepWake()
        startPolling()
    }

    /// Coalesces concurrent callers (the poll loop, the popover, the Retry button) onto one refresh
    /// so a manual request is never silently dropped while a background poll is in flight.
    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        // The handle is cleared inside the task so it is never left pointing at a finished
        // refresh: a caller arriving in that window would join it and return stale data.
        let task = Task {
            await performRefresh()
            refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    /// Used when the popover opens: avoids a redundant subprocess round-trip for data that the poll
    /// loop just fetched.
    func refreshIfStale(maxAge: TimeInterval = 60) async {
        if let snapshot, errorMessage == nil, Date().timeIntervalSince(snapshot.updatedAt) < maxAge {
            return
        }
        await refresh()
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await client.fetchUsage()
            errorMessage = nil
            consecutiveFailures = 0
            logger.info("Codex usage refreshed successfully")
        } catch {
            errorMessage = error.localizedDescription
            consecutiveFailures += 1
            // Kept private: resolver failures can embed local filesystem paths.
            logger.error("Codex usage refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                let delay = PollSchedule.interval(consecutiveFailures: self.consecutiveFailures, snapshot: self.snapshot)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    break
                }
            }
        }
    }

    /// Stops polling and releases the Codex subprocess while the machine is asleep.
    private func suspendPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        Task { await client.shutDown() }
    }

    private func observeSleepWake() {
        guard sleepObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, Bool)] = [
            (NSWorkspace.willSleepNotification, false),
            (NSWorkspace.didWakeNotification, true),
        ]
        sleepObservers = pairs.map { name, resuming in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if resuming {
                        self.consecutiveFailures = 0
                        self.startPolling()
                    } else {
                        self.suspendPolling()
                    }
                }
            }
        }
    }
}
