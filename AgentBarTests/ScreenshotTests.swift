import AppKit
import SwiftUI
import Testing
import AgentBarKit
@testable import AgentBar

/// Renders the README screenshots from the real SwiftUI views. `screencapture` is not available
/// to an agent, so the views are hosted in an offscreen window and captured at 2x instead.
/// Runs only when `make screenshots` points at an output directory (env var or marker file).
@Suite("Screenshots")
struct ScreenshotTests {
    nonisolated static let outputDirectory: URL? = {
        if let env = ProcessInfo.processInfo.environment["AGENTBAR_SCREENSHOT_DIR"] {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // xcodebuild does not forward environment variables to hosted tests; the Makefile writes a marker.
        let marker = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/screenshot-dir")
        guard let path = try? String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }()

    @Test(.enabled(if: outputDirectory != nil))
    func renderReadmeScreenshots() async throws {
        let directory = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try await MainActor.run {
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                // On a soft gradient, as the design page shows it: the glass has to sit on something.
                let backdrop = scheme == .dark
                    ? [Color(red: 0.16, green: 0.20, blue: 0.42), Color(red: 0.45, green: 0.22, blue: 0.40), Color(red: 0.75, green: 0.42, blue: 0.30)]
                    : [Color(red: 0.72, green: 0.85, blue: 0.95), Color(red: 0.96, green: 0.92, blue: 0.82), Color(red: 0.95, green: 0.72, blue: 0.75)]
                for style in PanelStyleID.allCases {
                    // The sample readings put one agent in an outage, so a caption saying
                    // a service is unwell is in the picture as well as two saying it is not.
                    let context = OverviewContext(snapshot: .sample, agents: Agent.allCases,
                                                  statuses: ServiceStatus.sampleAll())
                    let view = OverviewView(style: style, context: context)
                        .frame(width: PanelStyles.style(style).width)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .padding(28)
                        .background(LinearGradient(colors: backdrop, startPoint: .topLeading, endPoint: .bottomTrailing))
                        // Both: the window appearance follows `preferredColorScheme` a beat later
                        // than the render, and the environment value is what the views read.
                        .environment(\.colorScheme, scheme)
                        .preferredColorScheme(scheme)
                    let name = style == .glass ? "popover-\(suffix).png" : "popover-\(style.rawValue)-\(suffix).png"
                    try Self.write(view, name: name, to: directory)
                }
            }
        }
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("popover-light.png").path))
    }

    /// The status screen, on the agent the sample keeps unwell: the roll-up, the components with
    /// the watched ones marked, and the incident line.
    @Test(.enabled(if: outputDirectory != nil))
    func renderStatusScreenshots() async throws {
        let directory = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try await MainActor.run {
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                let now = Date.now
                let view = StatusScreen(agent: .codex, status: .sample(for: .codex, now: now), problem: nil, now: now)
                    // The panel's own padding, as GlassOverview gives it: a pushed screen
                    // starts below the title bar, not against it.
                    .padding(11)
                    .padding(.top, 6)
                    .frame(width: PanelStyles.style(.glass).width)
                    .background(GlassBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(28)
                    .background(Self.backdrop(scheme))
                    .environment(\.colorScheme, scheme)
                    .preferredColorScheme(scheme)
                try Self.write(view, name: "status-\(suffix).png", to: directory)
            }
        }
    }

    /// The two messages the app posts, drawn as macOS shows them. The app hands its text to
    /// Notification Center rather than drawing a banner itself, so this is a picture of the
    /// system's window carrying exactly the words `Notifier` sends.
    @Test(.enabled(if: outputDirectory != nil))
    func renderNotificationScreenshots() async throws {
        let directory = try #require(Self.outputDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try await MainActor.run {
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                let view = VStack(spacing: 12) {
                    NotificationBanner(title: "Codex is down", message: "Codex API: partial outage.", when: "16:04")
                    NotificationBanner(title: "Codex is back", message: "You can carry on.", when: "16:31")
                }
                .padding(28)
                .background(Self.backdrop(scheme))
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(scheme)
                try Self.write(view, name: "notifications-\(suffix).png", to: directory)
            }
        }
    }

    /// The soft gradient the panel is shown on, as the design page shows it: the glass has to
    /// sit on something.
    private static func backdrop(_ scheme: ColorScheme) -> LinearGradient {
        let colours = scheme == .dark
            ? [Color(red: 0.16, green: 0.20, blue: 0.42), Color(red: 0.45, green: 0.22, blue: 0.40), Color(red: 0.75, green: 0.42, blue: 0.30)]
            : [Color(red: 0.72, green: 0.85, blue: 0.95), Color(red: 0.96, green: 0.92, blue: 0.82), Color(red: 0.95, green: 0.72, blue: 0.75)]
        return LinearGradient(colors: colours, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Renders through a real (offscreen) window so AppKit-backed controls draw like they do on screen.
    @MainActor
    private static func write(_ view: some View, name: String, to directory: URL, scale: CGFloat = 2) throws {
        let hosting = NSHostingView(rootView: view.environment(\.controlActiveState, .key))
        hosting.sizingOptions = [.intrinsicContentSize]
        // Window-shaped content (Settings, with its split view and toolbar) does not render this
        // way: NavigationSplitView draws nothing offscreen. Only plain views are captured here.
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: 200, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        for _ in 0..<2 {
            let size = hosting.fittingSize
            window.setContentSize(size)
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        rep.size = hosting.bounds.size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try data.write(to: directory.appendingPathComponent(name))
    }
}

/// A macOS notification, drawn for the README. The app posts its text through Notification
/// Center and draws no banner of its own, so this carries exactly the words `Notifier`
/// sends and nothing it does not.
private struct NotificationBanner: View {
    let title: String
    let message: String
    let when: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 12)
                    Text(when).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text(message).font(.system(size: 13)).foregroundStyle(.primary.opacity(0.9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 344, alignment: .leading)
        .background(scheme == .dark ? Color(white: 0.16) : Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.18), radius: 12, y: 6)
    }

    @ViewBuilder
    private var icon: some View {
        if let image = NSImage(named: "AppIcon") {
            Image(nsImage: image).resizable().frame(width: 38, height: 38)
        } else {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.accentColor)
                .frame(width: 38, height: 38)
        }
    }
}
