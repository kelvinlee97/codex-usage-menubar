import Darwin
import Foundation

/// Talks to `codex app-server --stdio` over a line-delimited JSON-RPC-like protocol.
///
/// All subprocess state is confined to `queue`. The blocking `poll()`/`read()` calls must never run
/// on a Swift concurrency cooperative thread: a hung Codex CLI would park that thread for the full
/// request timeout and starve unrelated async work.
final class CodexUsageClient: @unchecked Sendable {
    enum ClientError: LocalizedError {
        case codexNotFound
        case serverStopped
        case timedOut
        case malformedResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .codexNotFound:
                "Codex CLI was not found. Install Codex or set CODEX_CLI_PATH."
            case .serverStopped:
                "Codex usage service stopped unexpectedly."
            case .timedOut:
                "Codex usage service did not respond within 10 seconds."
            case .malformedResponse:
                "Codex returned an unreadable usage response."
            case let .server(message):
                message
            }
        }
    }

    private let requestTimeout: TimeInterval = 10
    private let queue = DispatchQueue(label: "com.kelvin.codexbalance.app-server")
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var readBuffer = Data()
    private var nextID = 1

    func fetchUsage() async throws -> UsageSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try self.fetchUsageOnQueue())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Tears the subprocess down; used when polling suspends (display sleep) so nothing idles.
    func shutDown() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.stop()
                continuation.resume()
            }
        }
    }

    private func fetchUsageOnQueue() throws -> UsageSnapshot {
        dispatchPrecondition(condition: .onQueue(queue))
        do {
            try startIfNeeded()
            let result = try request(
                method: "account/rateLimits/read",
                params: [
                    "excludeResetCreditDetails": true,
                    "supportsLunaReserve": false,
                ]
            )
            return try Self.decodeSnapshot(from: result)
        } catch {
            stop()
            throw error
        }
    }

    private func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        try? input?.close()
        try? output?.close()
        if let process, process.isRunning {
            // Reaping matters: without it the child lingers as a zombie until the app exits, and
            // every transient failure leaks one more. But a plain `waitUntilExit()` after SIGTERM
            // would block this queue forever if the CLI ignores the signal - the exact case that
            // gets us here - so escalate to SIGKILL, which cannot be ignored.
            process.terminate()
            if !Self.waitForExit(process, timeout: 2) {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
        }
        process = nil
        input = nil
        output = nil
        readBuffer.removeAll(keepingCapacity: true)
    }

    private static func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            guard Date() < deadline else { return false }
            usleep(20_000)
        }
        return true
    }

    private func startIfNeeded() throws {
        if process?.isRunning == true { return }
        stop()
        guard let executableURL = CodexExecutableResolver.resolve() else {
            throw ClientError.codexNotFound
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.environment = CodexExecutableResolver.processEnvironment(for: executableURL)
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()

        self.process = process
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        readBuffer.removeAll(keepingCapacity: true)

        _ = try request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-usage",
                    "version": Self.clientVersion,
                ],
                "capabilities": [:],
            ]
        )
    }

    private static var clientVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func request(method: String, params: [String: Any]) throws -> Data {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let input else { throw ClientError.serverStopped }
        let id = nextID
        nextID += 1

        let payload: [String: Any] = ["id": id, "method": method, "params": params]
        var data = try JSONSerialization.data(withJSONObject: payload)
        data.append(0x0A)
        try input.write(contentsOf: data)

        let deadline = Date().addingTimeInterval(requestTimeout)
        while true {
            // Unrelated notifications are skipped; `nextObject` enforces the deadline, so a chatty
            // server cannot keep us here past the timeout.
            let object = try nextObject(deadline: deadline)
            guard (object["id"] as? NSNumber)?.intValue == id else { continue }
            if let error = object["error"] as? [String: Any] {
                throw ClientError.server(error["message"] as? String ?? "Codex usage request failed.")
            }
            guard let result = object["result"] else { throw ClientError.malformedResponse }
            return try JSONSerialization.data(withJSONObject: result)
        }
    }

    private func nextObject(deadline: Date) throws -> [String: Any] {
        while true {
            if let newline = readBuffer.firstIndex(of: 0x0A) {
                let line = readBuffer[..<newline]
                readBuffer.removeSubrange(...newline)
                guard !line.isEmpty else { continue }
                guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                    throw ClientError.malformedResponse
                }
                return object
            }

            guard let output else { throw ClientError.serverStopped }
            try Self.waitUntilReadable(output.fileDescriptor, deadline: deadline)
            let chunk = try Self.readAvailable(output.fileDescriptor)
            guard !chunk.isEmpty else {
                throw ClientError.serverStopped
            }
            readBuffer.append(chunk)
        }
    }

    static func waitUntilReadable(_ fileDescriptor: Int32, deadline: Date) throws {
        while true {
            let milliseconds = Int32(max(0, min(10_000, deadline.timeIntervalSinceNow * 1_000)))
            guard milliseconds > 0 else { throw ClientError.timedOut }
            var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0)
            let result = poll(&descriptor, 1, milliseconds)
            if result > 0 { return }
            if result == 0 { throw ClientError.timedOut }
            if errno != EINTR {
                throw ClientError.serverStopped
            }
        }
    }

    static func readAvailable(_ fileDescriptor: Int32) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(fileDescriptor, &bytes, bytes.count)
            if count > 0 { return Data(bytes.prefix(count)) }
            if count == 0 { return Data() }
            if errno != EINTR { throw ClientError.serverStopped }
        }
    }

    static func decodeSnapshot(from data: Data, now: Date = Date()) throws -> UsageSnapshot {
        let response: RateLimitsResponse
        do {
            response = try JSONDecoder().decode(RateLimitsResponse.self, from: data)
        } catch {
            throw ClientError.malformedResponse
        }
        guard let limits = response.rateLimitsByLimitID?["codex"] ?? response.rateLimits else {
            throw ClientError.malformedResponse
        }
        return UsageSnapshot(
            primary: limits.primary?.usageWindow,
            secondary: limits.secondary?.usageWindow,
            creditBalance: limits.credits?.hasCredits == true ? limits.credits?.balance : nil,
            updatedAt: now
        )
    }
}

private struct RateLimitsResponse: Decodable {
    let rateLimits: RateLimits?
    let rateLimitsByLimitID: [String: RateLimits]?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitID = "rateLimitsByLimitId"
    }
}

private struct RateLimits: Decodable {
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: Credits?
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    var usageWindow: UsageWindow {
        UsageWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: windowDurationMins,
            resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}

private struct Credits: Decodable {
    let hasCredits: Bool
    let balance: String?

    enum CodingKeys: String, CodingKey {
        case hasCredits
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits) ?? false
        if let string = try? container.decode(String.self, forKey: .balance) {
            balance = string
        } else if let number = try? container.decode(Decimal.self, forKey: .balance) {
            balance = NSDecimalNumber(decimal: number).stringValue
        } else {
            balance = nil
        }
    }
}
