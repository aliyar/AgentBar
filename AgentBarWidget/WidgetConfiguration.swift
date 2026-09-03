import AppIntents
import SwiftUI
import WidgetKit
import AgentBarKit

/// What the widget's right-click › Edit "AgentBar" offers. The widget has one design of
/// its own - it is not the panel shrunk - so there is no style to pick; what it shows is:
/// any set of windows (none chosen: every window), and for the large size whether the
/// running conversations are listed. `parameterSummary` shows each size its own settings.
struct ConfigureAgentBarWidget: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "AgentBar"
    static let description = IntentDescription("What the widget shows, and how it is drawn.")

    @Parameter(title: "Theme", default: .system)
    var theme: WidgetThemeOption

    /// The windows to show; none chosen means every window. The small size shows one as a
    /// card, up to three as blocks, more as one block per agent.
    @Parameter(title: "Windows")
    var windows: [WindowEntity]?

    /// Large: the conversations running right now, under the windows.
    @Parameter(title: "Show active conversations", default: true)
    var showsActive: Bool

    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .systemLarge) {
            Summary("Show \(\.$windows)") {
                \.$showsActive
                \.$theme
            }
        } otherwise: {
            Summary("Show \(\.$windows)") {
                \.$theme
            }
        }
    }
}

enum WidgetThemeOption: String, AppEnum {
    case system, dark, light

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Theme")
    static let caseDisplayRepresentations: [WidgetThemeOption: DisplayRepresentation] = [
        .system: "System",
        .dark: "Dark",
        .light: "Light",
    ]

    /// nil follows macOS.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

/// A rate-limit window as the widget's configuration lists it: "Claude · Weekly · Fable".
/// The choices come from the last snapshot the app wrote, so they are the windows this Mac
/// actually has; the id is `UsageLimit.id`, which survives the snapshot being rewritten.
struct WindowEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Window")
    static let defaultQuery = WindowQuery()

    let id: String
    let agent: Agent
    let title: String

    init(_ limit: UsageLimit) {
        id = limit.id
        agent = limit.agent
        title = limit.title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(agent.title) · \(title)")
    }
}

struct WindowQuery: EntityQuery {
    /// The snapshot's windows, or the sample's before the app has written one.
    private func known() -> [WindowEntity] {
        let snapshot = SnapshotStore()?.read() ?? .sample
        return snapshot.limits.map(WindowEntity.init)
    }

    func entities(for identifiers: [String]) async throws -> [WindowEntity] {
        known().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WindowEntity] {
        known()
    }
}
