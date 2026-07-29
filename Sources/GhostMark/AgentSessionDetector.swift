import AppKit
import Foundation

struct ProcessRecord: Equatable, Sendable {
    let pid: pid_t
    let parentPID: pid_t
    let command: String
    let arguments: String
}

struct AgentSessionDetector {
    private static let claudeDesktopBundlePrefix = "com.anthropic.claudefordesktop"
    private static let codexBundlePrefix = "com.openai.codex"

    private static let knownTerminalBundleFragments = [
        "terminal",
        "ghostty",
        "iterm",
        "warp",
        "kitty",
        "wezterm",
        "alacritty",
        "rio",
        "tabby",
        "hyper",
        "vscode",
        "visual-studio-code",
        "zed",
        "cursor",
        "jetbrains"
    ]

    private static let knownTerminalNameFragments = [
        "terminal",
        "ghostty",
        "iterm",
        "warp",
        "kitty",
        "wezterm",
        "alacritty",
        "rio",
        "tabby",
        "hyper",
        "visual studio code",
        "zed",
        "cursor"
    ]

    func target(
        for application: NSRunningApplication,
        processes: [ProcessRecord]
    ) -> AgentTarget? {
        if let nativeTarget = Self.nativeTarget(
            bundleIdentifier: application.bundleIdentifier
        ) {
            return nativeTarget
        }

        guard !processes.isEmpty else { return nil }
        guard Self.containsClaudeCodeSession(
            frontmostPID: application.processIdentifier,
            terminalLike: isTerminalLike(application),
            processes: processes
        ) else { return nil }

        return .claudeCode
    }

    static func nativeTarget(bundleIdentifier: String?) -> AgentTarget? {
        let bundleID = bundleIdentifier?.lowercased() ?? ""

        if bundleID == claudeDesktopBundlePrefix
            || bundleID.hasPrefix(claudeDesktopBundlePrefix + ".") {
            return .claudeDesktop
        }

        if bundleID == codexBundlePrefix
            || bundleID.hasPrefix(codexBundlePrefix + ".") {
            return .codex
        }

        return nil
    }

    func isTerminalLike(_ application: NSRunningApplication) -> Bool {
        let bundleID = application.bundleIdentifier?.lowercased() ?? ""
        let name = application.localizedName?.lowercased() ?? ""

        return Self.knownTerminalBundleFragments.contains(where: bundleID.contains)
            || Self.knownTerminalNameFragments.contains(where: name.contains)
    }

    static func descendants(of rootPID: pid_t, in processes: [ProcessRecord]) -> Set<pid_t> {
        var childrenByParent: [pid_t: [pid_t]] = [:]
        for process in processes {
            childrenByParent[process.parentPID, default: []].append(process.pid)
        }

        var result: Set<pid_t> = []
        var queue = [rootPID]
        var cursor = 0

        while cursor < queue.count {
            let parent = queue[cursor]
            cursor += 1

            for child in childrenByParent[parent, default: []] where result.insert(child).inserted {
                queue.append(child)
            }
        }

        return result
    }

    static func isClaudeCodeProcess(_ process: ProcessRecord) -> Bool {
        let commandName = URL(fileURLWithPath: process.command).lastPathComponent.lowercased()
        let arguments = process.arguments.lowercased()

        if commandName == "claude" || commandName == "claude-code" {
            return true
        }

        return (commandName == "node" || commandName == "bun")
            && (arguments.contains("/@anthropic-ai/claude-code/")
                || arguments.contains("/claude-code/cli"))
    }

    static func containsClaudeCodeSession(
        frontmostPID: pid_t,
        terminalLike: Bool,
        processes: [ProcessRecord]
    ) -> Bool {
        let descendantPIDs = descendants(of: frontmostPID, in: processes)
        if processes.contains(where: {
            descendantPIDs.contains($0.pid) && isClaudeCodeProcess($0)
        }) {
            return true
        }

        // Some terminals launch PTYs from a detached helper. In that case the
        // ancestry link is lost, so use a deliberately broad fallback only
        // while a terminal-like app is frontmost.
        return terminalLike && processes.contains(where: isClaudeCodeProcess)
    }

    static func processSnapshot() -> [ProcessRecord] {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,comm=,args="]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        let outputData: Data
        do {
            try process.run()
            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard
            process.terminationStatus == 0,
            let output = String(data: outputData, encoding: .utf8)
        else { return [] }

        return output.split(separator: "\n").compactMap(parseProcessLine)
    }

    private static func parseProcessLine(_ line: Substring) -> ProcessRecord? {
        let fields = line.split(
            maxSplits: 3,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\t" }
        )

        guard
            fields.count == 4,
            let pid = pid_t(fields[0]),
            let parentPID = pid_t(fields[1])
        else { return nil }

        return ProcessRecord(
            pid: pid,
            parentPID: parentPID,
            command: String(fields[2]),
            arguments: String(fields[3])
        )
    }
}
