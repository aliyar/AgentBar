import Foundation
import Testing
import AgentBarKit
@testable import AgentBar

/// The order the panel's blocks come in, and which of them are drawn. The gesture that
/// changes it cannot be driven from a test, so the rule it applies is tested on its own:
/// what dropping one row onto another does to the list, and what happens to a list that
/// has gone stale between releases.
@Suite("AppSettings · section order")
@MainActor
struct AppSettingsTests {
    private func settings(_ stored: [String]? = nil) -> AppSettings {
        let defaults = UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)")!
        if let stored { defaults.set(stored, forKey: "sectionOrder") }
        return AppSettings(defaults: defaults)
    }

    /// A fresh install: every agent as declared, then what is running now.
    @Test func withNothingStoredTheOrderIsTheCanonicalOne() {
        #expect(settings().sectionOrder == [.agent(.claude), .agent(.codex), .agent(.cursor), .conversations])
    }

    /// Dropping a row onto another takes that row's place; the rest shuffle to make room.
    @Test func droppingOntoARowTakesItsPlace() {
        let settings = settings()
        settings.move(.agent(.claude), onto: .conversations)
        #expect(settings.sectionOrder == [.agent(.codex), .agent(.cursor), .conversations, .agent(.claude)])

        settings.move(.conversations, onto: .agent(.codex))
        #expect(settings.sectionOrder == [.conversations, .agent(.codex), .agent(.cursor), .agent(.claude)])
    }

    /// The conversations block moves and hides like any other: it is a thing the panel
    /// stacks, no more fixed than an agent's group.
    @Test func theConversationsBlockIsOrderedAndHiddenLikeAnyOther() {
        let settings = settings()
        settings.move(.conversations, onto: .agent(.claude))
        #expect(settings.sections.first == .conversations)
        settings.setShown(.conversations, false)
        #expect(!settings.sections.contains(.conversations))
        #expect(settings.sections == [.agent(.claude), .agent(.codex), .agent(.cursor)])
    }

    @Test func droppingARowOnItselfChangesNothing() {
        let settings = settings()
        settings.move(.agent(.codex), onto: .agent(.codex))
        #expect(settings.sectionOrder == PanelSection.all)
    }

    @Test func theOrderIsWrittenThroughAndReadBack() {
        let defaults = UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)")!
        let first = AppSettings(defaults: defaults)
        first.move(.agent(.cursor), onto: .agent(.claude))
        #expect(AppSettings(defaults: defaults).sectionOrder
                == [.agent(.cursor), .agent(.claude), .agent(.codex), .conversations])
    }

    /// A block added by an update is in no stored list. It must appear rather than vanish,
    /// and at the end rather than somewhere arbitrary.
    @Test func aBlockTheStoredOrderDoesNotNameJoinsTheEnd() {
        let settings = settings(["agent:cursor"])
        #expect(settings.sectionOrder.first == .agent(.cursor))
        #expect(Set(settings.sectionOrder) == Set(PanelSection.all))
        #expect(settings.sectionOrder.count == PanelSection.all.count)
    }

    /// A name that no longer belongs to a block - one dropped by a later release - must
    /// not leave a hole or an extra.
    @Test func aNameThatIsNoLongerABlockIsIgnored() {
        let settings = settings(["agent:gremlin", "conversations", "agent:claude"])
        #expect(settings.sectionOrder == [.conversations, .agent(.claude), .agent(.codex), .agent(.cursor)])
    }

    /// What the readers and the menu bar work from: the agents alone, in the same order.
    @Test func theShownAgentsFollowTheOrder() {
        let settings = settings()
        settings.move(.agent(.cursor), onto: .agent(.claude))
        settings.setEnabled(.claude, false)
        #expect(settings.agents == [.cursor, .codex])
    }

    @Test func aSectionSurvivesARoundTripThroughItsName() {
        for section in PanelSection.all {
            #expect(PanelSection(rawValue: section.rawValue) == section)
        }
        #expect(PanelSection(rawValue: "agent:") == nil)
        #expect(PanelSection(rawValue: "nonsense") == nil)
    }
}

/// Which windows are announced as they fill, and at which marks; and the words it says.
@Suite("AppSettings · usage alerts")
@MainActor
struct UsageAlertSettingsTests {
    private func settings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "UsageAlertSettingsTests-\(UUID().uuidString)")!)
    }

    /// Nothing is announced until a window is chosen; the marks wait at 80 and 90.
    @Test func aFreshInstallAnnouncesNothing() {
        let settings = settings()
        #expect(settings.alertWindows.isEmpty)
        #expect(settings.alertThresholds == [80, 90])
        #expect(!settings.alertsAnything)
    }

    @Test func choicesAreKeptSortedAndSurviveARelaunch() {
        let defaults = UserDefaults(suiteName: "UsageAlertSettingsTests-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.setAlerts(on: "claude|5h", true)
        settings.setAlerts(on: "claude|5h", true)
        settings.setThreshold(95, true)
        settings.setThreshold(50, true)
        settings.setThreshold(80, false)
        #expect(settings.alertWindows == ["claude|5h"])
        #expect(settings.alertThresholds == [50, 90, 95])
        #expect(settings.alertsAnything)

        let again = AppSettings(defaults: defaults)
        #expect(again.alertWindows == ["claude|5h"])
        #expect(again.alertThresholds == [50, 90, 95])
        again.setAlerts(on: "claude|5h", false)
        #expect(!again.alertsAnything)
    }

    @Test func theMessageSaysTheWindowTheMarkAndWhenItStartsOver() {
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        let weekly = UsageLimit(agent: .codex, title: "Weekly", percentUsed: 91.4,
                                resetsAt: now.addingTimeInterval(86400 + 4 * 3600), windowLength: 7 * 86400)
        let message = Notifier.message(for: .init(limit: weekly, threshold: 90), now: now)
        #expect(message.title == "Codex \u{00B7} Weekly: 91% used")
        #expect(message.body.hasPrefix("Past your 90% mark. Starts over in 1d 4h, "))

        let extra = UsageLimit(agent: .claude, title: "Extra usage", percentUsed: 100, resetsAt: nil)
        #expect(Notifier.message(for: .init(limit: extra, threshold: 100), now: now).body == "Used up.")
    }
}
