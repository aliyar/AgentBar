import Foundation
import Observation
import OSLog
import AgentBarKit

/// Owns the snapshot the surfaces draw and the loop that keeps it current.
///
/// Cadence, from the prototype: every 60 s while the gauge is showing, every 30 s while
/// the popover is on screen, and on every popover open. Reading is off the main actor.
@Observable
final class AgentsModel {
    private(set) var snapshot = Snapshot()
    private(set) var isRefreshing = false

    /// The agents to read. Changing it reads again straight away.
    var agents: [Agent] = Agent.allCases {
        didSet { if agents != oldValue { refresh() } }
    }
    var isPopoverVisible = false {
        didSet { if isPopoverVisible != oldValue { reschedule() } }
    }
    var gaugeEnabled = true {
        didSet { if gaugeEnabled != oldValue { reschedule() } }
    }

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var loopTask: Task<Void, Never>?

    func start() {
        refresh()
        reschedule()
    }

    /// Re-reads every enabled agent. Coalesced: a popover opening while one is in flight
    /// does not start a second.
    func refresh() {
        guard refreshTask == nil else { return }
        isRefreshing = true
        let agents = agents
        refreshTask = Task {
            let read = await Task.detached(priority: .utility) {
                SnapshotReader.read(agents: agents)
            }.value
            snapshot = read
            isRefreshing = false
            refreshTask = nil
            Log.app.debug("read \(read.limits.count) limits, \(read.conversations.count) conversations")
        }
    }

    private var interval: Duration? {
        if isPopoverVisible { return .seconds(30) }
        if gaugeEnabled { return .seconds(60) }
        return nil
    }

    private func reschedule() {
        loopTask?.cancel()
        loopTask = nil
        guard let interval else { return }
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                refresh()
            }
        }
    }
}
