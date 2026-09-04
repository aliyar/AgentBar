import Foundation
import Testing
@testable import AgentBarKit

/// The two `api/v2/summary.json` shapes seen on 4 Sep 2026: Atlassian Statuspage, which
/// Claude and Cursor publish, and incident.io, which OpenAI publishes behind the same path
/// with two of the keys missing.
@Suite("StatusPage")
struct StatusPageTests {
    /// Trimmed from the live answer: six components, no open incident.
    private let anthropic = Data("""
    {"page":{"id":"tymt9n04zgry","name":"Claude","url":"https://status.claude.com",
             "time_zone":"Etc/UTC","updated_at":"2026-09-04T12:03:36.857Z"},
     "status":{"indicator":"none","description":"All Systems Operational"},
     "components":[
       {"id":"rwppv331jlwc","name":"claude.ai","status":"operational","position":1,"group":false,"group_id":null},
       {"id":"0qbwn08sd68x","name":"Claude Console (platform.claude.com)","status":"operational","position":2,"group":false,"group_id":null},
       {"id":"k8w3r06qmzrp","name":"Claude API (api.anthropic.com)","status":"operational","position":3,"group":false,"group_id":null},
       {"id":"yyzkbfz2thpt","name":"Claude Code","status":"operational","position":4,"group":false,"group_id":null},
       {"id":"bpp5gb3hpjcl","name":"Claude Cowork","status":"operational","position":5,"group":false,"group_id":null},
       {"id":"0scnb50nvy53","name":"Claude for Government","status":"operational","position":6,"group":false,"group_id":null}],
     "incidents":[],"scheduled_maintenances":[]}
    """.utf8)

    /// OpenAI's page. Note what is *not* there: no `incidents`, no `scheduled_maintenances`,
    /// no `group` on a component. Requiring any of them would throw the whole reading away.
    private let openAI = Data("""
    {"page":{"id":"01JMDK9XYNY6RXSED6SDWW50WY","name":"OpenAI","url":"https://status.openai.com/",
             "updated_at":"2026-07-09T19:25:56Z"},
     "status":{"description":"All Systems Operational","indicator":"none"},
     "components":[
       {"id":"01JMXBRMFE6N2NNT7DG6XZQ6PW","name":"Images","status":"operational","position":0},
       {"id":"01JVCV8YSWZFRSM1G5CVP253SK","name":"Codex Web","status":"operational","position":14},
       {"id":"01KMKFAMWKQ81YWSE1Z18R6VHR","name":"Codex in ChatGPT Desktop","status":"operational","position":16},
       {"id":"01KMP3KP5MGE23B80K1EK4S8PV","name":"Codex API","status":"operational","position":17}]}
    """.utf8)

    @Test func anthropicSummaryIsRead_2026_09_04() throws {
        let status = try #require(StatusPage.summary(from: anthropic, watching: Agent.claude.statusComponents))
        #expect(status.level == .operational)
        #expect(status.description == "All Systems Operational")
        #expect(status.components.count == 6)
        #expect(status.incidents.isEmpty)
        #expect(!status.isFallback)
        // "Claude API" finds "Claude API (api.anthropic.com)": the names are matched by prefix.
        #expect(status.watched.map(\.name) == ["Claude API (api.anthropic.com)", "Claude Code"])
        #expect(status.updatedAt != nil)
    }

    @Test func openAISummaryWithoutAnIncidentsKeyIsRead_2026_09_04() throws {
        let status = try #require(StatusPage.summary(from: openAI, watching: Agent.codex.statusComponents))
        #expect(status.level == .operational)
        #expect(status.incidents.isEmpty)
        #expect(!status.isFallback)
        // Only Codex API, not the ChatGPT and web surfaces the CLI does not run on.
        #expect(status.watched.map(\.name) == ["Codex API"])
        // The page's own order is kept: components carry a position here too.
        #expect(status.components.first?.name == "Images")
    }

