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

/// A transparent view laid over the status item's button that reports the pointer
/// entering and leaving it. Clicks pass through: it takes no events of its own.
private final class HoverTracking: NSView {
    private let onHover: (Bool) -> Void

    init(frame: NSRect, onHover: @escaping (Bool) -> Void) {
        self.onHover = onHover
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onHover(true) }
    override func mouseExited(with event: NSEvent) { onHover(false) }
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
    /// Something needs attention. Draws a small mark beside whatever the item is showing,
    /// gauge or symbol. Monochrome on purpose: the menu bar tints what it likes, and a
    /// colour here would argue with the gauge's own colours, which already mean something.
    var alert = false {
        didSet { if alert != oldValue { render() } }
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

    /// Takes the item out of the menu bar (the app lives in the Dock alone). The popover
    /// stays, to be shown from another anchor; `install()` puts the item back.
    func remove() {
        guard let item = statusItem else { return }
        closePopover()
        appearanceObservation = nil
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        Log.statusItem.info("status item removed")
    }

    var isInstalled: Bool { statusItem != nil }

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
            // The menu bar's capsule behind the item under the pointer, as it is behind a
            // pressed one; it stays while the popover is up.
            let tracking = HoverTracking(frame: button.bounds) { [weak self] inside in
                guard let self, let button = self.statusItem?.button else { return }
                button.highlight(inside || self.popover.isShown)
            }
            button.addSubview(tracking)
        }

        if popover.contentViewController == nil {
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            let host = NSHostingController(rootView: panelRoot?() ?? AnyView(EmptyView()))
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
        }

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
            button.image = Self.barsImage(gauge.bars, dark: dark, trailing: gauge.title.isEmpty ? 0 : 4, alert: alert)
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
            let glyph: NSImage?
            if let imageName, let mark = NSImage(named: imageName) {
                mark.size = Self.imageSize
                mark.isTemplate = true
                mark.accessibilityDescription = summary
                glyph = mark
            } else {
                let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: summary)?
                    .withSymbolConfiguration(.init(pointSize: Self.symbolSize, weight: .regular))
                image?.isTemplate = true
                glyph = image
            }
            button.image = alert ? glyph.map(Self.marked) : glyph
        }
    }

    /// Vertical bars 3 pt wide, 13 pt tall, 2.5 pt apart, each filled from the bottom; a
    /// 4 pt clear margin on the right keeps the title off them. Not a template image: the
    /// colours mean something.
    ///
    /// With `alert`, the exclamation mark below is drawn after the bars, in the menu bar's
    /// own ink rather than in one of the meters' colours: the bars say how full a window
    /// is, and this says something else entirely.
    private static func barsImage(_ bars: [StatusItemGauge.Bar], dark: Bool, trailing: CGFloat,
                                  alert: Bool = false) -> NSImage {
        let barWidth: CGFloat = 3, height: CGFloat = 13, gap: CGFloat = 2.5
        let markRoom: CGFloat = alert ? alertWidth + gap : 0
        let width = CGFloat(bars.count) * barWidth + CGFloat(max(0, bars.count - 1)) * gap + markRoom + trailing
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
            if alert {
                let x = CGFloat(bars.count) * (barWidth + gap)
                drawAlert(at: NSPoint(x: x, y: 0), height: height, ink: dark ? .white : .black)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// An exclamation mark 2 pt wide: a stroke with a dot under it, sized to sit beside a
    /// 13 pt bar or a 16 pt symbol without becoming one of them.
    private static let alertWidth: CGFloat = 2

    private static func drawAlert(at origin: NSPoint, height: CGFloat, ink: NSColor) {
        let dot = alertWidth, gap: CGFloat = 1.5
        let stroke = (height * 0.46).rounded()
        // The whole mark, centred on the glyph beside it: dot at the bottom, stroke above.
        let bottom = origin.y + ((height - (stroke + gap + dot)) / 2).rounded()
        ink.setFill()
        NSBezierPath(ovalIn: NSRect(x: origin.x, y: bottom, width: dot, height: dot)).fill()
        NSBezierPath(roundedRect: NSRect(x: origin.x, y: bottom + dot + gap, width: alertWidth, height: stroke),
                     xRadius: alertWidth / 2, yRadius: alertWidth / 2).fill()
    }

    /// The same mark beside a template glyph, in one template image so the menu bar tints
    /// both together.
    private static func marked(_ glyph: NSImage) -> NSImage {
        let gap: CGFloat = 3
        let size = NSSize(width: glyph.size.width + gap + alertWidth, height: glyph.size.height)
        let image = NSImage(size: size, flipped: false) { _ in
            glyph.draw(in: NSRect(origin: .zero, size: glyph.size))
            drawAlert(at: NSPoint(x: glyph.size.width + gap, y: 0), height: glyph.size.height, ink: .black)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = glyph.accessibilityDescription
        return image
    }

    // MARK: Popover

    func showPopover() {
        guard let button = statusItem?.button else { return }
        showPopover(from: button, edge: .minY)
    }

    /// The same popover hanging off another view - the app's Dock icon, through an anchor
    /// parked over it - opening towards `edge`. Works with no status item installed.
    func showPopover(from anchor: NSView, edge: NSRectEdge) {
        guard !popover.isShown else { return }
        if popover.contentViewController == nil {
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self
            let host = NSHostingController(rootView: panelRoot?() ?? AnyView(EmptyView()))
            host.sizingOptions = [.preferredContentSize]
            popover.contentViewController = host
        }
        AppActivation.activate()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
        popover.contentViewController?.view.window?.makeKey()
        if anchor === statusItem?.button {
            // The button's own mouse tracking un-highlights it when the click that opened
            // the popover ends, a moment after this; assert the capsule after that.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.popover.isShown else { return }
                self.statusItem?.button?.highlight(true)
            }
        }
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
