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
                let view = OverviewView(snapshot: .sample, agents: Agent.allCases)
                    .frame(width: 340)
                    .background(.background)
                    .preferredColorScheme(scheme)
                try Self.write(view, name: "popover-\(suffix).png", to: directory)
            }
        }
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("popover-light.png").path))
    }

    /// Renders through a real (offscreen) window so AppKit-backed controls draw like they do on screen.
    @MainActor
    private static func write(_ view: some View, name: String, to directory: URL, scale: CGFloat = 2) throws {
        let hosting = NSHostingView(rootView: view.environment(\.controlActiveState, .key))
        hosting.sizingOptions = [.intrinsicContentSize]
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
