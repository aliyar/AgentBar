import Foundation
import Testing
@testable import AgentBarKit

/// The rules that decide when a change of status is worth interrupting someone for. Each
/// test is one rule, and each rule exists because saying it at the wrong moment is worse
/// than not saying it at all.
@Suite("StatusWatch")
struct StatusWatchTests {
    /// Starting the app in the middle of an outage must not announce it: the user is
    /// already living through it, and the app has nothing to add.
    @Test func theFirstReadingSetsTheStateAndSaysNothing() {
        var watch = StatusWatch()
        #expect(!watch.hasRead)
        #expect(watch.record(.outage) == nil)
        #expect(watch.hasRead)
        #expect(watch.isFailing)
    }

    @Test func goingDownIsAnnouncedOnceTwoReadingsAgree() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(.partial) == nil)
        #expect(watch.record(.partial) == .wentDown(.partial))
        #expect(watch.isFailing)
        // And not again while it stays down.
        #expect(watch.record(.outage) == nil)
        #expect(watch.record(.outage) == nil)
    }

    @Test func comingBackIsAnnouncedOnceTwoReadingsAgree() {
        var watch = StatusWatch()
        watch.record(.outage)
        #expect(watch.record(.operational) == nil)
        #expect(watch.record(.operational) == .cameBack)
        #expect(!watch.isFailing)
        #expect(watch.record(.operational) == nil)
    }

    /// One bad reading between two good ones is a flake, not an outage.
    @Test func aSingleFlakeIsNotAnnounced() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(.outage) == nil)
        #expect(watch.record(.operational) == nil)
        #expect(!watch.isFailing)
        // And the flake did not count towards the next one either.
        #expect(watch.record(.outage) == nil)
        #expect(watch.record(.outage) == .wentDown(.outage))
    }

    /// The single most annoying false positive in this category: dropped Wi-Fi looks
    /// exactly like a dead service, and must never be reported as one.
    @Test func aPageThatCouldNotBeReadIsNotAnOutage() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(nil) == nil)
        #expect(watch.record(nil) == nil)
        #expect(!watch.isFailing)
    }

    /// A failure between two agreeing readings breaks the agreement: they were not
    /// consecutive, and the one before the gap may describe a different world.
    @Test func aFailedReadingBreaksAnAgreementInProgress() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(.outage) == nil)
        #expect(watch.record(nil) == nil)
        #expect(watch.record(.outage) == nil)
        #expect(watch.record(.outage) == .wentDown(.outage))
    }

    /// A planned window is not news, and "we could not tell" is not an outage. Neither
    /// moves the latch in either direction.
    @Test func maintenanceAndUnknownChangeNothing() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(.maintenance) == nil)
        #expect(watch.record(.maintenance) == nil)
        #expect(watch.record(.unknown) == nil)
        #expect(!watch.isFailing)

        var down = StatusWatch()
        down.record(.outage)
        #expect(down.record(.maintenance) == nil)
        #expect(down.record(.unknown) == nil)
        #expect(down.isFailing)
    }

    /// Two readings agree when both say the service is unwell - they need not name the
    /// same level. A page that slides from degraded to a full outage has said the same
    /// thing twice, and the level announced is the one that is true now, not the first one.
    @Test func twoUnwellReadingsAgreeEvenWhenTheyNameDifferentLevels() {
        var watch = StatusWatch()
        watch.record(.operational)
        #expect(watch.record(.degraded) == nil)
        #expect(watch.record(.outage) == .wentDown(.outage))
    }

    @Test func severityOrdersFromWorkingToGone() {
        #expect(StatusLevel.operational < .maintenance)
        #expect(StatusLevel.maintenance < .degraded)
        #expect(StatusLevel.degraded < .partial)
        #expect(StatusLevel.partial < .outage)
        #expect([StatusLevel.operational, .outage, .degraded].max() == .outage)
        #expect(StatusLevel.allCases.filter(\.isIssue) == [.degraded, .partial, .outage])
    }
}
