import AppKit

// No SwiftUI `App` scene: every window the app has is an NSWindow of its own (Settings, later
// the Dock window), so the SwiftUI `Settings` scene and its fragile "showSettingsWindow:"
// action are not needed. The delegate builds everything after launch.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
