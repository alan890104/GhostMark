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
                .accessibilityLabel("圖片標記畫布")
                .accessibilityHint("在圖片上拖曳以使用目前選取的工具")

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
            Button("取消", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Text("標記後貼到 Claude Code")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Button("完成", action: onDone)
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

    private let swatches: [Color] = [
        .pink,
        .red,
        .orange,
        .yellow,
        .green,
        .cyan,
        .blue,
        .purple,
        .white,
        .black
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
            Button("復原", systemImage: "arrow.uturn.backward", action: document.undo)
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!document.canUndo)
                .help("復原（⌘Z）")

            Button("重做", systemImage: "arrow.uturn.forward", action: document.redo)
                .labelStyle(.iconOnly)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!document.canRedo)
                .help("重做（⇧⌘Z）")
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
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(document.selectedTool == tool ? .isSelected : [])
                .help(tool.title)
            }
        }
        .controlSize(.large)
    }

    private var colorControls: some View {
        HStack(spacing: 8) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                Button {
                    document.selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(isSelected(color) ? 1 : 0), lineWidth: 2)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("選擇顏色")
                .accessibilityAddTraits(isSelected(color) ? .isSelected : [])
            }

            ColorPicker("自訂顏色", selection: $document.selectedColor, supportsOpacity: false)
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
                .accessibilityLabel("線條粗細")

            Image(systemName: "circle.fill")
                .font(.system(size: 17))
                .accessibilityHidden(true)
        }
    }

    private func isSelected(_ color: Color) -> Bool {
        RGBAColor(color) == RGBAColor(document.selectedColor)
    }
}
