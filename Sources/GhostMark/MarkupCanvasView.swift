import AppKit
import SwiftUI

struct MarkupCanvasView: NSViewRepresentable {
    let document: MarkupDocument
    let revision: Int

    func makeNSView(context: Context) -> MarkupCanvasNSView {
        MarkupCanvasNSView(document: document)
    }

    func updateNSView(_ nsView: MarkupCanvasNSView, context: Context) {
        nsView.document = document
        nsView.updateTextEntryAppearance()
        nsView.needsDisplay = true
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

@MainActor
final class MarkupCanvasNSView: NSView, NSTextFieldDelegate {
    var document: MarkupDocument {
        didSet {
            registerCommitHandler()
            needsDisplay = true
        }
    }

    private weak var textEntryField: NSTextField?
    private var pendingTextPosition: NormalizedPoint?
    private var isFinishingTextEntry = false

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(document: MarkupDocument) {
        self.document = document
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
        registerCommitHandler()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        guard let pendingTextPosition, let textEntryField else { return }
        textEntryField.frame = textFieldFrame(at: denormalized(pendingTextPosition))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
        dirtyRect.fill()

        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else { return }

        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: 12),
                blur: 28,
                color: NSColor.black.withAlphaComponent(0.45).cgColor
            )
            NSColor.black.setFill()
            rect.fill()
            context.restoreGState()
        }

        document.sourceImage.draw(
            in: rect,
            from: .zero,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )

        if let context = NSGraphicsContext.current?.cgContext {
            MarkupRenderer.draw(
                annotations: document.annotations,
                in: context,
                imageRect: rect
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(location) else { return }

        if document.selectedTool == .text {
            beginTextEntry(at: location)
            return
        }

        finishTextEntry(commit: true)
        window?.makeFirstResponder(self)
        document.beginStroke(at: normalized(location))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard document.selectedTool != .text else { return }
        let location = convert(event.locationInWindow, from: nil)
        document.appendPoint(normalized(location))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard document.selectedTool != .text else { return }
        let location = convert(event.locationInWindow, from: nil)
        document.appendPoint(normalized(location))
        document.endStroke()
        needsDisplay = true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !isFinishingTextEntry else { return }
        finishTextEntry(commit: true)
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            finishTextEntry(commit: true)
            window?.makeFirstResponder(self)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            finishTextEntry(commit: false)
            window?.makeFirstResponder(self)
            return true
        default:
            return false
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let cursor: NSCursor = switch document.selectedTool {
        case .text: .iBeam
        case .eraser: .operationNotAllowed
        default: .crosshair
        }
        addCursorRect(imageRect, cursor: cursor)
    }

    func updateTextEntryAppearance() {
        guard let textEntryField else { return }
        let fontSize = max(
            14,
            min(48, document.relativeTextSize * min(imageRect.width, imageRect.height))
        )
        textEntryField.font = .systemFont(ofSize: fontSize, weight: .semibold)
        textEntryField.textColor = RGBAColor(document.selectedColor).nsColor
        if let pendingTextPosition {
            textEntryField.frame = textFieldFrame(at: denormalized(pendingTextPosition))
        }
    }

    private func beginTextEntry(at location: CGPoint) {
        finishTextEntry(commit: true)

        let field = NSTextField(frame: textFieldFrame(at: location))
        field.delegate = self
        field.placeholderString = String(localized: "Type here")
        field.setAccessibilityLabel(String(localized: "Text to add"))
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94)
        field.focusRingType = .default
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byClipping

        pendingTextPosition = normalized(field.frame.origin)
        textEntryField = field
        addSubview(field)
        updateTextEntryAppearance()
        window?.makeFirstResponder(field)
    }

    private func finishTextEntry(commit: Bool) {
        guard !isFinishingTextEntry, let field = textEntryField else { return }

        isFinishingTextEntry = true
        let value = field.stringValue
        let position = pendingTextPosition
        field.delegate = nil
        field.removeFromSuperview()
        textEntryField = nil
        pendingTextPosition = nil

        if commit, let position {
            document.addText(value, at: position)
        }

        isFinishingTextEntry = false
        needsDisplay = true
    }

    private func registerCommitHandler() {
        document.commitPendingEditing = { [weak self] in
            self?.finishTextEntry(commit: true)
        }
    }

    private func textFieldFrame(at location: CGPoint) -> CGRect {
        let rect = imageRect
        let fontSize = max(
            14,
            min(48, document.relativeTextSize * min(rect.width, rect.height))
        )
        let height = max(32, ceil(fontSize * 1.55))
        let preferredWidth: CGFloat = 280
        let width = min(preferredWidth, max(120, rect.width))
        let originX = min(max(location.x, rect.minX), max(rect.minX, rect.maxX - width))
        let originY = min(max(location.y, rect.minY), max(rect.minY, rect.maxY - height))
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private var imageRect: CGRect {
        let available = bounds.insetBy(dx: 28, dy: 28)
        let imageSize = document.sourceImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let imageAspect = imageSize.width / imageSize.height
        let availableAspect = available.width / available.height
        let size: CGSize

        if imageAspect > availableAspect {
            size = CGSize(width: available.width, height: available.width / imageAspect)
        } else {
            size = CGSize(width: available.height * imageAspect, height: available.height)
        }

        return CGRect(
            x: available.midX - size.width / 2,
            y: available.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func normalized(_ point: CGPoint) -> NormalizedPoint {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else { return NormalizedPoint(x: 0, y: 0) }
        return NormalizedPoint(
            x: (point.x - rect.minX) / rect.width,
            y: (point.y - rect.minY) / rect.height
        ).clamped
    }

    private func denormalized(_ point: NormalizedPoint) -> CGPoint {
        let rect = imageRect
        return CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}
