import AppKit
import SwiftUI
import XCTest
@testable import GhostMark

final class AgentSessionDetectorTests: XCTestCase {
    func testFindsNestedDescendants() {
        let processes = [
            ProcessRecord(pid: 11, parentPID: 1, command: "Terminal", arguments: "Terminal"),
            ProcessRecord(pid: 12, parentPID: 11, command: "login", arguments: "login -pf user"),
            ProcessRecord(pid: 13, parentPID: 12, command: "zsh", arguments: "-zsh"),
            ProcessRecord(pid: 14, parentPID: 13, command: "claude", arguments: "claude")
        ]

        XCTAssertEqual(
            AgentSessionDetector.descendants(of: 11, in: processes),
            Set([12, 13, 14])
        )
    }

    func testRecognizesNativeAndNodeClaudeCodeProcesses() {
        XCTAssertTrue(AgentSessionDetector.isClaudeCodeProcess(
            ProcessRecord(pid: 1, parentPID: 0, command: "/usr/local/bin/claude", arguments: "claude")
        ))
        XCTAssertTrue(AgentSessionDetector.isClaudeCodeProcess(
            ProcessRecord(
                pid: 2,
                parentPID: 1,
                command: "node",
                arguments: "node /opt/node_modules/@anthropic-ai/claude-code/cli.js"
            )
        ))
        XCTAssertFalse(AgentSessionDetector.isClaudeCodeProcess(
            ProcessRecord(pid: 3, parentPID: 1, command: "node", arguments: "node server.js")
        ))
    }

    func testUsesCachedProcessesForDescendantsAndDetachedTerminalSessions() {
        let processes = [
            ProcessRecord(pid: 100, parentPID: 1, command: "/bin/zsh", arguments: "zsh"),
            ProcessRecord(
                pid: 101,
                parentPID: 100,
                command: "/usr/local/bin/claude",
                arguments: "claude"
            ),
            ProcessRecord(
                pid: 202,
                parentPID: 1,
                command: "/usr/local/bin/claude",
                arguments: "claude"
            )
        ]

        XCTAssertTrue(
            AgentSessionDetector.containsClaudeCodeSession(
                frontmostPID: 100,
                terminalLike: false,
                processes: processes
            )
        )
        XCTAssertTrue(
            AgentSessionDetector.containsClaudeCodeSession(
                frontmostPID: 999,
                terminalLike: true,
                processes: processes
            )
        )
        XCTAssertFalse(
            AgentSessionDetector.containsClaudeCodeSession(
                frontmostPID: 999,
                terminalLike: false,
                processes: processes
            )
        )
    }

    func testRecognizesClaudeDesktopAndCodexBundleIdentifiers() {
        XCTAssertEqual(
            AgentSessionDetector.nativeTarget(
                bundleIdentifier: "com.anthropic.claudefordesktop"
            ),
            .claudeDesktop
        )
        XCTAssertEqual(
            AgentSessionDetector.nativeTarget(bundleIdentifier: "com.openai.codex"),
            .codex
        )
        XCTAssertEqual(
            AgentSessionDetector.nativeTarget(bundleIdentifier: "com.openai.codex.beta"),
            .codex
        )
        XCTAssertNil(
            AgentSessionDetector.nativeTarget(bundleIdentifier: "com.openai.chat")
        )
    }

    func testUsesTheCorrectPasteShortcutForEachAgent() {
        XCTAssertEqual(AgentTarget.claudeCode.pasteShortcut, .controlV)
        XCTAssertEqual(AgentTarget.claudeDesktop.pasteShortcut, .commandV)
        XCTAssertEqual(AgentTarget.codex.pasteShortcut, .commandV)
    }
}

final class EventTapMonitorTests: XCTestCase {
    func testRecognizesPasteShortcutsWithoutExtraModifiers() throws {
        let controlPaste = try makePasteEvent(flags: .maskControl)
        let commandPaste = try makePasteEvent(flags: .maskCommand)
        let shiftedPaste = try makePasteEvent(flags: [.maskControl, .maskShift])
        let plainV = try makePasteEvent(flags: [])

        XCTAssertTrue(EventTapMonitor.isPasteShortcut(controlPaste))
        XCTAssertTrue(EventTapMonitor.isPasteShortcut(commandPaste))
        XCTAssertFalse(EventTapMonitor.isPasteShortcut(shiftedPaste))
        XCTAssertFalse(EventTapMonitor.isPasteShortcut(plainV))
    }

