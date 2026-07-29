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
            title: String(
                localized: "Intercept image pastes in AI agent apps",
                bundle: .main,
                comment: "Menu item that enables or disables image-paste interception."
            ),
            action: #selector(toggleInterception)
        )
        interceptionItem.state = controller.isEnabled ? .on : .off
        menu.addItem(interceptionItem)

        let status = NSMenuItem(
            title: String(localized: controller.statusMessage),
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let editItem = item(
            title: String(
                localized: "Edit image on clipboard…",
                bundle: .main,
                comment: "Menu item that opens the image currently on the clipboard."
            ),
            action: #selector(openClipboardEditor),
            keyEquivalent: "e"
        )
        editItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(editItem)

        menu.addItem(
            item(
                title: String(
                    localized: "How to use GhostMark…",
                    bundle: .main,
                    comment: "Menu item that reopens onboarding instructions."
                ),
                action: #selector(showOnboarding)
            )
        )

        if controller.permissionState != .granted {
            menu.addItem(
                item(
                    title: String(
                        localized: "Open Accessibility Settings…",
                        bundle: .main,
                        comment: "Menu item that opens macOS Accessibility privacy settings."
                    ),
                    action: #selector(requestAccessibilityPermission)
                )
            )
        } else if !controller.eventTapIsActive {
            menu.addItem(
                item(
                    title: String(
                        localized: "Restart keyboard monitoring",
                        bundle: .main,
                        comment: "Menu item that restarts the global paste-shortcut monitor."
                    ),
                    action: #selector(refreshAccessibilityPermission)
                )
            )
        }

        menu.addItem(.separator())
        let quitItem = item(
            title: String(
                localized: "Quit GhostMark",
                bundle: .main,
                comment: "Menu item that quits the application."
            ),
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
