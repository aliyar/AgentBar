import AppKit

/// Somewhere for a popover to hang when the app is clicked in macOS's Dock. The Dock is
/// another process and its icon frames are only readable with the Accessibility
/// permission, so instead this parks an invisible window over the slice of the Dock the
/// pointer is on - the click that reopened the app came from there - and hands its view
/// back as something `NSPopover` can point at. (Great Menubar's approach.)
final class DockIconAnchor {
    private var window: NSWindow?

    /// How far from a screen edge the pointer still counts as "on the Dock" when the
    /// Dock is hidden and the visible frame cannot say where it is.
    private static let hiddenDockReach: CGFloat = 40

    /// An anchor over the Dock icon under the pointer, with the edge a popover should
    /// grow towards. Nil when the pointer is not on the Dock at all - the app was
    /// reopened from Finder or Spotlight - and the caller should open elsewhere.
    func dockIconUnderPointer() -> (view: NSView, edge: NSRectEdge)? {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(location, $0.frame) }),
              let (edge, rect) = dockStrip(at: location, on: screen) else {
            release()
            return nil
        }
        guard let view = park(rect) else { return nil }
        return (view, edge)
    }

    /// Takes the anchor away once the popover it held is gone.
    func release() {
        window?.orderOut(nil)
    }

    private func park(_ rect: NSRect) -> NSView? {
        let window = self.window ?? makeWindow()
        self.window = window
        window.setFrame(rect, display: false)
        window.orderFront(nil)
        return window.contentView
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 16, height: 16),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // Above the Dock, on every Space, and never in the way of a click: it marks a
        // place, it is not a surface.
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = NSView()
        return window
    }

    /// The slice of the Dock the pointer is over, and which way a popover opens from it.
    /// The Dock's own edge comes from what it takes out of the screen's visible frame; a
    /// hidden Dock takes nothing, so there the pointer's own distance to an edge answers.
    private func dockStrip(at location: NSPoint, on screen: NSScreen) -> (NSRectEdge, NSRect)? {
        let frame = screen.frame
        let visible = screen.visibleFrame
        let reach = Self.hiddenDockReach

        // A visible Dock: anchor across its whole depth, so the arrow lands on the icon
        // rather than on the pointer.
        if visible.minY - frame.minY > 1, location.y <= visible.minY {
            return (.maxY, NSRect(x: location.x - 8, y: frame.minY, width: 16, height: visible.minY - frame.minY))
        }
        if visible.minX - frame.minX > 1, location.x <= visible.minX {
            return (.maxX, NSRect(x: frame.minX, y: location.y - 8, width: visible.minX - frame.minX, height: 16))
        }
        if frame.maxX - visible.maxX > 1, location.x >= visible.maxX {
            return (.minX, NSRect(x: visible.maxX, y: location.y - 8, width: frame.maxX - visible.maxX, height: 16))
        }
        // A hidden Dock: on screen only while the pointer is at the edge.
        if location.y - frame.minY <= reach {
            return (.maxY, NSRect(x: location.x - 8, y: frame.minY, width: 16, height: max(1, location.y - frame.minY)))
        }
        if location.x - frame.minX <= reach {
            return (.maxX, NSRect(x: frame.minX, y: location.y - 8, width: max(1, location.x - frame.minX), height: 16))
        }
        if frame.maxX - location.x <= reach {
            return (.minX, NSRect(x: location.x, y: location.y - 8, width: max(1, frame.maxX - location.x), height: 16))
        }
        return nil
    }
}
