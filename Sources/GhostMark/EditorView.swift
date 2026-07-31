import SwiftUI

struct EditorView: View {
    @Bindable var document: MarkupDocument
    let agentTarget: AgentTarget?
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MarkupCanvasView(document: document, revision: document.revision)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Image markup canvas")
                .accessibilityHint("Drag over the image to use the selected tool")

            MarkupToolbar(document: document)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            EditorHeader(
                agentTarget: agentTarget,
                onCancel: onCancel,
                onDone: onDone
            )
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }
}

private struct EditorHeader: View {
    let agentTarget: AgentTarget?
    let onCancel: () -> Void
    let onDone: () -> Void

    private var completionTitle: LocalizedStringResource {
        agentTarget?.completionTitle ?? "Copy image"
    }

    private var editorTitle: LocalizedStringResource {
        agentTarget == nil ? "Mark up your image" : "Mark up before sending to your AI agent"
    }

    var body: some View {
        HStack(spacing: 14) {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .fixedSize()

            Text(editorTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)

            Button(action: onDone) {
                Label {
                    Text(completionTitle)
                } icon: {
                    Image(systemName: agentTarget == nil ? "doc.on.doc" : "paperplane.fill")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .fixedSize()
            .accessibilityIdentifier("send-button")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 54)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct MarkupToolbar: View {
    @Bindable var document: MarkupDocument
    @State private var showsColorPopover = false
    @State private var showsSizePopover = false

    var body: some View {
        HStack(spacing: 14) {
            Spacer(minLength: 0)
            historyControls
            Divider().frame(height: 28)
            toolControls
            Divider().frame(height: 28)
            styleControls
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
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
                        .frame(width: 23, height: 23)
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

    private var styleControls: some View {
        HStack(spacing: 6) {
            Button {
                showsColorPopover.toggle()
            } label: {
                Circle()
                    .fill(document.selectedColor)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle().stroke(.white.opacity(0.82), lineWidth: 1.5)
                    }
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(.bordered)
            .disabled(!document.selectedTool.supportsColor)
            .opacity(document.selectedTool.supportsColor ? 1 : 0.38)
            .accessibilityLabel("Choose color")
            .help("Choose color")
            .popover(isPresented: $showsColorPopover, arrowEdge: .bottom) {
                ColorPalette(document: document)
            }

            Button {
                showsSizePopover.toggle()
            } label: {
                Image(systemName: document.selectedTool.usesTextSize ? "textformat.size" : "lineweight")
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(document.selectedTool.usesTextSize ? "Text size" : "Line width")
            .help(document.selectedTool.usesTextSize ? "Text size" : "Line width")
            .popover(isPresented: $showsSizePopover, arrowEdge: .bottom) {
                SizeControl(document: document)
            }
        }
        .controlSize(.large)
    }
}

private struct ColorPalette: View {
    @Bindable var document: MarkupDocument

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 10), count: 5)
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
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(swatches) { swatch in
                    Button {
                        document.selectedColor = swatch.color
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Circle()
                                    .stroke(.primary, lineWidth: isSelected(swatch.color) ? 2 : 0.5)
                                    .padding(isSelected(swatch.color) ? -3 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose color")
                    .accessibilityAddTraits(isSelected(swatch.color) ? .isSelected : [])
                }
            }

            Divider()

            ColorPicker("Custom color", selection: $document.selectedColor, supportsOpacity: false)
        }
        .padding(16)
    }

    private func isSelected(_ color: Color) -> Bool {
        RGBAColor(color) == RGBAColor(document.selectedColor)
    }
}

private struct SizeControl: View {
    @Bindable var document: MarkupDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                document.selectedTool.usesTextSize ? "Text size" : "Line width",
                systemImage: document.selectedTool.usesTextSize ? "textformat.size" : "lineweight"
            )
            .font(.headline)

            if document.selectedTool.usesTextSize {
                HStack(spacing: 10) {
                    Text("A").font(.caption)
                    Slider(value: $document.relativeTextSize, in: 0.025...0.12)
                        .accessibilityLabel("Text size")
                    Text("A").font(.title2)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .accessibilityHidden(true)
                    Slider(value: $document.relativeLineWidth, in: 0.002...0.03)
                        .accessibilityLabel("Line width")
                    Image(systemName: "circle.fill")
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: 230)
        .padding(16)
    }
}

private struct ColorSwatch: Identifiable {
    let id: String
    let color: Color
}
