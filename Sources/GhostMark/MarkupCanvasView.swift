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
        nsView.needsDisplay = true
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

@MainActor
final class MarkupCanvasNSView: NSView {
    var document: MarkupDocument {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(document: MarkupDocument) {
        self.document = document
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.055, alpha: 1).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            MarkupRenderer.draw(strokes: document.strokes, in: context, imageRect: rect)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(location) else { return }
        document.beginStroke(at: normalized(location))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        document.appendPoint(normalized(location))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        document.appendPoint(normalized(location))
        document.endStroke()
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(imageRect, cursor: document.selectedTool == .eraser ? .operationNotAllowed : .crosshair)
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
}
