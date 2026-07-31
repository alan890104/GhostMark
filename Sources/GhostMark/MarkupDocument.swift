import AppKit
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum MarkupTool: String, CaseIterable, Equatable, Identifiable {
    case pen
    case highlighter
    case line
    case arrow
    case text
    case eraser

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .line: "Line"
        case .arrow: "Arrow"
        case .text: "Text"
        case .eraser: "Eraser"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .text: "character.textbox"
        case .eraser: "eraser"
        }
    }

    var supportsColor: Bool { self != .eraser }
    var usesTextSize: Bool { self == .text }
}

struct NormalizedPoint: Equatable {
    var x: CGFloat
    var y: CGFloat

    var clamped: NormalizedPoint {
        NormalizedPoint(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }
}

struct RGBAColor: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: Color) {
        let converted = NSColor(color).usingColorSpace(.deviceRGB) ?? .systemPink
        red = converted.redComponent
        green = converted.greenComponent
        blue = converted.blueComponent
        alpha = converted.alphaComponent
    }

    var nsColor: NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    func cgColor(alphaMultiplier: CGFloat = 1) -> CGColor {
        CGColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha * alphaMultiplier
        )
    }
}

struct MarkupStroke: Equatable, Identifiable {
    let id: UUID
    let tool: MarkupTool
    let color: RGBAColor
    let relativeWidth: CGFloat
    var points: [NormalizedPoint]
}

struct MarkupText: Equatable, Identifiable {
    let id: UUID
    let text: String
    let color: RGBAColor
    let relativeFontSize: CGFloat
    let position: NormalizedPoint
}

enum MarkupAnnotation: Equatable, Identifiable {
    case stroke(MarkupStroke)
    case text(MarkupText)

    var id: UUID {
        switch self {
        case .stroke(let stroke): stroke.id
        case .text(let text): text.id
        }
    }
}

@MainActor
@Observable
final class MarkupDocument {
    let sourceImage: NSImage
    var selectedTool: MarkupTool = .pen
    var selectedColor: Color = .pink
    var relativeLineWidth: CGFloat = 0.008
    var relativeTextSize: CGFloat = 0.05
    private(set) var annotations: [MarkupAnnotation] = []
    private(set) var revision = 0

    @ObservationIgnored private var redoStack: [MarkupAnnotation] = []
    @ObservationIgnored private var activeStrokeID: UUID?
    @ObservationIgnored var commitPendingEditing: (() -> Void)?

    init(sourceImage: NSImage) {
        self.sourceImage = sourceImage
    }

    var strokes: [MarkupStroke] {
        annotations.compactMap {
            guard case .stroke(let stroke) = $0 else { return nil }
            return stroke
        }
    }

    var textElements: [MarkupText] {
        annotations.compactMap {
            guard case .text(let text) = $0 else { return nil }
            return text
        }
    }

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func beginStroke(at point: NormalizedPoint) {
        guard selectedTool != .text else { return }

        let id = UUID()
        let stroke = MarkupStroke(
            id: id,
            tool: selectedTool,
            color: RGBAColor(selectedColor),
            relativeWidth: relativeLineWidth,
            points: [point.clamped]
        )

        redoStack.removeAll()
        annotations.append(.stroke(stroke))
        activeStrokeID = id
        revision += 1
    }

    func appendPoint(_ point: NormalizedPoint) {
        guard
            let activeStrokeID,
            let index = annotations.lastIndex(where: { $0.id == activeStrokeID }),
            case .stroke(var stroke) = annotations[index]
        else { return }

        let clampedPoint = point.clamped
        if stroke.tool == .line || stroke.tool == .arrow {
            if stroke.points.count == 1 {
                stroke.points.append(clampedPoint)
            } else {
                stroke.points[1] = clampedPoint
                stroke.points.removeSubrange(2...)
            }
        } else {
            if let previous = stroke.points.last {
                let distance = hypot(clampedPoint.x - previous.x, clampedPoint.y - previous.y)
                guard distance > 0.0005 else { return }
            }
            stroke.points.append(clampedPoint)
        }

        annotations[index] = .stroke(stroke)
        revision += 1
    }

    func endStroke() {
        activeStrokeID = nil
    }

