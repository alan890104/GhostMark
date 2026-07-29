import AppKit
import SwiftUI

struct StatusMenuView: View {
    @Bindable var controller: AppController

    var body: some View {
        Toggle("攔截 Claude Code 圖片貼上", isOn: $controller.isEnabled)

        Text(controller.statusMessage)

        Divider()

        Button("編輯剪貼簿中的圖片…", systemImage: "photo.badge.pencil") {
            controller.openClipboardEditor()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])

        Button("使用說明…", systemImage: "sparkles") {
            controller.showOnboarding()
        }

        if controller.permissionState != .granted {
            Button("開啟輔助使用權限…", systemImage: "hand.raised") {
                controller.requestAccessibilityPermission()
            }
        } else if !controller.eventTapIsActive {
            Button("重新啟動鍵盤監聽", systemImage: "arrow.clockwise") {
                controller.refreshAccessibilityPermission()
            }
        }

        Divider()

        Button("結束 GhostMark") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
