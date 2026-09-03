import Foundation
import Testing
@testable import AgentBarKit

@Suite("Format")
struct FormatTests {
    @Test func tokensAreCompact() {
        #expect(Format.compact(950) == "950")
        #expect(Format.compact(44_200) == "44K")
        #expect(Format.compact(1_234_000) == "1.2M")
    }

    @Test func durationsAreShort() {
        #expect(Format.short(0) == "1m")
        #expect(Format.short(40 * 60) == "40m")
        #expect(Format.short(2 * 3600 + 5 * 60) == "2h 5m")
        #expect(Format.short(4 * 3600 + 5 * 60) == "4h 5m")
        #expect(Format.short(4 * 3600 + 5 * 60, coarse: true) == "4h")
        #expect(Format.short(4 * 3600) == "4h")
        #expect(Format.short(2 * 86400 + 3 * 3600) == "2d 3h")
        #expect(Format.short(2 * 86400 + 3 * 3600, coarse: true) == "2d")
        #expect(Format.short(-100) == "1m")
    }

    @Test func clocksNameTheDayOnlyWhileItIsUnambiguous() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 9, minute: 44))!
        #expect(Format.clock(now.addingTimeInterval(4 * 3600), now: now, calendar: calendar).hasSuffix(":44"))
        #expect(!Format.clock(now.addingTimeInterval(4 * 3600), now: now, calendar: calendar).contains(" "))
        // Two days on: a weekday and the time.
        #expect(Format.clock(now.addingTimeInterval(2 * 86400), now: now, calendar: calendar).contains(" "))
        #expect(!Format.clock(now.addingTimeInterval(2 * 86400), now: now, calendar: calendar).contains("Sep"))
        // Nine days on: the date, no weekday, no time.
        let far = Format.clock(now.addingTimeInterval(9 * 86400), now: now, calendar: calendar)
        #expect(far.contains("12") && !far.contains(":"))
    }

    @Test func percentsAreWhole() {
        #expect(Format.percent(77.6) == "78%")
        #expect(Format.percent(0.2) == "0%")
    }
}
