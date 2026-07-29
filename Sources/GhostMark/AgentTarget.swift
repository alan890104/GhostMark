import CoreGraphics
import Foundation

enum AgentPasteShortcut: Equatable, Sendable {
    case controlV
    case commandV

    var eventFlags: CGEventFlags {
        switch self {
        case .controlV:
            .maskControl
        case .commandV:
            .maskCommand
        }
    }
}

enum AgentTarget: Equatable, Sendable {
    case claudeCode
    case claudeDesktop
    case codex

    var pasteShortcut: AgentPasteShortcut {
        switch self {
        case .claudeCode:
            .controlV
        case .claudeDesktop, .codex:
            .commandV
        }
    }

    var completionTitle: LocalizedStringResource {
        switch self {
        case .claudeCode:
            "Send to Claude Code"
        case .claudeDesktop:
            "Send to Claude"
        case .codex:
            "Send to Codex"
        }
    }

    var pastingStatus: LocalizedStringResource {
        switch self {
        case .claudeCode:
            "Done — pasting back into Claude Code"
        case .claudeDesktop:
            "Done — pasting back into Claude"
        case .codex:
            "Done — pasting back into Codex"
        }
    }

    var sentStatus: LocalizedStringResource {
        switch self {
        case .claudeCode:
            "Marked-up image sent to Claude Code"
        case .claudeDesktop:
            "Marked-up image sent to Claude"
        case .codex:
            "Marked-up image sent to Codex"
        }
    }
}
