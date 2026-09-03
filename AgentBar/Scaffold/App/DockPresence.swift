import AppKit

/// Whether the app is in the Dock and ⌘-Tab (a regular app with a menu bar) or a menu bar
/// item only (an accessory). Nothing else changes: the status item stays either way.
enum DockPresence {
    static func set(_ inDock: Bool) {
        let policy: NSApplication.ActivationPolicy = inDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if inDock {
            // Becoming regular does not activate; without this the new Dock icon sits
            // there with no window until the next click.
            AppActivation.activate()
        } else if NSApp.isActive {
            // Leaving the Dock only takes effect once the app has deactivated: while it
            // stays frontmost (Settings is open, the change was made there) the Dock icon
            // lingers and still answers clicks. Step back and forward once.
            NSApp.deactivate()
            DispatchQueue.main.async { AppActivation.activate() }
        }
    }
}
