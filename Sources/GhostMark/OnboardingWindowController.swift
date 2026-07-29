import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private var onClose: (() -> Void)?
    private var isControlledClose = false

    func show(controller: AppController, onClose: @escaping () -> Void) {
        dismiss()
        self.onClose = onClose

        let hostingController = NSHostingController(rootView: OnboardingView(controller: controller))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 510),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "GhostMark"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hostingController
        panel.delegate = self
        panel.center()

        window = panel
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard let window else { return }
        isControlledClose = true
        window.orderOut(nil)
        window.close()
        self.window = nil
        onClose = nil
        isControlledClose = false
    }

    func windowWillClose(_ notification: Notification) {
        guard !isControlledClose else { return }
        window = nil
        let close = onClose
        onClose = nil
        close?()
    }
}
