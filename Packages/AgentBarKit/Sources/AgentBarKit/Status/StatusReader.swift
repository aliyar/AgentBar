import Foundation

/// Asks one agent's status page how it is doing.
///
/// The same shape as `AccountUsage`, with one difference worth stating: these pages are
/// public. No credential is read, none is sent, and nothing identifies the Mac beyond the
/// app's name - unlike the account reads, which carry the sign-in the agent already keeps.
public enum StatusReader {
    public enum Problem: Error, Equatable, Sendable {
        case offline(String)
        case badResponse(Int)
        case unreadable

        /// A few words for the panel.
        public var description: String {
            switch self {
            case .offline: "offline"
            case .badResponse(let code): "no answer (\(code))"
            case .unreadable: "unexpected answer"
            }
        }
    }

    public enum Answer: Sendable {
        case read(ServiceStatus, etag: String?)
        /// The page says it has not changed since the etag we held. What we have stands.
        case unchanged
        case failed(Problem)
    }

    public static func fetch(_ agent: Agent, etag: String? = nil,
                             session: URLSession = .shared, now: Date = .now) async -> Answer {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request(for: agent, etag: etag))
        } catch {
            return .failed(.offline(error.localizedDescription))
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        // Atlassian's pages answer a conditional request; incident.io's send no etag and
        // never reach here.
        if status == 304 { return .unchanged }
        guard (200..<300).contains(status) else { return .failed(.badResponse(status)) }
        guard let reading = StatusPage.summary(from: data, watching: agent.statusComponents, now: now) else {
            return .failed(.unreadable)
        }
        return .read(reading, etag: http?.value(forHTTPHeaderField: "ETag"))
    }

    static func request(for agent: Agent, etag: String?) -> URLRequest {
        var request = URLRequest(url: agent.statusFeed)
        request.setValue("AgentBar (macOS)", forHTTPHeaderField: "User-Agent")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        // The session's own cache would answer a repeat itself and the 304 we are asking
        // for would never be seen: the etag above is the only cache this read keeps.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        return request
    }
}
