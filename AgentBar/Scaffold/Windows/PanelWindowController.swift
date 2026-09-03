import AppKit
import SwiftUI

/// A normal, resizable window for the app's main content - the Dock presence. Created on
/// first use and kept for the rest of the run; closing it hides it, the app keeps running.
/// The content is whatever SwiftUI view the app hands over.
final class PanelWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let frameName: String
    private let minimumSize: NSSize
    private let content: () -> AnyView
    private var window: NSWindow?
    /// nil follows the system. Applied to this window only.
    var appearance: NSAppearance? {
        didSet { window?.appearance = appearance }
    }
    /// Told when the window comes on screen or leaves it.
    var onVisibilityChange: ((Bool) -> Void)?

    var isVisible: Bool { window?.isVisible ?? false }

    init(title: String, frameName: String = "PanelWindow", minimumSize: NSSize, content: @escaping () -> AnyView) {
        self.title = title
        self.frameName = frameName
        self.minimumSize = minimumSize
        self.content = content
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        let wasVisible = window.isVisible
        AppActivation.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if !wasVisible { onVisibilityChange?(true) }
    }

    func close() {
        window?.orderOut(nil)
        onVisibilityChange?(false)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: minimumSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        // The content draws its own header where the title bar would be; only the traffic
        // lights remain of the system's, and the whole surface drags the window.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = minimumSize
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.appearance = appearance
        window.setFrameAutosaveName(frameName)
        let host = NSHostingController(rootView: content())
        // The content's own size is the window's first size and its floor.
        host.sizingOptions = [.minSize]
        window.contentViewController = host
        let fitting = host.view.fittingSize
        let size = NSSize(width: max(minimumSize.width, fitting.width), height: max(minimumSize.height, fitting.height))
        window.contentMinSize = size
        window.setContentSize(size)
        if !window.setFrameUsingName(frameName) { window.center() }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        onVisibilityChange?(false)
    }
}
