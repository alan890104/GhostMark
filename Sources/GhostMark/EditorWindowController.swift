import AppKit
import SwiftUI

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private var editorWindow: NSPanel?
    private var onWindowCancel: (() -> Void)?
    private var isControlledClose = false

    var isVisible: Bool { editorWindow?.isVisible == true }

    func show(
        document: MarkupDocument,
        onCancel: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        dismiss()
        onWindowCancel = onCancel

        let content = EditorView(
            document: document,
            onCancel: onCancel,
            onDone: onDone
        )
        let hostingController = NSHostingController(rootView: content)
        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "GhostMark"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.delegate = self
        window.minSize = NSSize(width: 760, height: 540)

        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let targetSize = NSSize(
            width: min(max(visibleFrame.width * 0.86, 860), 1440),
            height: min(max(visibleFrame.height * 0.84, 620), 960)
        )
        let targetOrigin = NSPoint(
            x: visibleFrame.midX - targetSize.width / 2,
            y: visibleFrame.midY - targetSize.height / 2
        )
        window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: false)

        editorWindow = window
        NSApp.activate()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard let editorWindow else { return }
        isControlledClose = true
        editorWindow.orderOut(nil)
        editorWindow.close()
        self.editorWindow = nil
        onWindowCancel = nil
        isControlledClose = false
    }

    func windowWillClose(_ notification: Notification) {
        guard !isControlledClose else { return }
        editorWindow = nil
        let cancel = onWindowCancel
        onWindowCancel = nil
        cancel?()
    }
}
