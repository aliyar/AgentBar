import OSLog
import AppKit
import SwiftUI
import AgentBarKit

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
        // One read at launch, until the refresh loop arrives with the popover.
        Task.detached(priority: .utility) {
            let snapshot = UsageReader.read()
            Log.app.notice("read \(snapshot.limits.count) limits, \(snapshot.conversations.count) conversations; agents: \(snapshot.lastWritten.keys.map(\.rawValue).sorted().joined(separator: ","), privacy: .public)")
        }
    }
}