    @Test func theWorstWatchedComponentDecidesTheLevel() throws {
        let json = Data("""
        {"status":{"indicator":"minor","description":"Partially Degraded Service"},
         "components":[
           {"id":"a","name":"Claude Code","status":"degraded_performance","position":1},
           {"id":"b","name":"Claude API (api.anthropic.com)","status":"major_outage","position":2}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.claude.statusComponents))
        #expect(status.level == .outage)
        #expect(status.detail == "Claude Code, Claude API (api.anthropic.com)")
    }

    /// A component the page lists but this agent does not run on must not raise an alarm:
    /// claude.ai going down while Claude Code keeps working is not this agent's outage.
    @Test func aComponentThisAgentDoesNotRunOnIsListedButNeverDecides() throws {
        let json = Data("""
        {"status":{"indicator":"critical","description":"Major Service Outage"},
         "components":[
           {"id":"a","name":"claude.ai","status":"major_outage","position":1},
           {"id":"b","name":"Claude Code","status":"operational","position":2}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.claude.statusComponents))
        #expect(status.level == .operational)
        #expect(status.components.count == 2)
        #expect(!status.isFallback)
    }

    @Test func aPageWhoseComponentsWeDoNotKnowFallsBackToItsIndicator() throws {
        let json = Data("""
        {"status":{"indicator":"major","description":"Partial System Outage"},
         "components":[{"id":"a","name":"Something Renamed","status":"partial_outage","position":1}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.claude.statusComponents))
        #expect(status.isFallback)
        #expect(status.level == .partial)
        #expect(status.watched.isEmpty)
    }

    /// Atlassian repeats a group's children below it; drawing both would say everything twice.
    @Test func aComponentGroupIsNotARowOfItsOwn() throws {
        let json = Data("""
        {"status":{"indicator":"none"},
         "components":[
           {"id":"g","name":"Agents","status":"operational","position":1,"group":true},
           {"id":"a","name":"CLI","status":"operational","position":2,"group":false,"group_id":"g"}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.cursor.statusComponents))
        #expect(status.components.map(\.name) == ["CLI"])
    }

    @Test func everyComponentVocabularyIsMapped() {
        #expect(StatusPage.level(ofComponent: "operational") == .operational)
        #expect(StatusPage.level(ofComponent: "degraded_performance") == .degraded)
        #expect(StatusPage.level(ofComponent: "partial_outage") == .partial)
        #expect(StatusPage.level(ofComponent: "major_outage") == .outage)
        #expect(StatusPage.level(ofComponent: "full_outage") == .outage)
        #expect(StatusPage.level(ofComponent: "under_maintenance") == .maintenance)
        #expect(StatusPage.level(ofComponent: "something new") == .unknown)
        #expect(StatusPage.level(ofComponent: nil) == .unknown)
    }

    /// The page states its own health in different words from its components'.
    @Test func everyPageVocabularyIsMapped() {
        #expect(StatusPage.level(ofPage: "none") == .operational)
        #expect(StatusPage.level(ofPage: "minor") == .degraded)
        #expect(StatusPage.level(ofPage: "major") == .partial)
        #expect(StatusPage.level(ofPage: "critical") == .outage)
        #expect(StatusPage.level(ofPage: "maintenance") == .maintenance)
        #expect(StatusPage.level(ofPage: "something new") == .unknown)
    }

    @Test func anOpenIncidentIsCarriedWithItsShortLink() throws {
        let json = Data("""
        {"status":{"indicator":"major","description":"Partial System Outage"},
         "components":[{"id":"a","name":"Claude Code","status":"partial_outage","position":1}],
         "incidents":[{"id":"9xz4","name":"**Elevated** errors for multiple models","status":"investigating",
                       "impact":"major","created_at":"2026-09-03T13:26:04Z","started_at":"2026-09-03T13:20:00Z",
                       "shortlink":"https://stspg.io/9xz4hhmd1jzn"},
                      {"id":"bad","status":"investigating"}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.claude.statusComponents))
        // The nameless one is dropped rather than costing the readable one its place.
        #expect(status.incidents.count == 1)
        let incident = try #require(status.incidents.first)
        #expect(incident.name == "Elevated errors for multiple models")
        #expect(incident.impact == .partial)
        #expect(incident.url?.absoluteString == "https://stspg.io/9xz4hhmd1jzn")
        #expect(incident.startedAt == ISODate.parse("2026-09-03T13:20:00Z"))
    }

    @Test func nothingUsableReadsAsNothing() {
        let watching = Agent.claude.statusComponents
        #expect(StatusPage.summary(from: Data("{}".utf8), watching: watching) == nil)
        #expect(StatusPage.summary(from: Data("\"nope\"".utf8), watching: watching) == nil)
        #expect(StatusPage.summary(from: Data(#"{"status":{"indicator":"none"}"#.utf8), watching: watching) == nil)
        #expect(StatusPage.summary(from: Data(), watching: watching) == nil)
    }

    /// One malformed component must not cost the page its other rows.
    @Test func aMalformedComponentDoesNotCostThePageItsOthers() throws {
        let json = Data("""
        {"status":{"indicator":"none"},
         "components":[{"id":"a","name":"Claude Code","status":"operational","position":1},
                       "not an object",
                       {"name":"no id at all","status":"operational"},
                       {"id":"b","name":"   ","status":"operational","position":3}]}
        """.utf8)
        let status = try #require(StatusPage.summary(from: json, watching: Agent.claude.statusComponents))
        #expect(status.components.map(\.name) == ["Claude Code"])
    }

    /// The addresses are part of the reading and a typo in one is silent otherwise.
    /// `status.anthropic.com` redirects to `status.claude.com`; the new host is written out.
    @Test func everyAgentPointsAtItsOwnSummary() {
        #expect(Agent.claude.statusFeed.absoluteString == "https://status.claude.com/api/v2/summary.json")
        #expect(Agent.codex.statusFeed.absoluteString == "https://status.openai.com/api/v2/summary.json")
        #expect(Agent.cursor.statusFeed.absoluteString == "https://status.cursor.com/api/v2/summary.json")
    }

    /// These pages are public: the request carries the app's name, the tag it was last
    /// given, and nothing else. No credential must ever find its way in.
    @Test func requestsCarryNoCredential() throws {
        let plain = StatusReader.request(for: .claude, etag: nil)
        #expect(plain.url == Agent.claude.statusFeed)
        #expect(plain.value(forHTTPHeaderField: "User-Agent") == "AgentBar (macOS)")
        #expect(plain.value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(plain.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(plain.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(plain.timeoutInterval == 10)
        // The session's own cache would answer a repeat itself and the 304 we are asking
        // for would never be seen.
        #expect(plain.cachePolicy == .reloadIgnoringLocalCacheData)

        let conditional = StatusReader.request(for: .cursor, etag: "W/\"abc\"")
        #expect(conditional.value(forHTTPHeaderField: "If-None-Match") == "W/\"abc\"")
    }
}
