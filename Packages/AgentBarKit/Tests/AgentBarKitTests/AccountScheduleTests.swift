import Foundation
import Testing
@testable import AgentBarKit

/// How seldom the accounts are asked. Claude's usage endpoint refused this app for 17
/// hours on 16 Nov 2026: it was asked every 5 minutes, again every quarter of an hour into
/// the refusal, and on every relaunch.
@Suite("AccountSchedule")
struct AccountScheduleTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    @Test func nothingInHandIsAskedForStraightAway() {
        #expect(AccountSchedule().isDue(.timer, now: now, answeredAt: nil, lastActivity: nil))
        // A failure that was not a refusal (offline, signed out) is tried again after 5 min.
        let failed = AccountSchedule(lastAttempt: ago(2))
        #expect(!failed.isDue(.timer, now: now, answeredAt: nil, lastActivity: nil))
        #expect(AccountSchedule(lastAttempt: ago(5)).isDue(.timer, now: now, answeredAt: nil, lastActivity: nil))
    }

    @Test func anAgentAtWorkIsAskedEveryTenMinutes() {
        let schedule = AccountSchedule(lastAttempt: ago(9))
        #expect(!schedule.isDue(.timer, now: now, answeredAt: ago(9), lastActivity: ago(1)))
        let later = AccountSchedule(lastAttempt: ago(10))
        #expect(later.isDue(.timer, now: now, answeredAt: ago(10), lastActivity: ago(1)))
    }

    @Test func anAgentLeftAloneIsAskedHourly() {
        // Worked before the answer, not since: nothing on this Mac moved the numbers.
        let schedule = AccountSchedule(lastAttempt: ago(50))
        #expect(!schedule.isDue(.timer, now: now, answeredAt: ago(50), lastActivity: ago(55)))
        #expect(!schedule.isDue(.timer, now: now, answeredAt: ago(50), lastActivity: nil))
        let later = AccountSchedule(lastAttempt: ago(60))
        #expect(later.isDue(.timer, now: now, answeredAt: ago(60), lastActivity: nil))
    }

    @Test func theRefreshButtonAsksAtMostEveryTwoMinutes() {
        #expect(!AccountSchedule(lastAttempt: ago(1)).isDue(.manual, now: now, answeredAt: ago(1), lastActivity: nil))
        #expect(AccountSchedule(lastAttempt: ago(2)).isDue(.manual, now: now, answeredAt: ago(2), lastActivity: nil))
    }

    @Test func aRefusalStopsEveryAskForAsLongAsTheServerSays() {
        var schedule = AccountSchedule(lastAttempt: now)
        let retry = now.addingTimeInterval(40 * 60)
        schedule.recordRefusal(retryAfter: retry, now: now)
        #expect(schedule.blockedUntil == retry)
        let soon = now.addingTimeInterval(39 * 60)
        #expect(!schedule.isDue(.manual, now: soon, answeredAt: nil, lastActivity: soon))
        #expect(!schedule.isDue(.timer, now: soon, answeredAt: nil, lastActivity: soon))
        #expect(schedule.isDue(.timer, now: retry.addingTimeInterval(1), answeredAt: nil, lastActivity: nil))
    }

    @Test func withoutRetryAfterTheWaitDoublesUpToTwoHours() {
        var schedule = AccountSchedule()
        let waits = (0..<5).map { _ -> TimeInterval in
            schedule.recordRefusal(retryAfter: nil, now: now)
            return schedule.blockedUntil!.timeIntervalSince(now) / 60
        }
        #expect(waits == [15, 30, 60, 120, 120])
        // A Retry-After already past is no answer; the guess stands in.
        schedule.recordRefusal(retryAfter: ago(1), now: now)
        #expect(schedule.blockedUntil == now.addingTimeInterval(120 * 60))
        schedule.recordSuccess()
        #expect(schedule.refusals == 0)
        #expect(schedule.blockedUntil == nil)
        schedule.recordRefusal(retryAfter: nil, now: now)
        #expect(schedule.blockedUntil == now.addingTimeInterval(15 * 60))
    }

    @Test func retryAfterIsReadAsSecondsOrAnHTTPDate() {
        #expect(AccountUsage.retryAfter("120", now: now) == now.addingTimeInterval(120))
        #expect(AccountUsage.retryAfter(" 0 ", now: now) == now)
        #expect(AccountUsage.retryAfter("Wed, 21 Oct 2026 07:28:00 GMT", now: now)
                == Date(timeIntervalSince1970: 1_792_567_680))
        #expect(AccountUsage.retryAfter(nil, now: now) == nil)
        #expect(AccountUsage.retryAfter("", now: now) == nil)
        #expect(AccountUsage.retryAfter("-5", now: now) == nil)
        #expect(AccountUsage.retryAfter("soon", now: now) == nil)
        #expect(AccountUsage.Problem.rateLimited(retryAfter: nil).description == "asked too often")
    }

    @Test func theRecordsOutliveARelaunch() throws {
        let directory = try TemporaryDirectory()
        let store = AccountStore(directory: directory.url.appendingPathComponent("group"))
        #expect(store.read().isEmpty)
        let reading = Reading(limits: [UsageLimit(agent: .claude, title: "5h", percentUsed: 37,
                                                  resetsAt: now.addingTimeInterval(3600), windowLength: 5 * 3600)],
                              identity: Identity(plan: "Max 5x"))
        var schedule = AccountSchedule(lastAttempt: now)
        schedule.recordRefusal(retryAfter: nil, now: now)
        let records: [Agent: AccountRecord] = [
            .claude: AccountRecord(answer: reading, answeredAt: ago(30), problem: "asked too often", schedule: schedule)
        ]
        try store.write(records)
        #expect(store.read() == records)
        // A torn or foreign file costs one early ask, never a crash.
        try Data("{".utf8).write(to: store.url)
        #expect(store.read().isEmpty)
    }
}

@Suite("Snapshot staleness")
struct SnapshotStalenessTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func snapshot(written minutesAgo: Double, worked workedAgo: Double?) -> Snapshot {
        let conversations = workedAgo.map {
            [Conversation(agent: .claude, id: "s", name: "n", project: "p", isBusy: true, pid: 1,
                          lastActivity: now.addingTimeInterval(-$0 * 60))]
        } ?? []
        return Snapshot(conversations: conversations, lastWritten: [.claude: now.addingTimeInterval(-minutesAgo * 60)])
    }

    @Test func numbersAreStaleOnlyOnceOldAndWorkedPast() {
        #expect(snapshot(written: 20, worked: 1).isStale(.claude, at: now))
        // Fresh enough, however busy.
        #expect(!snapshot(written: 10, worked: 1).isStale(.claude, at: now))
        // Old, but nothing has moved them.
        #expect(!snapshot(written: 120, worked: 130).isStale(.claude, at: now))
        #expect(!snapshot(written: 120, worked: nil).isStale(.claude, at: now))
        #expect(!Snapshot().isStale(.claude, at: now))
    }
}
