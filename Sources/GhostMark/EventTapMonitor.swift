import AppKit
// CGEvent is delivered and consumed synchronously on the main run loop. Remove
// this compatibility import once CoreGraphics annotates CGEvent for concurrency.
@preconcurrency import CoreGraphics

@MainActor
final class EventTapMonitor {
    typealias PasteHandler = @MainActor () -> Bool
    typealias StateHandler = @MainActor (Bool) -> Void

    private let onPaste: PasteHandler
    private let onStateChange: StateHandler
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var bypassPasteCount = 0

    init(onPaste: @escaping PasteHandler, onStateChange: @escaping StateHandler) {
        self.onPaste = onPaste
        self.onStateChange = onStateChange
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onStateChange(false)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStateChange(true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        onStateChange(false)
    }

    func bypassNextPaste() {
        bypassPasteCount += 1
    }

    func postClaudeCodePaste() {
        bypassNextPaste()

        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
        else { return }

        keyDown.flags = .maskControl
        keyUp.flags = .maskControl
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                onStateChange(true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, Self.isPasteShortcut(event) else {
            return Unmanaged.passUnretained(event)
        }

        if bypassPasteCount > 0 {
            bypassPasteCount -= 1
            return Unmanaged.passUnretained(event)
        }

        return onPaste() ? nil : Unmanaged.passUnretained(event)
    }

    private nonisolated static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<EventTapMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return MainActor.assumeIsolated {
            monitor.handle(type: type, event: event)
        }
    }

    nonisolated static func isPasteShortcut(_ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.keyboardEventKeycode) == 9 else { return false }

        let flags = event.flags
        let usesControl = flags.contains(.maskControl)
        let usesCommand = flags.contains(.maskCommand)
        let hasDisallowedModifier = flags.contains(.maskAlternate)
            || flags.contains(.maskShift)

        return !hasDisallowedModifier && (usesControl != usesCommand)
    }
}
