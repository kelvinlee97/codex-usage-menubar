import Foundation

/// How often `UsageStore` polls the Codex CLI.
///
/// A five-hour window moves slowly, so the steady-state interval is deliberately long: each poll
/// spawns traffic to a local subprocess and the data is barely fresher for it. Failures back off so
/// that an uninstalled or broken Codex CLI is not retried forever at full rate.
enum PollSchedule {
    static let successInterval: TimeInterval = 120
    static let firstFailureDelay: TimeInterval = 30
    static let maxFailureDelay: TimeInterval = 300

    /// How soon to re-poll once a window's reset time has passed, so "Resetting…" does not sit on
    /// screen for the rest of the normal `successInterval`.
    static let resetPollDelay: TimeInterval = 5

    static func interval(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return successInterval }
        let exponent = min(consecutiveFailures - 1, 16)
        return min(maxFailureDelay, firstFailureDelay * pow(2, Double(exponent)))
    }

    /// The failure backoff already governs how soon to retry a broken refresh, so reset-awareness
    /// only shortens the *successful*-poll interval: it has no opinion once `consecutiveFailures > 0`.
    static func interval(consecutiveFailures: Int, snapshot: UsageSnapshot?, now: Date = Date()) -> TimeInterval {
        let base = interval(consecutiveFailures: consecutiveFailures)
        guard consecutiveFailures == 0, let snapshot else { return base }
        let resetsAts = [snapshot.primary?.resetsAt, snapshot.secondary?.resetsAt].compactMap { $0 }
        guard let nextReset = resetsAts.min() else { return base }
        let secondsUntilReset = nextReset.timeIntervalSince(now)
        if secondsUntilReset <= 0 { return resetPollDelay }
        return min(base, max(resetPollDelay, secondsUntilReset))
    }
}
