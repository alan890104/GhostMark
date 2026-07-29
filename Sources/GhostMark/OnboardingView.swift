import SwiftUI

struct OnboardingView: View {
    @Bindable var controller: AppController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 26)

            MarkGlyph(isRevealed: isRevealed || reduceMotion)
                .frame(width: 154, height: 154)
                .accessibilityHidden(true)

            Text("貼圖，先畫一下。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .padding(.top, 24)

            OnboardingSteps()
                .padding(.top, 26)

            Spacer(minLength: 30)

            Button(primaryButtonTitle, action: controller.performOnboardingPrimaryAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(width: 240)

            permissionHint
                .frame(height: 28)

            Label("圖片只留在這台 Mac", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .frame(width: 480, height: 510)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(red: 0.075, green: 0.082, blue: 0.105)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).delay(0.12)) {
                isRevealed = true
            }
        }
    }

    private var primaryButtonTitle: String {
        controller.permissionState == .granted ? "開始" : "允許並開始"
    }

    @ViewBuilder
    private var permissionHint: some View {
        if controller.hasRequestedPermission, controller.permissionState != .granted {
            Text("在系統設定打開 GhostMark")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Color.clear
        }
    }
}

private struct OnboardingSteps: View {
    private let steps = [
        ("doc.on.clipboard", "貼上"),
        ("pencil.tip", "標記"),
        ("paperplane.fill", "完成")
    ]

    var body: some View {
        HStack(spacing: 13) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 7) {
                    Image(systemName: step.0)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(index == 1 ? Color.pink : .secondary)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
                    Text(step.1)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if index < steps.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("貼上、標記、完成")
    }
}

private struct MarkGlyph: View {
    let isRevealed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color(red: 0.075, green: 0.082, blue: 0.105))
                .shadow(color: .black.opacity(0.34), radius: 30, y: 18)

            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(red: 0.96, green: 0.97, blue: 0.98))
                .frame(width: 92, height: 72)

            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 25, height: 4)
            }
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color(red: 0.075, green: 0.082, blue: 0.105))

            MarkerLoop()
                .trim(from: 0, to: isRevealed ? 1 : 0)
                .stroke(
                    Color(red: 1, green: 0.24, blue: 0.45),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 132, height: 112)
        }
    }
}

private struct MarkerLoop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.59))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.57, y: rect.height * 0.13),
            control1: CGPoint(x: rect.width * 0.13, y: rect.height * 0.18),
            control2: CGPoint(x: rect.width * 0.39, y: rect.height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.93, y: rect.height * 0.59),
            control1: CGPoint(x: rect.width * 0.83, y: rect.height * 0.18),
            control2: CGPoint(x: rect.width * 0.96, y: rect.height * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.88),
            control1: CGPoint(x: rect.width * 0.84, y: rect.height * 0.94),
            control2: CGPoint(x: rect.width * 0.43, y: rect.height * 0.98)
        )
        return path
    }
}
