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

    @Test func percentsAreWhole() {
        #expect(Format.percent(77.6) == "78%")
        #expect(Format.percent(0.2) == "0%")
    }
}
