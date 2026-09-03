import Foundation
import SQLite3

/// The sign-ins the agents keep on this Mac, read the way the agents' own tools read them.
/// Nothing is written back, nothing is logged, and a token lives only as long as the
/// request it is used for.
public enum Credentials {
    public struct Codex: Sendable {
        public let accessToken: String
        public let accountID: String?
        /// The person the ChatGPT sign-in was issued to, from its id token.
        public let identity: Identity
    }

    public struct Claude: Sendable {
        public let accessToken: String
        /// The plan the sign-in was issued for: "Max 20x", "Pro".
        public let plan: String?
    }

    // MARK: Claude Code

    /// Claude Code stores its OAuth tokens in the login Keychain under this service name,
    /// through the `security` tool - which macOS therefore trusts to read the item back
    /// without asking the user. Reading it through the Security framework from another
    /// app would put up a Keychain prompt; the tool does not.
    static let claudeKeychainService = "Claude Code-credentials"

    /// The sign-in Claude Code holds - the token, and the plan it was issued for. Nil
    /// when Claude Code is not signed in.
    public static func claude(home: URL = HomeDirectory.url) -> Claude? {
        if let json = keychainPassword(service: claudeKeychainService), let signIn = claude(in: json) {
            return signIn
        }
        // Older builds and Linux keep the same JSON in a file.
        if let data = try? Data(contentsOf: home.appendingPathComponent(".claude/.credentials.json")) {
            return claude(in: data)
        }
        return nil
    }

    static func claude(in data: Data) -> Claude? {
        struct File: Decodable {
            struct OAuth: Decodable {
                let accessToken: String?
                let subscriptionType: String?
                /// "default_claude_max_20x" - the multiplier a Max plan was sold with.
                let rateLimitTier: String?
            }
            let claudeAiOauth: OAuth?
        }
        guard let oauth = (try? JSONDecoder().decode(File.self, from: data))?.claudeAiOauth,
              let token = oauth.accessToken, !token.isEmpty else { return nil }
        return Claude(accessToken: token, plan: claudePlan(oauth.subscriptionType, tier: oauth.rateLimitTier))
    }

    /// "max" with a 20x tier is the plan a person calls "Max 20x"; the multiplier is the
    /// difference that matters, and Claude states it separately.
    static func claudePlan(_ subscription: String?, tier: String?) -> String? {
        guard let plan = Reading.planName(subscription) else { return nil }
        guard let tier, let multiplier = tier.split(separator: "_").last.map(String.init),
              multiplier.hasSuffix("x"), multiplier.dropLast().allSatisfy(\.isNumber),
              !plan.lowercased().contains(multiplier) else { return plan }
        return "\(plan) \(multiplier)"
    }

    private static func keychainPassword(service: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        // `-w` prints the secret with a trailing newline.
        return data.last == UInt8(ascii: "\n") ? data.dropLast() : data
    }

    // MARK: Codex

    /// Codex keeps its ChatGPT sign-in in `~/.codex/auth.json`. Nil when signed in with an
    /// API key (no plan windows to show) or when the token has expired - Codex refreshes it
    /// when it runs; the app never does, so as not to touch Codex's file.
    public static func codex(home: URL = HomeDirectory.url, now: Date = .now) -> Codex? {
        guard let data = try? Data(contentsOf: home.appendingPathComponent(".codex/auth.json")) else { return nil }
        return codex(in: data, now: now)
    }

    static func codex(in data: Data, now: Date) -> Codex? {
        struct File: Decodable {
            struct Tokens: Decodable {
                let access_token: String?
                let id_token: String?
                let account_id: String?
            }
            let auth_mode: String?
            let tokens: Tokens?
        }
        guard let file = try? JSONDecoder().decode(File.self, from: data),
              file.auth_mode == nil || file.auth_mode == "chatgpt",
              let token = file.tokens?.access_token, !token.isEmpty else { return nil }
        if let expiry = JWT.expiry(of: token), expiry < now { return nil }
        // The id token is the one that names the person; the access token carries none.
        let claims = file.tokens?.id_token.flatMap { JWT.claims(of: $0) }
        return Codex(accessToken: token, accountID: file.tokens?.account_id,
                     identity: Identity(email: claims?["email"] as? String, name: claims?["name"] as? String))
    }

    // MARK: Cursor

    /// Cursor keeps its session in the editor's state database. The website wants it as a
    /// cookie: the user id (the tail of the token's subject) and the token, joined by "::".
    public static func cursorSessionCookie(home: URL = HomeDirectory.url, now: Date = .now) -> String? {
        let database = home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard let db = SQLiteCopy(of: database) else { return nil }
        defer { db.close() }
        guard let token = db.value(in: "ItemTable", key: "cursorAuth/accessToken") else { return nil }
        return cursorSessionCookie(accessToken: token, now: now)
    }

    /// The account Cursor's editor has signed in, cached beside its token.
    public static func cursorIdentity(home: URL = HomeDirectory.url) -> Identity {
        let database = home.appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard let db = SQLiteCopy(of: database) else { return Identity() }
        defer { db.close() }
        return Identity(plan: Reading.planName(db.value(in: "ItemTable", key: "cursorAuth/stripeMembershipType")),
                        email: db.value(in: "ItemTable", key: "cursorAuth/cachedEmail"))
    }

    static func cursorSessionCookie(accessToken token: String, now: Date) -> String? {
        guard let claims = JWT.claims(of: token), let subject = claims["sub"] as? String else { return nil }
        if let expiry = JWT.expiry(of: token), expiry < now { return nil }
        let userID = subject.split(separator: "|").last.map(String.init) ?? subject
        return "WorkosCursorSessionToken=\(userID)%3A%3A\(token)"
    }

}

/// Just enough of JSON Web Tokens to read a claim: the middle part, base64url, a JSON object.
enum JWT {
    static func claims(of token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var body = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while body.count % 4 != 0 { body += "=" }
        guard let data = Data(base64Encoded: body) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func expiry(of token: String) -> Date? {
        guard let seconds = claims(of: token)?["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
