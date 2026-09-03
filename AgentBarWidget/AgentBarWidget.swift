import AppIntents
import OSLog
import SwiftUI
import WidgetKit
import AgentBarKit

/// The widget only decodes the snapshot the app wrote into the App Group; it reads no
/// agent's folder and asks no account. It opens nothing when tapped; a conversation in the
/// large widget brings the terminal or editor it runs in forward.
@main
struct AgentBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageWidget: Widget {
    static let kind = "com.greatpixels.AgentBar.usage"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: ConfigureAgentBarWidget.self, provider: SnapshotProvider()) { entry in
            WidgetRoot(entry: entry)
        }
        .configurationDisplayName("AgentBar")
        .description("How much of each coding agent's quota is used, when it starts over, and what is running right now.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    /// nil follows macOS.
    let scheme: ColorScheme?
    /// macOS's appearance when the entry was made. The view's own `colorScheme` cannot be
    /// trusted for this: the extension renders with its own, not the desktop's.
    let systemIsDark: Bool
    /// What to show, as the configuration put it; `Selection.all` before any choice.
    let selection: Selection

    struct Selection {
        /// The windows, by `UsageLimit.id`; empty for every window.
        var windowIDs: Set<String> = []
        /// Large: the running conversations under the windows.
        var showsActive = true

        static let all = Selection()

        init(windowIDs: Set<String> = [], showsActive: Bool = true) {
            self.windowIDs = windowIDs
            self.showsActive = showsActive
        }

        init(_ configuration: ConfigureAgentBarWidget) {
            self.init(windowIDs: Set((configuration.windows ?? []).map(\.id)), showsActive: configuration.showsActive)
        }

        func keeps(_ limit: UsageLimit) -> Bool { windowIDs.isEmpty || windowIDs.contains(limit.id) }
    }

    init(date: Date, snapshot: Snapshot?, scheme: ColorScheme? = nil, selection: Selection = .all) {
        self.date = date
        self.snapshot = snapshot
        self.scheme = scheme
        self.systemIsDark = SystemAppearance.isDark
        self.selection = selection
    }
}

/// macOS's appearance, from the global preference the Appearance setting writes. The app
/// reloads the timelines when it changes, so an entry never outlives the answer.
enum SystemAppearance {
    static var isDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle")?.lowercased() == "dark"
    }
}

/// Reads the shared file. The app reloads the widget whenever it writes; a fresh entry
/// every 15 minutes keeps the "as of" note and the countdowns honest in between.
typealias Selection = SnapshotEntry.Selection

struct SnapshotProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func snapshot(for configuration: ConfigureAgentBarWidget, in context: Context) async -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: context.isPreview ? .sample : SnapshotStore()?.read(),
                      scheme: configuration.theme.colorScheme, selection: Selection(configuration))
    }

    func timeline(for configuration: ConfigureAgentBarWidget, in context: Context) async -> Timeline<SnapshotEntry> {
        let snapshot = SnapshotStore()?.read()
        let scheme = configuration.theme.colorScheme
        // One line per timeline, so `/usr/bin/log show --predicate 'subsystem == "com.greatpixels.AgentBar.Widget"'`
        // says what each widget was asked to draw.
        Logger(subsystem: "com.greatpixels.AgentBar.Widget", category: "timeline")
            .notice("\(String(describing: context.family), privacy: .public): theme=\(configuration.theme.rawValue, privacy: .public) windows=\(configuration.windows?.count ?? 0, privacy: .public) active=\(configuration.showsActive, privacy: .public) snapshot=\(snapshot == nil ? "none" : "read", privacy: .public)")
        let selection = Selection(configuration)
        let entries = (0..<4).map { step in
            SnapshotEntry(date: Date().addingTimeInterval(Double(step) * 15 * 60), snapshot: snapshot, scheme: scheme, selection: selection)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

/// The theme applied, then the family's view on the widget's own ground: near-white or
/// near-black, a little translucent so the desktop shows faintly through, with a soft
/// light from the top. (The desktop's own glass, the Battery widget's, is not on offer to
/// a third-party widget on this macOS: whatever is painted here replaces it, and nothing
/// painted here leaves it.)
private struct WidgetRoot: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let scheme = entry.scheme ?? (entry.systemIsDark ? .dark : .light)
        UsageWidgetView(entry: entry, family: family)
            .containerBackground(for: .widget) { WidgetPalette.ground(scheme) }
            .environment(\.colorScheme, scheme)
    }
}
