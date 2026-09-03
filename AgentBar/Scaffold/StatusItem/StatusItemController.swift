import OSLog
import AppKit
import SwiftUI

/// A small gauge drawn in the menu bar: a few vertical bars and a short text beside them.
/// Colours come in pairs because the menu bar may be light or dark regardless of the app.
struct StatusItemGauge: Equatable {
    struct Bar: Equatable {
        let fraction: Double
        let dark: NSColor
        let light: NSColor
    }
    let bars: [Bar]
    let title: String
    let titleDark: NSColor
    let titleLight: NSColor
    /// Tooltip and accessibility label.
    let summary: String
}

/// Owns the `NSStatusItem` and the `NSPopover` that hosts the SwiftUI panel.
///
/// The item shows either the app symbol or a gauge (bars and a short text). Left click
/// toggles the popover; right click shows a small menu whose items are all reachable from
/// Settings too.
final class StatusItemController: NSObject, NSPopoverDelegate {
    /// Symbol drawn when there is no gauge. Set by the app before `install()`.
    var symbolName = "circle.dashed" {
        didSet { if symbolName != oldValue { render() } }
    }
    /// An asset-catalogue template image to draw instead of the symbol (the app's own
    /// mark), at `imageSize`. macOS tints it for light, dark and selected menu bars.
    var imageName: String? {
        didSet { if imageName != oldValue { render() } }
    }
    static let imageSize = NSSize(width: 18, height: 18)
    /// The size a standard menu bar symbol is drawn at (the bar is 22 pt; Apple's own extras
    /// use ~16 pt template images). Without this the symbol takes the button font's size.
    static let symbolSize: CGFloat = 16

    /// Bars and text instead of the symbol. nil → symbol.
    var gauge: StatusItemGauge? {
        didSet { if gauge != oldValue { render() } }
    }
    /// Tooltip and accessibility label while the symbol shows.
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
    private var appearanceObservation: NSKeyValueObservation?
    private var renderPending = false
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
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            // The menu bar turns light or dark with the wallpaper; the gauge's colours follow it.
            appearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.render() }
            }
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

    /// Replacing the button's image or tooltip while the popover is shown makes AppKit
    /// dismiss the popover, so a change that arrives then waits until it closes.
    func render() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            renderPending = true
            return
        }
        renderPending = false
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let gauge {
            button.toolTip = gauge.summary
            button.setAccessibilityLabel(gauge.summary)
            button.image = Self.barsImage(gauge.bars, dark: dark, trailing: gauge.title.isEmpty ? 0 : 4)
            button.imagePosition = gauge.title.isEmpty ? .imageOnly : .imageLeading
            button.attributedTitle = NSAttributedString(string: gauge.title, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: dark ? gauge.titleDark : gauge.titleLight,
            ])
        } else {
            button.toolTip = summary
            button.setAccessibilityLabel(summary)
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
            if let imageName, let mark = NSImage(named: imageName) {
                mark.size = Self.imageSize
                mark.isTemplate = true
                mark.accessibilityDescription = summary
                button.image = mark
            } else {
                let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: summary)?
                    .withSymbolConfiguration(.init(pointSize: Self.symbolSize, weight: .regular))
                image?.isTemplate = true
                button.image = image
            }
        }
    }

    /// Vertical bars 3 pt wide, 13 pt tall, 2.5 pt apart, each filled from the bottom; a
    /// 4 pt clear margin on the right keeps the title off them. Not a template image: the
    /// colours mean something.
    private static func barsImage(_ bars: [StatusItemGauge.Bar], dark: Bool, trailing: CGFloat) -> NSImage {
        let barWidth: CGFloat = 3, height: CGFloat = 13, gap: CGFloat = 2.5
        let width = CGFloat(bars.count) * barWidth + CGFloat(max(0, bars.count - 1)) * gap + trailing
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let track = dark ? NSColor.white.withAlphaComponent(0.26) : NSColor.black.withAlphaComponent(0.22)
            for (index, bar) in bars.enumerated() {
                let x = CGFloat(index) * (barWidth + gap)
                let full = NSRect(x: x, y: 0, width: barWidth, height: height)
                track.setFill()
                NSBezierPath(roundedRect: full, xRadius: 1.5, yRadius: 1.5).fill()
                let lit = NSRect(x: x, y: 0, width: barWidth, height: (height * min(1, max(0, bar.fraction))).rounded())
                (dark ? bar.dark : bar.light).setFill()
                NSBezierPath(roundedRect: lit, xRadius: 1.5, yRadius: 1.5).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: Popover

    func showPopover() {
        guard let button = statusItem?.button else { return }
        showPopover(from: button, edge: .minY)
    }

    /// The same popover hanging off another view - the app's Dock icon, through an anchor
    /// parked over it - opening towards `edge`.
    func showPopover(from anchor: NSView, edge: NSRectEdge) {
        guard !popover.isShown else { return }
        AppActivation.activate()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
        popover.contentViewController?.view.window?.makeKey()
        if anchor === statusItem?.button { statusItem?.button?.highlight(true) }
        installMonitors()
        onPanelOpened?()
        Log.statusItem.debug("popover shown; app active=\(NSApp.isActive)")
    }

    func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func togglePopover() {
        popover.isShown ? closePopover() : showPopover()
    }

    func popoverDidClose(_ notification: Notification) {
        Log.statusItem.debug("popover closed")
        statusItem?.button?.highlight(false)
        removeMonitors()
        onPanelClosed?()
        if renderPending { render() }
    }

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // While the app is not active (activation after a status item click is
            // asynchronous, and refused outright now and then), the click that lands on
            // our own popover reaches this monitor too. Only a click elsewhere closes it.
            let location = NSEvent.mouseLocation
            Task { @MainActor in
                guard let self else { return }
                if let frame = self.popover.contentViewController?.view.window?.frame, frame.contains(location) { return }
                Log.statusItem.debug("closing popover: click outside")
                self.closePopover()
            }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                Log.statusItem.debug("closing popover: app resigned active")
                self?.closePopover()
            }
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
