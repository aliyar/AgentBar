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
