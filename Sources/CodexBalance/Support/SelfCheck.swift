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
            try checkParserVariants()
            precondition(
                CodexExecutableResolver.candidates(environment: ["PATH": "/custom/bin"])
                    .contains(URL(fileURLWithPath: "/custom/bin/codex"))
            )
            precondition(CodexExecutableResolver.resolve() != nil)
            try checkPipeTimeoutAndShortRead()
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
        precondition(snapshot.primary?.usedPercent == 13)
        precondition(snapshot.primary?.remainingPercent == 87)
        precondition(snapshot.creditBalance == "42.5")

        do {
            _ = try CodexUsageClient.decodeSnapshot(from: Data(#"{"unexpected":true}"#.utf8))
            preconditionFailure("A response without rate limits should fail")
        } catch CodexUsageClient.ClientError.malformedResponse {
            // Expected.
        }
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
