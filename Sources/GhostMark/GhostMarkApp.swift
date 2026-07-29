import AppKit
import SwiftUI

@main
struct GhostMarkApp: App {
    @NSApplicationDelegateAdaptor(GhostMarkAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class GhostMarkAppDelegate: NSObject, NSApplicationDelegate {
    let controller = AppController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        let statusItemController = StatusItemController(controller: controller)
        statusItemController.start()
        self.statusItemController = statusItemController
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.stop()
        controller.stop()
    }
}
