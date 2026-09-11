import Foundation
import Testing
@testable import AgentBarKit

/// When a window's use is announced: once per mark and window, and again only in a new one.
@Suite("UsageWatch")
struct UsageWatchTests {
    private let now = Date(timeIntervalSince1970: 1_788_400_000)
    private let week: TimeInterval = 7 * 86400

    private func weekly(_ percent: Double, endsIn: TimeInterval = 3 * 86400, from start: Date? = nil) -> UsageLimit {
        UsageLimit(agent: .claude, title: "Weekly · all models", percentUsed: percent,
                   resetsAt: (start ?? now).addingTimeInterval(endsIn), windowLength: week)
    }

    private var watching: Set<String> { [weekly(0).id] }

    @Test func eachMarkIsAnnouncedOnceAsTheWindowFills() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(79)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
        #expect(watch.observe([weekly(81)], watching: watching, thresholds: [80, 90], now: now).map(\.threshold) == [80])
        // Read again, a little fuller: nothing new to say.
        #expect(watch.observe([weekly(84)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
        #expect(watch.observe([weekly(90)], watching: watching, thresholds: [80, 90], now: now).map(\.threshold) == [90])
        #expect(watch.observe([weekly(97)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
    }

    /// A late read that jumps past two marks says the higher one, once.
    @Test func aJumpPastSeveralMarksSaysTheHighest() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(93)], watching: watching, thresholds: [80, 90], now: now).map(\.threshold) == [90])
        #expect(watch.observe([weekly(95)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
    }

    @Test func onlyTheWindowsChosenAreWatched() {
        var watch = UsageWatch()
        let session = UsageLimit(agent: .claude, title: "5h", percentUsed: 95,
                                 resetsAt: now.addingTimeInterval(3600), windowLength: 5 * 3600)
        let alerts = watch.observe([session, weekly(85)], watching: watching, thresholds: [80, 90], now: now)
        #expect(alerts.map(\.limit.id) == [weekly(0).id])
    }

    /// A new week starts from nothing, and announces its marks again.
    @Test func aWindowThatStartsOverIsWatchedAfresh() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(92)], watching: watching, thresholds: [80, 90], now: now).count == 1)
        let later = now.addingTimeInterval(4 * 86400)
        let next = weekly(12, endsIn: week - 86400, from: later)
        #expect(watch.observe([next], watching: watching, thresholds: [80, 90], now: later).isEmpty)
        let fuller = weekly(83, endsIn: week - 2 * 86400, from: later)
        #expect(watch.observe([fuller], watching: watching, thresholds: [80, 90], now: later).map(\.threshold) == [80])
    }

    /// Read only after its week has ended, a window's figure is history: nothing is said,
    /// and the next week is watched from the start.
    @Test func aRolledOverFigureRaisesNothing() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(85)], watching: watching, thresholds: [80], now: now).count == 1)
        let later = now.addingTimeInterval(4 * 86400)
        #expect(watch.observe([weekly(96)], watching: watching, thresholds: [80, 90], now: later).isEmpty)
        let fresh = weekly(81, endsIn: 6 * 86400, from: later)
        #expect(watch.observe([fresh], watching: watching, thresholds: [80, 90], now: later).map(\.threshold) == [80])
    }

    /// The same window restated a few minutes apart is still the same window.
    @Test func aResetDateThatJittersIsTheSameWindow() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(81)], watching: watching, thresholds: [80, 90], now: now).count == 1)
        #expect(watch.observe([weekly(82, endsIn: 3 * 86400 + 120)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
    }

    /// A limit with no reset date (extra usage) starts over when its use falls well below
    /// the mark; a point's difference between two sources does not count.
    @Test func aLimitWithoutAResetDateStartsOverWhenItsUseFalls() {
        var watch = UsageWatch()
        let extra = { (percent: Double) in UsageLimit(agent: .claude, title: "Extra usage", percentUsed: percent, resetsAt: nil) }
        let ids: Set<String> = [extra(0).id]
        #expect(watch.observe([extra(82)], watching: ids, thresholds: [80], now: now).count == 1)
        #expect(watch.observe([extra(79)], watching: ids, thresholds: [80], now: now).isEmpty)
        #expect(watch.observe([extra(81)], watching: ids, thresholds: [80], now: now).isEmpty)
        #expect(watch.observe([extra(3)], watching: ids, thresholds: [80], now: now).isEmpty)
        #expect(watch.observe([extra(80)], watching: ids, thresholds: [80], now: now).count == 1)
    }

    /// Turned off and on again, a window says where it stands.
    @Test func aWindowTurnedBackOnAnnouncesAgain() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(85)], watching: watching, thresholds: [80], now: now).count == 1)
        #expect(watch.observe([weekly(85)], watching: [], thresholds: [80], now: now).isEmpty)
        #expect(watch.observe([weekly(85)], watching: watching, thresholds: [80], now: now).count == 1)
    }

    /// Kept across launches: a restart at 85% has nothing new to say.
    @Test func whatWasAnnouncedSurvivesARestart() throws {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(85)], watching: watching, thresholds: [80, 90], now: now).count == 1)
        var restored = try JSONDecoder().decode(UsageWatch.self, from: JSONEncoder().encode(watch))
        #expect(restored.observe([weekly(86)], watching: watching, thresholds: [80, 90], now: now).isEmpty)
    }

    /// A mark added below where a window stands says nothing more; one added above it is
    /// announced when reached.
    @Test func changingTheMarksMidWindow() {
        var watch = UsageWatch()
        #expect(watch.observe([weekly(86)], watching: watching, thresholds: [80], now: now).count == 1)
        #expect(watch.observe([weekly(86)], watching: watching, thresholds: [50, 80], now: now).isEmpty)
        #expect(watch.observe([weekly(86)], watching: watching, thresholds: [80, 85], now: now).map(\.threshold) == [85])
    }
}