    private func makePasteEvent(flags: CGEventFlags) throws -> CGEvent {
        let event = try XCTUnwrap(
            CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)
        )
        event.flags = flags
        return event
    }
}

final class ReturnPasteReadinessTests: XCTestCase {
    func testRequiresTheTargetApplicationToBeActiveAndFrontmost() {
        XCTAssertTrue(ReturnPasteReadiness.isReady(
            targetPID: 42,
            applicationIsActive: true,
            frontmostPID: 42
        ))
        XCTAssertFalse(ReturnPasteReadiness.isReady(
            targetPID: 42,
            applicationIsActive: false,
            frontmostPID: 42
        ))
        XCTAssertFalse(ReturnPasteReadiness.isReady(
            targetPID: 42,
            applicationIsActive: true,
            frontmostPID: 99
        ))
        XCTAssertFalse(ReturnPasteReadiness.isReady(
            targetPID: 42,
            applicationIsActive: true,
            frontmostPID: nil
        ))
    }
}

@MainActor
final class MarkupDocumentTests: XCTestCase {
    func testPointClampingAndUndoRedo() {
        let image = NSImage(size: NSSize(width: 100, height: 60))
        let document = MarkupDocument(sourceImage: image)

        document.beginStroke(at: NormalizedPoint(x: -1, y: 2))
        document.endStroke()

        XCTAssertEqual(document.strokes.first?.points.first, NormalizedPoint(x: 0, y: 1))
        XCTAssertTrue(document.canUndo)

        document.undo()
        XCTAssertTrue(document.strokes.isEmpty)
        XCTAssertTrue(document.canRedo)

        document.redo()
        XCTAssertEqual(document.strokes.count, 1)
    }

    func testLineKeepsOnlyItsStartAndLatestEndpoint() throws {
        let image = NSImage(size: NSSize(width: 100, height: 60))
        let document = MarkupDocument(sourceImage: image)
        document.selectedTool = .line

        document.beginStroke(at: NormalizedPoint(x: 0.1, y: 0.2))
        document.appendPoint(NormalizedPoint(x: 0.4, y: 0.5))
        document.appendPoint(NormalizedPoint(x: 0.8, y: 0.9))
        document.endStroke()

        let stroke = try XCTUnwrap(document.strokes.first)
        XCTAssertEqual(stroke.tool, .line)
        XCTAssertEqual(stroke.points, [
            NormalizedPoint(x: 0.1, y: 0.2),
            NormalizedPoint(x: 0.8, y: 0.9)
        ])
    }

    func testTextUsesSelectedStyleAndParticipatesInUndoRedo() throws {
        let image = NSImage(size: NSSize(width: 100, height: 60))
        let document = MarkupDocument(sourceImage: image)
        document.selectedColor = .orange
        document.relativeTextSize = 0.075

        document.addText("  Move this button  ", at: NormalizedPoint(x: 0.25, y: 0.3))

        let text = try XCTUnwrap(document.textElements.first)
        XCTAssertEqual(text.text, "Move this button")
        XCTAssertEqual(text.color, RGBAColor(.orange))
        XCTAssertEqual(text.relativeFontSize, 0.075)
        XCTAssertEqual(text.position, NormalizedPoint(x: 0.25, y: 0.3))

        document.undo()
        XCTAssertTrue(document.textElements.isEmpty)
        document.redo()
        XCTAssertEqual(document.textElements.first?.text, "Move this button")
    }

