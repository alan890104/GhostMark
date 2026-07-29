import AppKit
import XCTest
@testable import GhostMark

final class ClaudeCodeSessionDetectorTests: XCTestCase {
    func testFindsNestedDescendants() {
        let processes = [
            ProcessRecord(pid: 11, parentPID: 1, command: "Terminal", arguments: "Terminal"),
            ProcessRecord(pid: 12, parentPID: 11, command: "login", arguments: "login -pf user"),
            ProcessRecord(pid: 13, parentPID: 12, command: "zsh", arguments: "-zsh"),
            ProcessRecord(pid: 14, parentPID: 13, command: "claude", arguments: "claude")
        ]

        XCTAssertEqual(
            ClaudeCodeSessionDetector.descendants(of: 11, in: processes),
            Set([12, 13, 14])
        )
    }

    func testRecognizesNativeAndNodeClaudeCodeProcesses() {
        XCTAssertTrue(ClaudeCodeSessionDetector.isClaudeCodeProcess(
            ProcessRecord(pid: 1, parentPID: 0, command: "/usr/local/bin/claude", arguments: "claude")
        ))
        XCTAssertTrue(ClaudeCodeSessionDetector.isClaudeCodeProcess(
            ProcessRecord(
                pid: 2,
                parentPID: 1,
                command: "node",
                arguments: "node /opt/node_modules/@anthropic-ai/claude-code/cli.js"
            )
        ))
        XCTAssertFalse(ClaudeCodeSessionDetector.isClaudeCodeProcess(
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
            ClaudeCodeSessionDetector.containsClaudeCodeSession(
                frontmostPID: 100,
                terminalLike: false,
                processes: processes
            )
        )
        XCTAssertTrue(
            ClaudeCodeSessionDetector.containsClaudeCodeSession(
                frontmostPID: 999,
                terminalLike: true,
                processes: processes
            )
        )
        XCTAssertFalse(
            ClaudeCodeSessionDetector.containsClaudeCodeSession(
                frontmostPID: 999,
                terminalLike: false,
                processes: processes
            )
        )
    }
}

final class EventTapMonitorTests: XCTestCase {
    func testRecognizesClaudeCodePasteShortcutsWithoutExtraModifiers() throws {
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
