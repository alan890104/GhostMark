import AppKit
// The Accessibility C API exposes option constants as mutable globals even
// though GhostMark only reads them on the MainActor.
@preconcurrency import ApplicationServices
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
    private(set) var statusMessage: LocalizedStringResource = "Starting…"

    @ObservationIgnored private let sessionDetector = ClaudeCodeSessionDetector()
    @ObservationIgnored private let editorWindowController = EditorWindowController()
    @ObservationIgnored private let onboardingWindowController = OnboardingWindowController()
    @ObservationIgnored private var eventTapMonitor: EventTapMonitor?
    @ObservationIgnored private var permissionPollTimer: Timer?
    @ObservationIgnored private var sessionRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var sessionProcesses: [ProcessRecord] = []
    @ObservationIgnored private var activeDocument: MarkupDocument?
    @ObservationIgnored private var returnTarget: ReturnTarget?

    private static let onboardingCompletionKey = "GhostMark.hasCompletedOnboarding"

    func start() {
        beginSessionMonitoring()
        refreshAccessibilityPermission()
        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: Self.onboardingCompletionKey
        )
        if !hasCompletedOnboarding || permissionState != .granted {
            showOnboarding()
        }
    }

    func stop() {
        sessionRefreshTask?.cancel()
        sessionRefreshTask = nil
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
            statusMessage = "Accessibility access is required to intercept image pastes"
            beginPermissionPolling()
        }
    }

    func openClipboardEditor() {
        guard let image = ClipboardImage.read() else {
            statusMessage = "No image on the clipboard"
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
                        self.statusMessage = "Watching for image pastes in Claude Code"
                    } else if self.permissionState == .granted {
                        self.statusMessage = "Keyboard monitoring stopped — reopen GhostMark"
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
        guard sessionDetector.isClaudeCodeFrontmost(
            in: frontmostApplication,
            processes: sessionProcesses
        ) else { return false }

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
        statusMessage = "Cancelled — the original clipboard is unchanged"
    }

    private func completeEditing() {
        guard
            let document = activeDocument,
            let pngData = document.renderedPNGData(),
            ClipboardImage.write(pngData: pngData)
        else {
            statusMessage = "Couldn't export the marked-up image"
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
            statusMessage = "Marked-up image copied to the clipboard"
            return
        }

        statusMessage = "Done — pasting back into Claude Code"
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

    private func beginSessionMonitoring() {
        guard sessionRefreshTask == nil else { return }

        sessionRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                // Process.run() and waitUntilExit() are blocking APIs. Keep them
                // outside the MainActor and, crucially, outside the event-tap callback.
                let processes = await Task.detached(priority: .utility) {
                    ClaudeCodeSessionDetector.processSnapshot()
                }.value

                guard let self else { return }
                sessionProcesses = processes

                do {
                    try await Task.sleep(for: .milliseconds(750))
                } catch {
                    return
                }
            }
        }
    }
}

private struct ReturnTarget {
    let application: NSRunningApplication?
    let shouldAutoPaste: Bool
}