    func testRendererDrawsTextAndArrowAnnotations() throws {
        let image = NSImage(size: NSSize(width: 240, height: 160), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            return true
        }
        let document = MarkupDocument(sourceImage: image)
        document.selectedColor = .black
        document.relativeTextSize = 0.1
        document.addText("GhostMark", at: NormalizedPoint(x: 0.08, y: 0.08))
        document.selectedTool = .arrow
        document.beginStroke(at: NormalizedPoint(x: 0.1, y: 0.8))
        document.appendPoint(NormalizedPoint(x: 0.85, y: 0.45))
        document.endStroke()

        let output = try XCTUnwrap(MarkupRenderer.render(
            sourceImage: image,
            annotations: document.annotations
        ))
        let outputData = try XCTUnwrap(output.dataProvider?.data) as Data

        XCTAssertTrue(outputData.contains(where: { $0 < 250 }))
    }

    func testExportCommitsPendingInlineText() throws {
        let image = NSImage(size: NSSize(width: 180, height: 120), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            return true
        }
        let document = MarkupDocument(sourceImage: image)
        var commitCount = 0
        document.commitPendingEditing = { [weak document] in
            commitCount += 1
            document?.commitPendingEditing = nil
            document?.addText("Pending text", at: NormalizedPoint(x: 0.1, y: 0.1))
        }

        XCTAssertNotNil(document.renderedPNGData())
        XCTAssertEqual(commitCount, 1)
        XCTAssertEqual(document.textElements.first?.text, "Pending text")
    }

    func testRendererPreservesPixelOrientation() throws {
        // Two rows with unique colors make vertical or horizontal flips visible.
        let sourceBytes = Data([
            255, 0, 0, 255,     0, 255, 0, 255,
            0, 0, 255, 255,     255, 255, 0, 255
        ])
        let provider = try XCTUnwrap(CGDataProvider(data: sourceBytes as CFData))
        let source = try XCTUnwrap(CGImage(
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                    | CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let image = NSImage(cgImage: source, size: NSSize(width: 2, height: 2))

        let output = try XCTUnwrap(MarkupRenderer.render(sourceImage: image, strokes: []))
        let outputData = try XCTUnwrap(output.dataProvider?.data) as Data

        XCTAssertEqual(outputData.prefix(sourceBytes.count), sourceBytes)
    }
}

final class LocalizationTests: XCTestCase {
    func testTraditionalChineseTranslationCoversEveryCatalogEntry() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let missingTranslations = strings.compactMap { key, value -> String? in
            guard
                let entry = value as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any],
                localizations["zh-Hant"] != nil
            else { return key }
            return nil
        }

        XCTAssertFalse(strings.isEmpty)
        XCTAssertEqual(missingTranslations, [])
    }

    func testSystemLanguageSelectionUsesTraditionalChineseAndEnglishFallback() {
        let supported = ["en", "zh-Hant"]

        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supported,
                forPreferences: ["zh-Hant-TW"]
            ).first,
            "zh-Hant"
        )
        XCTAssertEqual(
            Bundle.preferredLocalizations(
                from: supported,
                forPreferences: ["fr-FR"]
            ).first,
            "en"
        )
    }
}

@MainActor
final class EditorLayoutSnapshotTests: XCTestCase {
    func testRendersEditorOffscreen() throws {
        let image = NSImage(size: NSSize(width: 820, height: 500), flipped: false) { rect in
            NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
            rect.fill()
            NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
            NSRect(x: 64, y: 350, width: 310, height: 34).fill()
            NSColor.systemGray.setFill()
            NSRect(x: 64, y: 286, width: 610, height: 16).fill()
            NSRect(x: 64, y: 238, width: 480, height: 16).fill()
            return true
        }
        let document = MarkupDocument(sourceImage: image)
        document.selectedTool = .arrow
        document.beginStroke(at: NormalizedPoint(x: 0.2, y: 0.76))
        document.appendPoint(NormalizedPoint(x: 0.68, y: 0.48))
        document.endStroke()
        document.selectedTool = .text
        document.selectedColor = .blue
        document.relativeTextSize = 0.055
        document.addText("Move this below the banner", at: NormalizedPoint(x: 0.08, y: 0.12))

        let view = EditorView(
            document: document,
            agentTarget: .codex,
            onCancel: {},
            onDone: {}
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.setContentSize(NSSize(width: 1200, height: 760))
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        let representation = try XCTUnwrap(
            hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))

        XCTAssertGreaterThan(data.count, 10_000)
    }
}
