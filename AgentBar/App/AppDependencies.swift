import OSLog
import AppKit
import SwiftUI

/// Composition root. Created in `applicationWillFinishLaunching`, before any scene exists.
final class AppDependencies {
    private(set) static var shared: AppDependencies!

    let statusItem: StatusItemController
    let updates: UpdateController

    private init() {
        statusItem = StatusItemController()
        updates = UpdateController()
        wire()
    }

    static func bootstrap() {
        guard shared == nil else { return }
        shared = AppDependencies()
    }

    private func wire() {
        let updates = updates
        statusItem.panelRoot = { AnyView(PopoverView().environment(updates)) }
        statusItem.onOpenSettings = { AppActivation.openSettings() }
        statusItem.onQuit = { NSApp.terminate(nil) }
    }

    func start() {
        updates.start()
        Log.app.notice("AgentBar started")
    }
}
