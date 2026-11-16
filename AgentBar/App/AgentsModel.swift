import Foundation
import Observation
import OSLog
import WidgetKit
import AgentBarKit

/// Owns the snapshot the surfaces draw and the loops that keep it current.
///
/// Two sources, merged: what the agents left on disk (read every 30 s while the popover
/// is open, every 60 s while the gauge shows, and on every popover open), and what their
/// accounts report, asked as seldom as `AccountSchedule` allows: every 10 minutes while
/// the agent works, hourly while it does not, never into a refusal. For an agent that
/// answered, the account's numbers replace the file's unless the file was written later -
/// Codex just ran, say. The last answers and the schedule outlive a relaunch.
@Observable
final class AgentsModel {
    enum Reason { case timer, popoverOpened, manual, settingsChanged }

    private(set) var snapshot = Snapshot()
    /// The snapshot is the made-up one: nothing in it is anyone's usage, so nothing in it
    /// is announced. Set with the snapshot, since the setting changes before the read does.
    private(set) var isShowingSample = false
    private(set) var isRefreshing = false

    /// The agents to read. Changing it reads again straight away.
    var agents: [Agent] = Agent.allCases {
        didSet { if agents != oldValue { refresh(.settingsChanged) } }
    }
    /// The agents whose accounts are asked.
    var liveAgents: Set<Agent> = [] {
        didSet { if liveAgents != oldValue { refresh(.settingsChanged) } }
    }
    var isPopoverVisible = false {
        didSet { if isPopoverVisible != oldValue { reschedule() } }
    }
    var gaugeEnabled = true {
        didSet { if gaugeEnabled != oldValue { reschedule() } }
    }
    /// Sample data instead of a read; the loop keeps running so the sample's clock ticks.
    var showsSampleData = false {
        didSet { if showsSampleData != oldValue { refresh(.settingsChanged) } }
    }

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pendingReason: Reason?
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private let accountStore = AccountStore()
    /// The last numbers each account gave, why the last ask failed, and when to ask
    /// again - kept between reads so a file read in between does not push them out, and
    /// between launches so a relaunch neither shows nothing nor asks into a refusal.
    @ObservationIgnored private lazy var records: [Agent: AccountRecord] = accountStore?.read() ?? [:]
    @ObservationIgnored private var loggedResets: Set<Agent> = []

