import Foundation
import Testing
@testable import AgentBarKit

/// The account endpoints' shapes as seen on 3 Sep 2026. None is documented.
@Suite("AccountUsage")
struct AccountUsageTests {
    @Test func codexAccountWindowsAreRead_2026_09_03() throws {
        let json = """
        {"user_id":"u","account_id":"a","email":"x@y","plan_type":"prolite",
         "rate_limit":{"allowed":true,"limit_reached":false,
           "primary_window":{"used_percent":2,"limit_window_seconds":604800,"reset_after_seconds":349207,"reset_at":1788769105},
           "secondary_window":null},
         "additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_at":1788437899}}}],
         "credits":{"has_credits":false},"rate_limit_reached_type":null}
        """
        let limits = AccountUsage.codexLimits(from: Data(json.utf8))
        #expect(limits.count == 1)
        let weekly = try #require(limits.first)
        #expect(weekly.agent == .codex)
        #expect(weekly.title == "Weekly")
        #expect(weekly.percentUsed == 2)
        #expect(weekly.resetsAt == Date(timeIntervalSince1970: 1788769105))
        #expect(weekly.windowLength == 604800)
        #expect(AccountUsage.codexLimits(from: Data("{}".utf8)).isEmpty)
        #expect(AccountUsage.codexLimits(from: Data("nope".utf8)).isEmpty)
    }

    @Test func cursorPlanUsageIsRead_2026_09_03() throws {
        let json = """
        {"billingCycleStart":"2026-08-12T12:09:25.954Z","billingCycleEnd":"2026-09-12T12:09:25.954Z","membershipType":"free","limitType":"user","isUnlimited":false,
         "individualUsage":{"plan":{"enabled":true,"used":0,"limit":0,"remaining":0,"breakdown":{"included":0,"bonus":127,"total":127},"autoPercentUsed":100,"apiPercentUsed":0,"totalPercentUsed":63.5},
                            "onDemand":{"enabled":false,"used":0,"limit":null,"remaining":null}},
         "teamUsage":null}
        """
        let limits = AccountUsage.cursorLimits(from: Data(json.utf8))
        #expect(limits.map(\.title) == ["Free · monthly"])
        let plan = try #require(limits.first)
        #expect(plan.agent == .cursor)
        #expect(plan.percentUsed == 63.5)
        #expect(plan.resetsAt == ISODate.parse("2026-09-12T12:09:25.954Z"))
        let month: TimeInterval = 31 * 86400
        #expect(plan.windowLength == month)
        // On-demand appears only when it is on and has a limit.
        let withDemand = json.replacingOccurrences(of: #""onDemand":{"enabled":false,"used":0,"limit":null,"remaining":null}"#,
                                                   with: #""onDemand":{"enabled":true,"used":25,"limit":100,"remaining":75}"#)
        #expect(AccountUsage.cursorLimits(from: Data(withDemand.utf8)).map(\.title) == ["Free · monthly", "On-demand"])
        #expect(AccountUsage.cursorLimits(from: Data(withDemand.utf8)).last?.percentUsed == 25)
    }

    @Test func claudeAccountAnswersInTheUsageFileShape() {
        // The same JSON the status line caches: the existing parser reads it.
        let json = #"{"limits":[{"kind":"session","percent":41,"resets_at":"2026-09-02T20:50:00.073173+00:00"}]}"#
        #expect(ClaudeReader.limits(from: Data(json.utf8)).first?.percentUsed == 41)
    }

    @Test func credentialsAreReadDefensively() {
        let now = Date(timeIntervalSince1970: 1_788_400_000)
        func jwt(exp: Double, sub: String = "auth0|user_123") -> String {
            let header = Data(#"{"alg":"none"}"#.utf8).base64EncodedString()
            let body = Data(#"{"sub":"\#(sub)","exp":\#(Int(exp))}"#.utf8).base64EncodedString()
                .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            return "\(header).\(body).sig"
        }
        // Claude: the Keychain JSON, and nothing for an empty token.
        #expect(Credentials.claudeToken(in: Data(#"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x","refreshToken":"r"}}"#.utf8)) == "sk-ant-oat01-x")
        #expect(Credentials.claudeToken(in: Data(#"{"claudeAiOauth":{"accessToken":""}}"#.utf8)) == nil)
        #expect(Credentials.claudeToken(in: Data("{}".utf8)) == nil)
        // Codex: ChatGPT sign-in with a live token; API-key sign-ins and expired tokens give nothing.
        let live = jwt(exp: now.timeIntervalSince1970 + 3600)
        let codex = Credentials.codex(in: Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":"\#(live)","account_id":"acc"}}"#.utf8), now: now)
        #expect(codex?.accessToken == live)
        #expect(codex?.accountID == "acc")
        #expect(Credentials.codex(in: Data(#"{"auth_mode":"apikey","OPENAI_API_KEY":"k"}"#.utf8), now: now) == nil)
        let expired = jwt(exp: now.timeIntervalSince1970 - 1)
        #expect(Credentials.codex(in: Data(#"{"auth_mode":"chatgpt","tokens":{"access_token":"\#(expired)"}}"#.utf8), now: now) == nil)
        // Cursor: the cookie is the user id from the subject plus the token.
        #expect(Credentials.cursorSessionCookie(accessToken: live, now: now) == "WorkosCursorSessionToken=user_123%3A%3A\(live)")
        #expect(Credentials.cursorSessionCookie(accessToken: expired, now: now) == nil)
        #expect(Credentials.cursorSessionCookie(accessToken: "garbage", now: now) == nil)
    }

    @Test func requestsCarryTheSignInAndNothingElse() {
        // Without a sign-in there is no request; the builder never invents one.
        let request = AccountUsage.request(for: .cursor, now: .distantFuture)   // every token is expired by then
        #expect(request == nil)
    }
}
