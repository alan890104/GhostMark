import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let controller: AppController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    init(controller: AppController) {
        self.controller = controller
        super.init()
    }

    func start() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "pencil.tip",
            accessibilityDescription: "GhostMark"
        )
        button.toolTip = "GhostMark"
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func stop() {
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let interceptionItem = item(
            title: "攔截 Claude Code 圖片貼上",
            action: #selector(toggleInterception)
        )
        interceptionItem.state = controller.isEnabled ? .on : .off
        menu.addItem(interceptionItem)

        let status = NSMenuItem(title: controller.statusMessage, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let editItem = item(
            title: "編輯剪貼簿中的圖片…",
            action: #selector(openClipboardEditor),
            keyEquivalent: "e"
        )
        editItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(editItem)

        menu.addItem(item(title: "使用說明…", action: #selector(showOnboarding)))

        if controller.permissionState != .granted {
            menu.addItem(
                item(
                    title: "開啟輔助使用權限…",
                    action: #selector(requestAccessibilityPermission)
                )
            )
        } else if !controller.eventTapIsActive {
            menu.addItem(
                item(
                    title: "重新啟動鍵盤監聽",
                    action: #selector(refreshAccessibilityPermission)
                )
            )
        }

        menu.addItem(.separator())
        let quitItem = item(
            title: "結束 GhostMark",
            action: #selector(terminateApplication),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    private func item(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.isEnabled = true
        return item
    }

    @objc private func toggleInterception() {
        controller.isEnabled.toggle()
    }

    @objc private func openClipboardEditor() {
        controller.openClipboardEditor()
    }

    @objc private func showOnboarding() {
        controller.showOnboarding()
    }

    @objc private func requestAccessibilityPermission() {
        controller.requestAccessibilityPermission()
    }

    @objc private func refreshAccessibilityPermission() {
        controller.refreshAccessibilityPermission()
    }

    @objc private func terminateApplication() {
        NSApplication.shared.terminate(nil)
    }
}