    func addText(_ value: String, at point: NormalizedPoint) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        redoStack.removeAll()
        annotations.append(.text(MarkupText(
            id: UUID(),
            text: text,
            color: RGBAColor(selectedColor),
            relativeFontSize: relativeTextSize,
            position: point.clamped
        )))
        revision += 1
    }

    func undo() {
        endStroke()
        guard let annotation = annotations.popLast() else { return }
        redoStack.append(annotation)
        revision += 1
    }

    func redo() {
        endStroke()
        guard let annotation = redoStack.popLast() else { return }
        annotations.append(annotation)
        revision += 1
    }

    func renderedPNGData() -> Data? {
        commitPendingEditing?()

        guard let renderedImage = MarkupRenderer.render(
            sourceImage: sourceImage,
            annotations: annotations
        ) else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, renderedImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum MarkupRenderer {
    static func render(sourceImage: NSImage, annotations: [MarkupAnnotation]) -> CGImage? {
        var proposedRect = NSRect(origin: .zero, size: sourceImage.size)
        guard let source = sourceImage.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else { return nil }

        let width = source.width
        let height = source.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        let imageRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(source, in: imageRect)
        draw(
            annotations: annotations,
            in: context,
            imageRect: imageRect,
            invertNormalizedY: true
        )

        return context.makeImage()
    }

    static func render(sourceImage: NSImage, strokes: [MarkupStroke]) -> CGImage? {
        render(sourceImage: sourceImage, annotations: strokes.map(MarkupAnnotation.stroke))
    }

    static func draw(
        annotations: [MarkupAnnotation],
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool = false
    ) {
        guard !annotations.isEmpty else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        for annotation in annotations {
            switch annotation {
            case .stroke(let stroke):
                draw(
                    stroke: stroke,
                    in: context,
                    imageRect: imageRect,
                    invertNormalizedY: invertNormalizedY
                )
            case .text(let text):
                draw(
                    text: text,
                    in: context,
                    imageRect: imageRect,
                    invertNormalizedY: invertNormalizedY
                )
            }
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    static func draw(
        strokes: [MarkupStroke],
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool = false
    ) {
        draw(
            annotations: strokes.map(MarkupAnnotation.stroke),
            in: context,
            imageRect: imageRect,
            invertNormalizedY: invertNormalizedY
        )
    }

    private static func draw(
        stroke: MarkupStroke,
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool
    ) {
        guard let firstPoint = stroke.points.first, stroke.tool != .text else { return }

        let minimumDimension = min(imageRect.width, imageRect.height)
        let toolWidthMultiplier: CGFloat = switch stroke.tool {
        case .pen, .line, .arrow: 1
        case .highlighter: 2.4
        case .eraser: 2.2
        case .text: 1
        }
        let lineWidth = max(1, stroke.relativeWidth * minimumDimension * toolWidthMultiplier)

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)

        switch stroke.tool {
        case .pen, .line, .arrow:
            context.setBlendMode(.normal)
            context.setStrokeColor(stroke.color.cgColor())
            context.setFillColor(stroke.color.cgColor())
        case .highlighter:
            context.setBlendMode(.normal)
            context.setStrokeColor(stroke.color.cgColor(alphaMultiplier: 0.32))
            context.setFillColor(stroke.color.cgColor(alphaMultiplier: 0.32))
        case .eraser:
            context.setBlendMode(.clear)
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setFillColor(CGColor(gray: 0, alpha: 1))
        case .text:
            break
        }

        let start = denormalize(firstPoint, in: imageRect, invertY: invertNormalizedY)
        if stroke.points.count == 1 {
            context.fillEllipse(
                in: CGRect(
                    x: start.x - lineWidth / 2,
                    y: start.y - lineWidth / 2,
                    width: lineWidth,
                    height: lineWidth
                )
            )
        } else if stroke.tool == .line || stroke.tool == .arrow {
            let end = denormalize(stroke.points[1], in: imageRect, invertY: invertNormalizedY)
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            if stroke.tool == .arrow {
                drawArrowhead(
                    from: start,
                    to: end,
                    lineWidth: lineWidth,
                    minimumDimension: minimumDimension,
                    in: context
                )
            }
        } else {
            context.beginPath()
            context.move(to: start)
            for point in stroke.points.dropFirst() {
                context.addLine(to: denormalize(point, in: imageRect, invertY: invertNormalizedY))
            }
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func drawArrowhead(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        minimumDimension: CGFloat,
        in context: CGContext
    ) {
        guard start != end else { return }

        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = max(lineWidth * 4.5, minimumDimension * 0.025)
        let spread: CGFloat = 0.48
        let firstWing = CGPoint(
            x: end.x + cos(angle + .pi - spread) * length,
            y: end.y + sin(angle + .pi - spread) * length
        )
        let secondWing = CGPoint(
            x: end.x + cos(angle + .pi + spread) * length,
            y: end.y + sin(angle + .pi + spread) * length
        )

        context.beginPath()
        context.move(to: firstWing)
        context.addLine(to: end)
        context.addLine(to: secondWing)
        context.strokePath()
    }

    private static func draw(
        text: MarkupText,
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool
    ) {
        let minimumDimension = min(imageRect.width, imageRect.height)
        let fontSize = max(8, text.relativeFontSize * minimumDimension)
        let attributedText = NSAttributedString(
            string: text.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: text.color.nsColor
            ]
        )
        let size = attributedText.size()
        var position = denormalize(text.position, in: imageRect, invertY: invertNormalizedY)
        if invertNormalizedY {
            position.y -= size.height
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(
            cgContext: context,
            flipped: !invertNormalizedY
        )
        attributedText.draw(at: position)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func denormalize(
        _ point: NormalizedPoint,
        in rect: CGRect,
        invertY: Bool
    ) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: invertY
                ? rect.maxY - point.y * rect.height
                : rect.minY + point.y * rect.height
        )
    }
}
