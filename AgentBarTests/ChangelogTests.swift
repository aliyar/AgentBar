import Foundation
import Testing
@testable import AgentBar

@Suite("Changelog")
struct ChangelogTests {
    @Test func keepAChangelogIsReadIntoReleases() throws {
        let text = """
        # Changelog

        Preamble that is not part of any release.

        ## [Unreleased]

        ## [1.2.0] - 2026-09-02

        ### Added
        - **Widgets** for the desktop, in three
          sizes.
        - A Dock window.

        ### Fixed
        - Stale percentages.

        ## [1.1.0] - 2026-08-01

        A release with a paragraph and `code`.

        [Unreleased]: https://example.com/compare/v1.2.0...HEAD
        [1.2.0]: https://example.com/releases/tag/v1.2.0
        """
        let releases = Changelog.parse(text)
        // The empty Unreleased section and the link references are dropped.
        #expect(releases.map(\.version) == ["1.2.0", "1.1.0"])
        let latest = try #require(releases.first)
        #expect(latest.date != nil)
        #expect(latest.lines.map(\.kind) == [.heading, .bullet, .bullet, .heading, .bullet])
        // A wrapped bullet is one line again.
        #expect(latest.lines[1].text == "**Widgets** for the desktop, in three sizes.")
        #expect(releases[1].lines.first?.kind == .paragraph)
    }

    @Test func theBundledChangelogIsPresent() {
        #expect(Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") != nil)
    }

    @Test func paneSelectionWalksLikeABrowser() {
        let selection = SettingsPaneSelection(initial: "a")
        #expect(!selection.canGoBack && !selection.canGoForward)
        selection.select("b")
        selection.select("c")
        selection.goBack()
        #expect(selection.pane == "b" as AnyHashable)
        #expect(selection.canGoForward)
        selection.select("d")   // forgets "c"
        #expect(!selection.canGoForward)
        selection.goBack(); selection.goBack()
        #expect(selection.pane == "a" as AnyHashable)
        selection.select("a")   // no-op, nothing pushed
        #expect(selection.canGoForward)
    }
}
