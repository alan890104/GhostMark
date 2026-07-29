import AppKit
import ImageIO
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum MarkupTool: String, CaseIterable, Equatable, Identifiable {
    case pen
    case highlighter
    case eraser

    var id: Self { self }

    var title: String {
        switch self {
        case .pen: "畫筆"
        case .highlighter: "螢光筆"
        case .eraser: "橡皮擦"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        }
    }
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

@MainActor
@Observable
final class MarkupDocument {
    let sourceImage: NSImage
    var selectedTool: MarkupTool = .pen
    var selectedColor: Color = .pink
    var relativeLineWidth: CGFloat = 0.008
    private(set) var strokes: [MarkupStroke] = []
    private(set) var revision = 0

    @ObservationIgnored private var redoStack: [MarkupStroke] = []
    @ObservationIgnored private var activeStrokeID: UUID?

    init(sourceImage: NSImage) {
        self.sourceImage = sourceImage
    }

    var canUndo: Bool { !strokes.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func beginStroke(at point: NormalizedPoint) {
        let id = UUID()
        let stroke = MarkupStroke(
            id: id,
            tool: selectedTool,
            color: RGBAColor(selectedColor),
            relativeWidth: relativeLineWidth,
            points: [point.clamped]
        )

        redoStack.removeAll()
        strokes.append(stroke)
        activeStrokeID = id
        revision += 1
    }

    func appendPoint(_ point: NormalizedPoint) {
        guard
            let activeStrokeID,
            let index = strokes.lastIndex(where: { $0.id == activeStrokeID })
        else { return }

        let clampedPoint = point.clamped
        if let previous = strokes[index].points.last {
            let distance = hypot(clampedPoint.x - previous.x, clampedPoint.y - previous.y)
            guard distance > 0.0005 else { return }
        }

        strokes[index].points.append(clampedPoint)
        revision += 1
    }

    func endStroke() {
        activeStrokeID = nil
    }

    func undo() {
        endStroke()
        guard let stroke = strokes.popLast() else { return }
        redoStack.append(stroke)
        revision += 1
    }

    func redo() {
        endStroke()
        guard let stroke = redoStack.popLast() else { return }
        strokes.append(stroke)
        revision += 1
    }

    func renderedPNGData() -> Data? {
        guard let renderedImage = MarkupRenderer.render(sourceImage: sourceImage, strokes: strokes) else {
            return nil
        }

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
    static func render(sourceImage: NSImage, strokes: [MarkupStroke]) -> CGImage? {
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
        draw(strokes: strokes, in: context, imageRect: imageRect, invertNormalizedY: true)

        return context.makeImage()
    }

    static func draw(
        strokes: [MarkupStroke],
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool = false
    ) {
        guard !strokes.isEmpty else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        for stroke in strokes {
            draw(
                stroke: stroke,
                in: context,
                imageRect: imageRect,
                invertNormalizedY: invertNormalizedY
            )
        }

        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func draw(
        stroke: MarkupStroke,
        in context: CGContext,
        imageRect: CGRect,
        invertNormalizedY: Bool
    ) {
        guard let firstPoint = stroke.points.first else { return }

        let minimumDimension = min(imageRect.width, imageRect.height)
        let toolWidthMultiplier: CGFloat = switch stroke.tool {
        case .pen: 1
        case .highlighter: 2.4
        case .eraser: 2.2
        }
        let lineWidth = max(1, stroke.relativeWidth * minimumDimension * toolWidthMultiplier)

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)

        switch stroke.tool {
        case .pen:
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
