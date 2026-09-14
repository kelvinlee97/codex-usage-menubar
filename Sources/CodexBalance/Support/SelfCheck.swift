import Darwin
import Foundation

enum SelfCheck {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["CODEX_BALANCE_SELF_CHECK"] == "1" else { return }

        let data = Data(#"""
        {
          "rateLimits": {"primary": null, "secondary": null, "credits": null},
          "rateLimitsByLimitId": {"codex": {
            "primary": {"usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1789369180},
            "secondary": {"usedPercent": 33, "windowDurationMins": 10080, "resetsAt": 1789891996},
            "credits": {"hasCredits": true, "balance": "157.28"}
          }}
        }
        """#.utf8)

        do {
            let snapshot = try CodexUsageClient.decodeSnapshot(from: data)
            precondition(snapshot.primary?.remainingPercent == 88)
            precondition(snapshot.secondary?.remainingPercent == 67)
            precondition(snapshot.creditBalance == "157.28")
            precondition(snapshot.formattedCreditBalance == "157.28")
            precondition(snapshot.primary?.hasReset(asOf: Date(timeIntervalSince1970: 1_789_369_181)) == true)
            precondition(snapshot.primary?.hasReset(asOf: Date(timeIntervalSince1970: 1_789_369_179)) == false)
            try checkParserVariants()
            try checkRemainingPercentEndpoints()
            try checkPollSchedule()
            precondition(
                CodexExecutableResolver.candidates(environment: ["PATH": "/custom/bin"])
                    .contains(URL(fileURLWithPath: "/custom/bin/codex"))
            )
            // Resolving a real Codex CLI is an assertion about the machine, not about this code,
            // so it stays opt-in: a fresh clone and CI have no Codex installed.
            if ProcessInfo.processInfo.environment["CODEX_BALANCE_SELF_CHECK_REQUIRE_CLI"] == "1" {
                precondition(CodexExecutableResolver.resolve() != nil)
            }
            try checkPipeTimeoutAndShortRead()
            try checkBrokenPipeIsRecoverable()
            print("CodexBalance self-check passed")
            exit(EXIT_SUCCESS)
        } catch {
            fputs("CodexBalance self-check failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func checkParserVariants() throws {
        let byIDOnly = Data(#"""
        {
          "rateLimitsByLimitId": {"codex": {
            "primary": {"usedPercent": 12.6, "windowDurationMins": 300},
            "secondary": null,
            "credits": {"hasCredits": true, "balance": 42.5}
          }}
        }
        """#.utf8)
        let snapshot = try CodexUsageClient.decodeSnapshot(from: byIDOnly)
        precondition(snapshot.primary?.usedPercent == 12.6)
        precondition(snapshot.primary?.remainingPercent == 87)
        precondition(snapshot.creditBalance == "42.5")

        do {
            _ = try CodexUsageClient.decodeSnapshot(from: Data(#"{"unexpected":true}"#.utf8))
            preconditionFailure("A response without rate limits should fail")
        } catch CodexUsageClient.ClientError.malformedResponse {
            // Expected.
        }
    }

    /// A rounded percentage must not claim an exhausted or untouched window that isn't one.
    private static func checkRemainingPercentEndpoints() throws {
        func remaining(_ used: Double) -> Int {
            UsageWindow(usedPercent: used, windowDurationMinutes: 300, resetsAt: nil).remainingPercent
        }
        precondition(remaining(0) == 100)
        precondition(remaining(0.4) == 99)
        precondition(remaining(99.6) == 1)
        precondition(remaining(100) == 0)
        precondition(remaining(120) == 0)
        precondition(remaining(-5) == 100)
    }

    private static func checkPollSchedule() throws {
        precondition(PollSchedule.interval(consecutiveFailures: 0) == PollSchedule.successInterval)
        precondition(PollSchedule.interval(consecutiveFailures: 1) == 30)
        precondition(PollSchedule.interval(consecutiveFailures: 2) == 60)
        precondition(PollSchedule.interval(consecutiveFailures: 3) == 120)
        precondition(PollSchedule.interval(consecutiveFailures: 20) == PollSchedule.maxFailureDelay)
    }

    /// Writing to a dead subprocess must raise a catchable error, not SIGPIPE. Without the
    /// `signal(SIGPIPE, SIG_IGN)` in `CodexBalanceApp.init`, this check kills the process instead
    /// of failing, which is exactly the production symptom it guards against.
    private static func checkBrokenPipeIsRecoverable() throws {
        let pipe = Pipe()
        try pipe.fileHandleForReading.close()
        do {
            try pipe.fileHandleForWriting.write(contentsOf: Data("dead\n".utf8))
            preconditionFailure("Writing to a closed pipe should fail")
        } catch {
            // Expected: EPIPE surfaces as a thrown error once SIGPIPE is ignored.
        }
        try? pipe.fileHandleForWriting.close()
    }

    private static func checkPipeTimeoutAndShortRead() throws {
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }

        do {
            try CodexUsageClient.waitUntilReadable(
                pipe.fileHandleForReading.fileDescriptor,
                deadline: Date().addingTimeInterval(0.02)
            )
            preconditionFailure("An empty pipe should time out")
        } catch CodexUsageClient.ClientError.timedOut {
            // Expected.
        }

        try pipe.fileHandleForWriting.write(contentsOf: Data("ok\n".utf8))
        try CodexUsageClient.waitUntilReadable(
            pipe.fileHandleForReading.fileDescriptor,
            deadline: Date().addingTimeInterval(1)
        )
        let result = try CodexUsageClient.readAvailable(pipe.fileHandleForReading.fileDescriptor)
        precondition(result == Data("ok\n".utf8))
    }
}
