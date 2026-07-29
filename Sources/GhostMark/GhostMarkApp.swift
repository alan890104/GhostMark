import AppKit
import SwiftUI

@main
struct GhostMarkApp: App {
    @NSApplicationDelegateAdaptor(GhostMarkAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("GhostMark", systemImage: "pencil.tip") {
            StatusMenuView(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class GhostMarkAppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}
