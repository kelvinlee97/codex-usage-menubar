import Foundation

enum CodexExecutableResolver {
    static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        candidates(environment: environment).first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }

    static func candidates(environment: [String: String]) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths = [
            environment["CODEX_CLI_PATH"],
            "/Applications/ChatGPT.app/Contents/Resources/codex",
        ]
        paths += (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { "\($0)/codex" }
        paths += [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.asdf/shims/codex",
            "\(home)/.npm-global/bin/codex",
        ]

        var seen = Set<String>()
        return paths.compactMap { path in
            guard let path, !path.isEmpty, seen.insert(path).inserted else { return nil }
            return URL(fileURLWithPath: path)
        }
    }

    static func processEnvironment(
        for executableURL: URL,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = base
        let directories = [
            executableURL.deletingLastPathComponent().path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ] + (base["PATH"] ?? "").split(separator: ":").map(String.init)
        environment["PATH"] = Array(NSOrderedSet(array: directories))
            .compactMap { $0 as? String }
            .joined(separator: ":")
        return environment
    }
}
