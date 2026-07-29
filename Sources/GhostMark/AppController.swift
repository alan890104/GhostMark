import AppKit
import ApplicationServices
import Observation

enum AccessibilityPermissionState: Equatable {
    case unknown
    case denied
    case granted
}

@MainActor
@Observable
final class AppController {
    var isEnabled = true
    private(set) var permissionState: AccessibilityPermissionState = .unknown
    private(set) var eventTapIsActive = false
    private(set) var isEditing = false
    private(set) var isOnboardingVisible = false
    private(set) var hasRequestedPermission = false
    private(set) var statusMessage = "正在啟動…"

    @ObservationIgnored private let sessionDetector = ClaudeCodeSessionDetector()
    @ObservationIgnored private let editorWindowController = EditorWindowController()
    @ObservationIgnored private let onboardingWindowController = OnboardingWindowController()
    @ObservationIgnored private var eventTapMonitor: EventTapMonitor?
    @ObservationIgnored private var permissionPollTimer: Timer?
    @ObservationIgnored private var activeDocument: MarkupDocument?
    @ObservationIgnored private var returnTarget: ReturnTarget?

    private static let onboardingCompletionKey = "GhostMark.hasCompletedOnboarding"

    func start() {
        refreshAccessibilityPermission()
        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: Self.onboardingCompletionKey
        )
        if !hasCompletedOnboarding || permissionState != .granted {
            showOnboarding()
        }
    }

    func stop() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        eventTapMonitor?.stop()
        editorWindowController.dismiss()
        onboardingWindowController.dismiss()
    }

    func requestAccessibilityPermission() {
        hasRequestedPermission = true
        refreshAccessibilityPermission(prompt: true)
        if permissionState != .granted {
            openAccessibilitySettings()
        }
    }

    func showOnboarding() {
        guard !isOnboardingVisible else { return }
        isOnboardingVisible = true
        hasRequestedPermission = false
        onboardingWindowController.show(
            controller: self,
            onClose: { [weak self] in self?.closeOnboarding(markComplete: false) }
        )
    }

    func performOnboardingPrimaryAction() {
        if permissionState == .granted {
            closeOnboarding(markComplete: true)
        } else {
            requestAccessibilityPermission()
        }
    }

    func refreshAccessibilityPermission(prompt: Bool = false) {
        let trusted: Bool
        if prompt {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            trusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        } else {
            trusted = AXIsProcessTrusted()
        }

        permissionState = trusted ? .granted : .denied
        if trusted {
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
            startEventTap()
            if isOnboardingVisible, hasRequestedPermission {
                closeOnboarding(markComplete: true)
            }
        } else {
            eventTapMonitor?.stop()
            statusMessage = "需要「輔助使用」權限才能攔截貼上"
            beginPermissionPolling()
        }
    }

    func openClipboardEditor() {
        guard let image = ClipboardImage.read() else {
            statusMessage = "剪貼簿裡沒有圖片"
            return
        }

        let sourceApplication = NSWorkspace.shared.frontmostApplication
        beginEditing(
            image: frozenCopy(of: image),
            returnTo: sourceApplication,
            autoPaste: false
        )
    }

    private func startEventTap() {
        if eventTapMonitor == nil {
            eventTapMonitor = EventTapMonitor(
                onPaste: { [weak self] in
                    self?.handlePasteShortcut() ?? false
                },
                onStateChange: { [weak self] isActive in
                    guard let self else { return }
                    self.eventTapIsActive = isActive
                    if isActive {
                        self.statusMessage = "已監聽 Claude Code 圖片貼上"
                    } else if self.permissionState == .granted {
                        self.statusMessage = "鍵盤監聽未啟動；請重新開啟 GhostMark"
                    }
                }
            )
        }

        _ = eventTapMonitor?.start()
    }

    private func handlePasteShortcut() -> Bool {
        guard isEnabled, !isEditing else { return false }
        guard let image = ClipboardImage.read() else { return false }
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else { return false }
        guard sessionDetector.isClaudeCodeFrontmost(in: frontmostApplication) else { return false }

        let stableImage = frozenCopy(of: image)
        DispatchQueue.main.async { [weak self] in
            self?.beginEditing(
                image: stableImage,
                returnTo: frontmostApplication,
                autoPaste: true
            )
        }
        return true
    }

    private func beginEditing(
        image: NSImage,
        returnTo application: NSRunningApplication?,
        autoPaste: Bool
    ) {
        guard !isEditing else { return }

        let document = MarkupDocument(sourceImage: image)
        activeDocument = document
        returnTarget = ReturnTarget(application: application, shouldAutoPaste: autoPaste)
        isEditing = true

        editorWindowController.show(
            document: document,
            onCancel: { [weak self] in self?.cancelEditing() },
            onDone: { [weak self] in self?.completeEditing() }
        )
    }

    private func cancelEditing() {
        cleanupEditor()
        statusMessage = "已取消；原始剪貼簿未變更"
    }

    private func completeEditing() {
        guard
            let document = activeDocument,
            let pngData = document.renderedPNGData(),
            ClipboardImage.write(pngData: pngData)
        else {
            statusMessage = "無法輸出標記圖片"
            NSSound.beep()
            return
        }

        let target = returnTarget
        cleanupEditor()

        guard
            target?.shouldAutoPaste == true,
            let application = target?.application,
            !application.isTerminated
        else {
            statusMessage = "完成圖已放入剪貼簿"
            return
        }

        statusMessage = "完成；正在貼回 Claude Code"
        application.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            self?.eventTapMonitor?.postClaudeCodePaste()
        }
    }

    private func cleanupEditor() {
        editorWindowController.dismiss()
        activeDocument = nil
        returnTarget = nil
        isEditing = false
    }

    private func frozenCopy(of image: NSImage) -> NSImage {
        (image.copy() as? NSImage) ?? image
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func closeOnboarding(markComplete: Bool) {
        if markComplete {
            UserDefaults.standard.set(true, forKey: Self.onboardingCompletionKey)
        }
        onboardingWindowController.dismiss()
        isOnboardingVisible = false
    }

    private func beginPermissionPolling() {
        guard permissionPollTimer == nil else { return }
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAccessibilityPermission()
            }
        }
    }
}

private struct ReturnTarget {
    let application: NSRunningApplication?
    let shouldAutoPaste: Bool
}
