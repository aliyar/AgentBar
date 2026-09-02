import Foundation
import Observation
import AgentBarKit

/// The handful of settings v1 has, backed by UserDefaults. Nothing is added here for a
/// feature that "might want" it.
@Observable
final class AppSettings {
    private enum Keys {
        static let gauge = "gaugeEnabled"
        static let agents = "enabledAgents"
    }

    private let defaults: UserDefaults

    /// Show the fullest live window as a percentage in the menu bar instead of the symbol.
    var gaugeEnabled: Bool {
        didSet { defaults.set(gaugeEnabled, forKey: Keys.gauge) }
    }

    /// The agents the popover and the gauge take into account.
    var enabledAgents: Set<Agent> {
        didSet { defaults.set(enabledAgents.map(\.rawValue).sorted(), forKey: Keys.agents) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        gaugeEnabled = defaults.object(forKey: Keys.gauge) as? Bool ?? true
        let stored = defaults.stringArray(forKey: Keys.agents)
        enabledAgents = Set((stored ?? Agent.allCases.map(\.rawValue)).compactMap(Agent.init(rawValue:)))
    }

    /// Enabled agents in their canonical order.
    var agents: [Agent] { Agent.allCases.filter { enabledAgents.contains($0) } }

    func isEnabled(_ agent: Agent) -> Bool { enabledAgents.contains(agent) }

    func setEnabled(_ agent: Agent, _ enabled: Bool) {
        if enabled { enabledAgents.insert(agent) } else { enabledAgents.remove(agent) }
    }
}
