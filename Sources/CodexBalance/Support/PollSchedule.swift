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

    static func interval(consecutiveFailures: Int) -> TimeInterval {
        guard consecutiveFailures > 0 else { return successInterval }
        let exponent = min(consecutiveFailures - 1, 16)
        return min(maxFailureDelay, firstFailureDelay * pow(2, Double(exponent)))
    }
}