    func start() {
        // A launch is not a press of the refresh button: the accounts are asked only when
        // their schedule says so, which the records carried over from the last run decide.
        refresh(.timer)
        reschedule()
        // The widget bakes macOS's appearance into its entries (its own views cannot see
        // the desktop's); a change here redraws them with the right one.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Re-reads every enabled agent, and asks the accounts that are due. Coalesced: a
    /// popover opening while one is in flight does not start a second, but its reason is
    /// kept so the accounts are asked right after.
    func refresh(_ reason: Reason = .timer) {
        guard refreshTask == nil else {
            if reason == .manual || reason == .popoverOpened { pendingReason = reason }
            return
        }
        isRefreshing = true
        let agents = agents
        let sample = showsSampleData
        let now = Date()
        let trigger: AccountSchedule.Trigger = reason == .manual ? .manual : .timer
        let due = sample ? [] : agents.filter { agent in
            guard liveAgents.contains(agent) else { return false }
            let record = records[agent] ?? AccountRecord()
            return record.schedule.isDue(trigger, now: now, answeredAt: record.answeredAt,
                                         lastActivity: snapshot.latestActivity(for: agent))
        }
        for agent in due { records[agent, default: AccountRecord()].schedule.recordAttempt(at: now) }
        refreshTask = Task {
            async let files = Task.detached(priority: .utility) {
                SnapshotReader.read(agents: agents, now: now)
            }.value
            var results: [Agent: Result<Reading, AccountUsage.Problem>] = [:]
            await withTaskGroup(of: (Agent, Result<Reading, AccountUsage.Problem>).self) { group in
                for agent in due {
                    group.addTask { (agent, await AccountUsage.fetch(agent, now: now)) }
                }
                for await (agent, result) in group { results[agent] = result }
            }
            let read = await files
            for (agent, result) in results {
                var record = records[agent] ?? AccountRecord()
                switch result {
                case .success(var reading):
                    // The reset credits are asked beside the usage and may miss while it
                    // answers; the last list stands until the next one comes.
                    if reading.resetCredits == nil { reading.resetCredits = record.answer?.resetCredits }
                    // Said when the inventory changes, and once per run whatever it is, so
                    // an account that never sends one can be told from one that has none.
                    if loggedResets.insert(agent).inserted || reading.resetCredits != record.answer?.resetCredits {
                        Log.app.notice("""
                            \(agent.rawValue, privacy: .public) account: \
                            \(reading.resetCredits.map { "\($0.available(at: now).count)" } ?? "no", privacy: .public) limit resets
                            """)
                    }
                    record.answer = reading
                    record.answeredAt = now
                    record.problem = nil
                    record.schedule.recordSuccess()
                    Log.app.debug("\(agent.rawValue, privacy: .public) account: \(reading.limits.count) windows")
                case .failure(let problem):
                    record.problem = problem.description
                    if case .rateLimited(let retryAfter) = problem {
                        record.schedule.recordRefusal(retryAfter: retryAfter, now: now)
                        // Logged with what the server said, so the limit nobody publishes
                        // can at least be measured.
                        Log.app.notice("""
                            \(agent.rawValue, privacy: .public) account: 429, Retry-After \
                            \(retryAfter.map { "\(Int($0.timeIntervalSince(now)))s" } ?? "none", privacy: .public), \
                            refusal \(record.schedule.refusals), next ask after \
                            \(record.schedule.blockedUntil?.formatted(date: .omitted, time: .standard) ?? "-", privacy: .public)
                            """)
                    } else {
                        Log.app.notice("\(agent.rawValue, privacy: .public) account: \(problem.description, privacy: .public)")
                    }
                }
                records[agent] = record
            }
            if !due.isEmpty { saveRecords() }
            snapshot = sample ? Snapshot.sample : merged(read, now: now)
            isShowingSample = sample
            // A read of the files alone takes milliseconds; the panels show a read in
            // progress, so a manual one stays visible long enough to register.
            if reason == .manual {
                let elapsed = Date().timeIntervalSince(now)
                if elapsed < 0.7 { try? await Task.sleep(for: .seconds(0.7 - elapsed)) }
            }
            isRefreshing = false
            refreshTask = nil
            publishToWidget(snapshot)
            Log.app.debug("read \(read.limits.count) limits, \(read.conversations.count) conversations; asked \(due.count) accounts")
            if let next = pendingReason {
                pendingReason = nil
                refresh(next)
            }
        }
    }

    /// The widget cannot read the agents' folders (app extensions are sandboxed), so every
    /// snapshot is written into the App Group for it, and its timelines reloaded.
    private func publishToWidget(_ snapshot: Snapshot) {
        guard let store = SnapshotStore() else {
            Log.app.error("no App Group container: the widget will stay empty")
            return
        }
        do {
            try store.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            Log.app.error("snapshot not written for the widget: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveRecords() {
        do {
            try accountStore?.write(records)
        } catch {
            Log.app.error("account records not written: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The file read with each account's answer laid over it.
    private func merged(_ read: Snapshot, now: Date) -> Snapshot {
        var snapshot = read
        for agent in agents {
            let record = records[agent]
            var status = AccountStatus(fetchedAt: record?.answeredAt, problem: record?.problem)
            if liveAgents.contains(agent), let answer = record?.answer, let answeredAt = record?.answeredAt {
                // The plan is not a reading and does not go stale the way a window does,
                // so it is taken from whichever source named it - Cursor and Claude name
                // it only in their account answer, and have no file to lose it to.
                if !answer.identity.isEmpty {
                    snapshot.identities[agent] = (snapshot.identities[agent] ?? Identity())
                        .merged(with: answer.identity)
                }
                // Like the plan, an inventory rather than a reading: only the account has
                // it, and a file written later says nothing about it.
                if let resets = answer.resetCredits { snapshot.resetCredits[agent] = resets }
                let fileIsNewer = (read.lastWritten[agent] ?? .distantPast) > answeredAt
                if !fileIsNewer {
                    snapshot.limits.removeAll { $0.agent == agent }
                    snapshot.limits += answer.limits
                    // The account knows the balance the files cannot: what was bought or
                    // spent elsewhere. Its answer replaces the file's, never the reverse.
                    snapshot.credits[agent] = answer.credits
                    snapshot.lastWritten[agent] = answeredAt
                }
            } else if !liveAgents.contains(agent) {
                status = AccountStatus()
            }
            snapshot.accounts[agent] = status
        }
        // Agents first, in the order the user put them; the file read may have produced
        // another. The menu bar's bars and the widget draw this list, so sorting it here
        // is what makes one order serve all three surfaces.
        let position = Dictionary(uniqueKeysWithValues: agents.enumerated().map { ($1, $0) })
        snapshot.limits.sort { (position[$0.agent] ?? .max) < (position[$1.agent] ?? .max) }
        return snapshot
    }

    private var interval: Duration? {
        if isPopoverVisible { return .seconds(30) }
        if gaugeEnabled { return .seconds(60) }
        // Nothing on screen: still ask the accounts every 5 minutes, for the gauge's return
        // and the widget's snapshot.
        return .seconds(300)
    }

    private func reschedule() {
        loopTask?.cancel()
        loopTask = nil
        guard let interval else { return }
        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                refresh(.timer)
            }
        }
    }
}
