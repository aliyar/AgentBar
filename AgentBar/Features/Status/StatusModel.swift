import Foundation
import Observation
import OSLog
import AgentBarKit

/// Owns what each agent's status page says, and the loop that keeps it current.
///
/// Deliberately not part of `AgentsModel`, which is about what the agents on this Mac are
/// doing. This asks three public pages on a cadence of its own: every five minutes, and
/// every minute while something is wrong, because the minute a service comes back is the
/// only moment this feature exists for. It keeps running with nothing on screen - a
/// recovery that is noticed only when the panel is next opened is not a recovery anyone
/// was told about.
@Observable
final class StatusModel {
    enum Reason { case timer, popoverOpened, manual, settingsChanged }

    private(set) var statuses: [Agent: ServiceStatus] = [:]
    /// Why the last read gave nothing, in words for the panel. The last good status stays
    /// on screen beside it: a page that cannot be reached is not a service that is down.
    private(set) var problems: [Agent: String] = [:]
    private(set) var isRefreshing = false

    /// The agents whose pages are read: the ones the panel shows.
    var agents: [Agent] = [] {
        didSet { if agents != oldValue { refresh(.settingsChanged) } }
    }
    /// Draw the sample readings instead of asking the pages: a way to see an outage, its
    /// component list and the menu bar mark without waiting for a real one. A development
    /// aid, as `AgentsModel.showsSampleData` is.
    var showsSampleData = false {
        didSet {
            guard showsSampleData != oldValue else { return }
            if showsSampleData {
                refreshTask?.cancel()
                refreshTask = nil
                isRefreshing = false
                statuses = ServiceStatus.sampleAll()
                problems = [:]
            } else {
                forget()
                refresh(.settingsChanged)
            }
            reschedule()
        }
    }

    /// The master switch. Turning it off empties the panel without a read.
    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled { refresh(.settingsChanged) } else { forget() }
            reschedule()
        }
    }

    /// Told about every settled change of state. Set by `AppDependencies`.
    var onTransition: ((Agent, StatusWatch.Transition, ServiceStatus) -> Void)?

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pendingReason: Reason?
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var attempts: [Agent: Date] = [:]
    /// The pages that answer a conditional request are asked with the tag they last gave.
    @ObservationIgnored private var etags: [Agent: String] = [:]
    @ObservationIgnored private var watches: [Agent: StatusWatch] = [:]

    func start() {
        if showsSampleData { statuses = ServiceStatus.sampleAll() }
        refresh(.manual)
        reschedule()
    }

    /// The worst thing any watched agent is reporting. What the menu bar mark and the
    /// panel's roll-up are drawn from.
    var worst: StatusLevel? {
        agents.compactMap { statuses[$0]?.level }.max()
    }

    /// The agents that are unwell right now, in their canonical order.
    var failing: [Agent] {
        agents.filter { statuses[$0]?.level.isIssue == true }
    }

    func refresh(_ reason: Reason = .timer) {
        guard isEnabled, !showsSampleData else { return }
        guard refreshTask == nil else {
            if reason == .manual || reason == .popoverOpened { pendingReason = reason }
            return
        }
        let now = Date()
        let due = agents.filter { isDue($0, reason: reason, now: now) }
        guard !due.isEmpty else { return }
        for agent in due { attempts[agent] = now }
        isRefreshing = true
        let tags = etags
        refreshTask = Task {
            var answers: [Agent: StatusReader.Answer] = [:]
            await withTaskGroup(of: (Agent, StatusReader.Answer).self) { group in
                for agent in due {
                    group.addTask { (agent, await StatusReader.fetch(agent, etag: tags[agent], now: now)) }
                }
                for await (agent, answer) in group { answers[agent] = answer }
            }
            for (agent, answer) in answers { take(answer, for: agent) }
            isRefreshing = false
            refreshTask = nil
            // A page that turned unwell is asked again sooner than one that is fine.
            reschedule()
            if let next = pendingReason {
                pendingReason = nil
                refresh(next)
            }
        }
    }

    /// Folds one answer in, and announces the change if this reading settled one.
    private func take(_ answer: StatusReader.Answer, for agent: Agent) {
        switch answer {
        case .read(let status, let etag):
            statuses[agent] = status
            problems[agent] = nil
            if let etag { etags[agent] = etag } else { etags[agent] = nil }
            Log.app.debug("\(agent.rawValue, privacy: .public) status: \(status.level.rawValue, privacy: .public), \(status.components.count) components")
            if status.isFallback {
                // The page renamed a component we watch. The reading still stands - the
                // page's own indicator answered - but the mapping wants revisiting.
                Log.app.notice("\(agent.rawValue, privacy: .public) status: no watched component found")
            }
            announce(status.level, for: agent, status: status)
        case .unchanged:
            // The page says nothing has changed since the tag we hold. What we have is
            // current, so it counts as a reading of the same level.
            if var status = statuses[agent] {
                status.checkedAt = Date()
                statuses[agent] = status
                problems[agent] = nil
                announce(status.level, for: agent, status: status)
            }
        case .failed(let problem):
            // The last good status stays; only the note changes. A page that could not be
            // reached is not a service that is down, and the watch is told exactly that.
            problems[agent] = problem.description
            announce(nil, for: agent, status: statuses[agent])
            Log.app.notice("\(agent.rawValue, privacy: .public) status: \(problem.description, privacy: .public)")
        }
    }

    private func announce(_ level: StatusLevel?, for agent: Agent, status: ServiceStatus?) {
        var watch = watches[agent] ?? StatusWatch()
        let transition = watch.record(level)
        watches[agent] = watch
        guard let transition, let status else { return }
        onTransition?(agent, transition, status)
    }

    /// Everything is forgotten, including the latches: turning the feature back on starts
    /// over rather than announcing a change across the gap it was off for.
    private func forget() {
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshing = false
        statuses = [:]
        problems = [:]
        etags = [:]
        watches = [:]
        attempts = [:]
    }

    private func isDue(_ agent: Agent, reason: Reason, now: Date) -> Bool {
        let since = attempts[agent].map { now.timeIntervalSince($0) } ?? .infinity
        switch reason {
        case .manual: return since >= 10
        case .popoverOpened, .settingsChanged: return since >= 60
        case .timer: return since >= interval - 5
        }
    }

    /// Five minutes normally; one minute while an agent is unwell, so the moment it comes
    /// back is a minute away rather than five. The pages cost a few hundred bytes and
    /// their public API is not rate limited, so the faster cadence is free.
    private var interval: TimeInterval { failing.isEmpty ? 300 : 60 }

    private func reschedule() {
        loopTask?.cancel()
        loopTask = nil
        guard isEnabled, !showsSampleData else { return }
        let interval = interval
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                refresh(.timer)
            }
        }
    }
}
