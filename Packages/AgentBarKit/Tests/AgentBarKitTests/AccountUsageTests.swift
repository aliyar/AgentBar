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
         "additional_rate_limits":[{"limit_name":"GPT-5.3-Codex-Spark","rate_limit":{"primary_window":{"used_percent":9,"limit_window_seconds":18000,"reset_at":1788437899}}}],
         "credits":{"has_credits":false},"rate_limit_reached_type":null}
        """
        let reading = AccountUsage.codexReading(from: Data(json.utf8))
        // The plan's window, and the model that meters its own beside it.
        // The window first, so two windows of one model stay apart when the name is cut;
        // "Codex" is dropped from the name because the row already sits under Codex.
        #expect(reading.limits.map(\.title) == ["5h · Spark", "Weekly"])
        // Shortest window first, whoever meters it: the model's 5 h before the plan's week.
        let spark = try #require(reading.limits.first)
        #expect(spark.agent == .codex)
        #expect(spark.percentUsed == 9)
        // The long name is kept for the row's tooltip, not for its label.
        #expect(spark.fullName == "GPT-5.3-Codex-Spark")
        let weekly = try #require(reading.limits.last)
        #expect(weekly.percentUsed == 2)
        #expect(weekly.fullName == nil)
        #expect(weekly.resetsAt == Date(timeIntervalSince1970: 1788769105))
        #expect(weekly.windowLength == 604800)
        #expect(reading.credits == nil)
        #expect(AccountUsage.codexReading(from: Data("{}".utf8)).isEmpty)
        #expect(AccountUsage.codexReading(from: Data("nope".utf8)).isEmpty)
    }

    /// A named limit that cannot be named, or one whose windows are malformed, is left
    /// out - it never costs the plan's own windows their row.
    @Test func aMalformedNamedLimitDoesNotCostThePlanItsWindows() {
        let json = """
        {"rate_limit":{"primary_window":{"used_percent":2,"limit_window_seconds":604800,"reset_at":1}},
         "additional_rate_limits":[{"rate_limit":{"primary_window":{"used_percent":9,"limit_window_seconds":18000,"reset_at":2}}},
                                   "not an object",
                                   {"limit_name":"  ","rate_limit":null},
                                   {"metered_feature":"code_review","rate_limit":{"primary_window":{"used_percent":40,"limit_window_seconds":18000,"reset_at":3}}}]}
        """
        // Unnamed and malformed entries drop; the one named by its metered feature stays,
        // and sorts before the plan's week because its window is the shorter one.
        #expect(AccountUsage.codexReading(from: Data(json.utf8)).limits.map(\.title)
            == ["5h · code_review", "Weekly"])
    }

    @Test func codexCreditsComeBackAsABalance() {
        let held = #"{"rate_limit":{"primary_window":{"used_percent":2,"limit_window_seconds":604800,"reset_at":1}},"credits":{"has_credits":true,"unlimited":false,"balance":"12.4"}}"#
        #expect(AccountUsage.codexReading(from: Data(held.utf8)).credits?.caption == "$12.40 credits")
        let none = #"{"rate_limit":{"primary_window":{"used_percent":2,"limit_window_seconds":604800,"reset_at":1}},"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}"#
        #expect(AccountUsage.codexReading(from: Data(none.utf8)).credits == nil)
    }

    @Test func cursorPlanUsageIsRead_2026_09_03() throws {
        let json = """
        {"billingCycleStart":"2026-08-12T12:09:25.954Z","billingCycleEnd":"2026-09-12T12:09:25.954Z","membershipType":"free","limitType":"user","isUnlimited":false,
         "individualUsage":{"plan":{"enabled":true,"used":0,"limit":0,"remaining":0,"breakdown":{"included":0,"bonus":127,"total":127},"autoPercentUsed":100,"apiPercentUsed":0,"totalPercentUsed":63.5},
                            "onDemand":{"enabled":false,"used":0,"limit":null,"remaining":null}},
         "teamUsage":null}
        """
        let reading = AccountUsage.cursorReading(from: Data(json.utf8))
        let limits = reading.limits
        // The row is the window it measures; the plan is said beside the agent's name.
        #expect(limits.map(\.title) == ["Monthly"])
        #expect(reading.identity.plan == "Free")
        let plan = try #require(limits.first)
        #expect(plan.agent == .cursor)
        #expect(plan.percentUsed == 63.5)
        #expect(plan.resetsAt == ISODate.parse("2026-09-12T12:09:25.954Z"))
        let month: TimeInterval = 31 * 86400
        #expect(plan.windowLength == month)
        // On-demand appears only when it is on and has a limit.
        let withDemand = json.replacingOccurrences(of: #""onDemand":{"enabled":false,"used":0,"limit":null,"remaining":null}"#,
                                                   with: #""onDemand":{"enabled":true,"used":25,"limit":100,"remaining":75}"#)
        #expect(AccountUsage.cursorReading(from: Data(withDemand.utf8)).limits.map(\.title) == ["Monthly", "On-demand"])
        #expect(AccountUsage.cursorReading(from: Data(withDemand.utf8)).limits.last?.percentUsed == 25)
    }

    /// Cursor answers differently by plan. Reading only `plan.totalPercentUsed` left a
    /// team member, and an account spending from the team's pool, with an empty panel.
    @Test func cursorFallsBackThroughTheFiguresTheAccountActuallyReports() {
        func percent(_ usage: String) -> Double? {
            let json = #"{"billingCycleEnd":"2026-09-12T12:09:25.954Z","membershipType":"pro",\#(usage)}"#
            // Rounded to the hundredth: a ratio of cents is a float, and the panel shows whole percents anyway.
            return AccountUsage.cursorReading(from: Data(json.utf8)).limits.first
                .map { ($0.percentUsed * 100).rounded() / 100 }
        }
        // The two lanes are one window measured apart, so the window is their mean.
        #expect(percent(#""individualUsage":{"plan":{"enabled":true,"autoPercentUsed":80,"apiPercentUsed":20}}"#) == 50)
        #expect(percent(#""individualUsage":{"plan":{"enabled":true,"apiPercentUsed":30}}"#) == 30)
        // Cents, when no percentage is written at all.
        #expect(percent(#""individualUsage":{"plan":{"enabled":true,"used":2500,"limit":10000}}"#) == 25)
        // A team member's personal cap, reported instead of a plan.
        #expect(percent(#""individualUsage":{"overall":{"enabled":true,"used":7384,"limit":10000}}"#) == 73.84)
        // Nothing individual at all: the pool the team spends from.
        #expect(percent(#""teamUsage":{"pooled":{"enabled":true,"used":5000,"limit":10000}}"#) == 50)
        #expect(percent(#""individualUsage":{"plan":{"enabled":true}}"#) == nil)
    }

    /// An unlimited plan has no ceiling to fill; a percentage of it would be a number
    /// about nothing.
    @Test func anUnlimitedPlanIsSaidRatherThanMeasured() {
        let json = """
        {"billingCycleEnd":"2026-09-12T12:09:25.954Z","membershipType":"enterprise","isUnlimited":true,
         "individualUsage":{"plan":{"enabled":true,"totalPercentUsed":0}}}
        """
        let reading = AccountUsage.cursorReading(from: Data(json.utf8))
        #expect(reading.limits.isEmpty)
        #expect(reading.credits?.caption == "unlimited credits")
    }

    /// The row says what tells the limit apart; the whole name is what resting on it says.
    @Test func aModelsLimitIsNamedByThePartThatTellsItApart() {
        #expect(Prose.limitName("GPT-5.3-Codex-Spark") == "Spark")
        #expect(Prose.limitName("code_review") == "code_review")
        #expect(Prose.limitName("Sora") == "Sora")
        // Nothing is shortened to a fragment that says less than the whole.
        #expect(Prose.limitName("gpt-5x") == "gpt-5x")
    }

    @Test func planNamesAreTheAccountsOwnWordsTidied() {
        #expect(Reading.planName("prolite") == "Pro Lite")
        #expect(Reading.planName("plus") == "Plus")
        #expect(Reading.planName("free_workspace") == "Free workspace")
        #expect(Reading.planName("enterprise") == "Enterprise")
        #expect(Reading.planName("  ") == nil)
        #expect(Reading.planName(nil) == nil)
    }

    @Test func claudeAccountAnswersInTheUsageFileShape() {
        // The same JSON the status line caches: the existing parser reads it.
        let json = #"{"limits":[{"kind":"session","percent":41,"resets_at":"2026-09-02T20:50:00.073173+00:00"}]}"#
        #expect(ClaudeReader.reading(from: Data(json.utf8)).limits.first?.percentUsed == 41)
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
        #expect(Credentials.claude(in: Data(#"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x","refreshToken":"r"}}"#.utf8))?.accessToken == "sk-ant-oat01-x")
        #expect(Credentials.claude(in: Data(#"{"claudeAiOauth":{"accessToken":""}}"#.utf8)) == nil)
        #expect(Credentials.claude(in: Data("{}".utf8)) == nil)
        // The plan rides in the same JSON: "max" sold at 20x is the plan a person names.
        let max20 = #"{"claudeAiOauth":{"accessToken":"t","subscriptionType":"max","rateLimitTier":"default_claude_max_20x"}}"#
        #expect(Credentials.claude(in: Data(max20.utf8))?.plan == "Max 20x")
        #expect(Credentials.claudePlan("max", tier: "default_claude_max_5x") == "Max 5x")
        // No multiplier to add, and nothing invented when the tier says nothing usable.
        #expect(Credentials.claudePlan("pro", tier: nil) == "Pro")
        #expect(Credentials.claudePlan("max", tier: "default_claude_max") == "Max")
        #expect(Credentials.claudePlan(nil, tier: "default_claude_max_20x") == nil)
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
