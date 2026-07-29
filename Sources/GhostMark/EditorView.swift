import SwiftUI

struct EditorView: View {
    @Bindable var document: MarkupDocument
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EditorHeader(onCancel: onCancel, onDone: onDone)

            MarkupCanvasView(document: document, revision: document.revision)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Image markup canvas")
                .accessibilityHint("Drag over the image to use the selected tool")

            MarkupToolbar(document: document)
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }
}

private struct EditorHeader: View {
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Text("Mark up before sending to Claude Code")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Button("Done", action: onDone)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct MarkupToolbar: View {
    @Bindable var document: MarkupDocument

    private let swatches: [ColorSwatch] = [
        ColorSwatch(id: "pink", color: .pink),
        ColorSwatch(id: "red", color: .red),
        ColorSwatch(id: "orange", color: .orange),
        ColorSwatch(id: "yellow", color: .yellow),
        ColorSwatch(id: "green", color: .green),
        ColorSwatch(id: "cyan", color: .cyan),
        ColorSwatch(id: "blue", color: .blue),
        ColorSwatch(id: "purple", color: .purple),
        ColorSwatch(id: "white", color: .white),
        ColorSwatch(id: "black", color: .black)
    ]

    var body: some View {
        HStack(spacing: 16) {
            historyControls
            Divider().frame(height: 28)
            toolControls
            Divider().frame(height: 28)
            colorControls
            Divider().frame(height: 28)
            widthControl
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial)
    }

    private var historyControls: some View {
        HStack(spacing: 6) {
            Button("Undo", systemImage: "arrow.uturn.backward", action: document.undo)
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!document.canUndo)
                .help("Undo (⌘Z)")

            Button("Redo", systemImage: "arrow.uturn.forward", action: document.redo)
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!document.canRedo)
                .help("Redo (⇧⌘Z)")
        }
        .controlSize(.large)
    }

    private var toolControls: some View {
        HStack(spacing: 6) {
            ForEach(MarkupTool.allCases) { tool in
                Button {
                    document.selectedTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .tint(document.selectedTool == tool ? .accentColor : .secondary)
                .accessibilityLabel(Text(tool.title))
                .accessibilityAddTraits(document.selectedTool == tool ? .isSelected : [])
                .help(Text(tool.title))
            }
        }
        .controlSize(.large)
    }

    private var colorControls: some View {
        HStack(spacing: 8) {
            ForEach(swatches) { swatch in
                Button {
                    document.selectedColor = swatch.color
                } label: {
                    Circle()
                        .fill(swatch.color)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isSelected(swatch.color) ? 1 : 0), lineWidth: 2)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose color")
                .accessibilityAddTraits(isSelected(swatch.color) ? .isSelected : [])
            }

            ColorPicker("Custom color", selection: $document.selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)
        }
        .disabled(document.selectedTool == .eraser)
    }

    private var widthControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .accessibilityHidden(true)

            Slider(value: $document.relativeLineWidth, in: 0.002...0.03)
                .frame(width: 130)
                .accessibilityLabel("Line width")

            Image(systemName: "circle.fill")
                .font(.system(size: 17))
                .accessibilityHidden(true)
        }
    }

    private func isSelected(_ color: Color) -> Bool {
        RGBAColor(color) == RGBAColor(document.selectedColor)
    }
}

private struct ColorSwatch: Identifiable {
    let id: String
    let color: Color
}
