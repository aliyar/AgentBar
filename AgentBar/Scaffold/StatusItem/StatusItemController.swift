import OSLog
import AppKit
import SwiftUI

/// Owns the `NSStatusItem` and the `NSPopover` that hosts the SwiftUI panel.
///
/// The item shows either the app symbol or a short text title (the usage gauge, "78%", set by a
/// later milestone). Left click toggles the popover; right click shows a small menu whose
/// items are all reachable from Settings too.
final class StatusItemController: NSObject, NSPopoverDelegate {
    /// Symbol drawn when there is no title. Set by the app before `install()`.
    var symbolName = "circle.dashed" {
        didSet { if symbolName != oldValue { render() } }
    }
    /// The size a standard menu bar symbol is drawn at (the bar is 22 pt; Apple's own extras
    /// use ~16 pt template images). Without this the symbol takes the button font's size.
    static let symbolSize: CGFloat = 16

    /// Text shown instead of the symbol (monospaced digits, so it does not jiggle). nil → symbol.
    var title: String? {
        didSet { if title != oldValue { render() } }
    }
    /// Tooltip and accessibility label.
    var summary = StatusItemController.appName {
        didSet { if summary != oldValue { render() } }
    }
    /// Builds the SwiftUI root of the popover. Set before `install()`.
    var panelRoot: (() -> AnyView)?

    /// nil follows the system. Applied to the popover only, so the status item glyph keeps
    /// matching the menu bar rather than the app's chosen theme.
    var appearance: NSAppearance? {
        didSet { popover.appearance = appearance }
    }

    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var onPanelOpened: (() -> Void)?
    var onPanelClosed: (() -> Void)?

    static var appName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "App" }

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var globalMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    var isPopoverShown: Bool { popover.isShown }

    // MARK: Lifecycle

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = []
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let host = NSHostingController(rootView: panelRoot?() ?? AnyView(EmptyView()))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host

        render()
        Log.statusItem.info("status item installed")
    }

    func render() {
        guard let button = statusItem?.button else { return }
        button.toolTip = summary
        button.setAccessibilityLabel(summary)
        if let title, !title.isEmpty {
            button.image = nil
            button.imagePosition = .noImage
            button.title = title
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: summary)?
                .withSymbolConfiguration(.init(pointSize: Self.symbolSize, weight: .regular))
            image?.isTemplate = true
            button.image = image
        }
    }

    // MARK: Popover

    func showPopover() {
        guard let button = statusItem?.button, !popover.isShown else { return }
        AppActivation.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
        installMonitors()
        onPanelOpened?()
    }

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func togglePopover() {
        popover.isShown ? closePopover() : showPopover()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
        removeMonitors()
        onPanelClosed?()
    }

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }
    }

    private func removeMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
    }

    // MARK: Clicks & menu

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isSecondary {
            closePopover()
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func showMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        menu.addItem(makeItem("Settings…", action: #selector(menuOpenSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit \(Self.appName)", action: #selector(menuQuit), key: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func menuOpenSettings() { onOpenSettings?() }
    @objc private func menuQuit() { onQuit?() }
}
