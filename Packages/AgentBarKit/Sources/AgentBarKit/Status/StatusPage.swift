import Foundation

/// Reads an `api/v2/summary.json` from a status page.
///
/// All three agents publish one, and the two families behind them - Atlassian Statuspage
/// (Claude, Cursor) and incident.io (OpenAI) - answer the same paths with nearly the same
/// shape. "Nearly" is the whole difficulty, and every difference seen on 4 Sep 2026 is
/// handled here rather than by three parsers:
///
/// - incident.io omits `incidents` and `scheduled_maintenances` **entirely**, so nothing
///   may be required.
/// - Atlassian marks a component group with `"group": true` and repeats its children below
///   it; incident.io writes no `group` key at all. Groups are dropped either way.
/// - The page's own `status.indicator` and a component's `status` are different
///   vocabularies. Both are mapped, separately.
///
/// Nothing is required, nothing throws, and a shape that is not understood reads as
/// nothing rather than as a reading - the rule every reader in this package follows.
public enum StatusPage {
    /// The reading, or nil when the answer holds neither a status nor a component.
    ///
    /// `watching` names the components this agent runs on, matched case-insensitively by
    /// prefix so "Claude API" finds "Claude API (api.anthropic.com)". The level is the
    /// worst of the ones that matched; when none did, the page's own indicator stands in
    /// and the reading is marked a fallback.
    public static func summary(from data: Data, watching: [String], now: Date = .now) -> ServiceStatus? {
        guard let page = try? JSONDecoder().decode(Summary.self, from: data) else { return nil }
        let wanted = watching.map { $0.lowercased() }

        var components: [StatusComponent] = []
        for raw in (page.components ?? []).compactMap(\.value) {
            // A group repeats the components listed under it; drawing both says everything twice.
            guard raw.group != true, let id = raw.id, let name = raw.name?.trimmed, !name.isEmpty else { continue }
            let isWatched = wanted.contains { name.lowercased().hasPrefix($0) }
            components.append(StatusComponent(id: id, name: name, level: level(ofComponent: raw.status),
                                              isWatched: isWatched))
        }
        // Atlassian numbers its components; incident.io leaves the order it gave them in.
        if (page.components ?? []).contains(where: { $0.value?.position != nil }) {
            let position = Dictionary(uniqueKeysWithValues: (page.components ?? []).compactMap(\.value)
                .compactMap { component -> (String, Int)? in
                    guard let id = component.id else { return nil }
                    return (id, component.position ?? .max)
                })
            components.sort { (position[$0.id] ?? .max) < (position[$1.id] ?? .max) }
        }

        let watched = components.filter(\.isWatched)
        let indicator = level(ofPage: page.status?.indicator)
        guard !components.isEmpty || page.status != nil else { return nil }

        let incidents = (page.incidents ?? []).compactMap(\.value).compactMap { raw -> Incident? in
            guard let id = raw.id, let name = raw.name?.trimmed, !name.isEmpty else { return nil }
            return Incident(id: id, name: Prose.oneLine(name),
                            impact: level(ofPage: raw.impact),
                            startedAt: ISODate.parse(raw.started_at) ?? ISODate.parse(raw.created_at),
                            url: raw.shortlink.flatMap(URL.init(string:)))
        }

        return ServiceStatus(
            level: watched.map(\.level).max() ?? indicator,
            description: page.status?.description?.trimmed,
            components: components,
            incidents: incidents,
            updatedAt: ISODate.parse(page.page?.updated_at),
            checkedAt: now,
            isFallback: watched.isEmpty
        )
    }

    // MARK: The two vocabularies

    /// A page's own overall indicator. Seen on 4 Sep 2026: `none`, `minor`, `major`,
    /// `critical`; the pages also document `maintenance`.
    static func level(ofPage indicator: String?) -> StatusLevel {
        switch indicator?.lowercased() {
        case "none": .operational
        case "minor": .degraded
        case "major": .partial
        case "critical": .outage
        case "maintenance": .maintenance
        default: .unknown
        }
    }

    /// One component's own status. A different set of words for the same idea.
    static func level(ofComponent status: String?) -> StatusLevel {
        switch status?.lowercased() {
        case "operational": .operational
        case "degraded_performance": .degraded
        case "partial_outage": .partial
        case "major_outage", "full_outage": .outage
        case "under_maintenance": .maintenance
        default: .unknown
        }
    }

    // MARK: The shape on the wire

    private struct Summary: Decodable {
        let page: Page?
        let status: Status?
        let components: [FailableDecodable<Component>]?
        /// Absent on incident.io pages. Never require it.
        let incidents: [FailableDecodable<RawIncident>]?
    }

    private struct Page: Decodable { let updated_at: String? }
    private struct Status: Decodable { let indicator: String?; let description: String? }

    private struct Component: Decodable {
        let id: String?
        let name: String?
        let status: String?
        let position: Int?
        /// Atlassian only: true for a heading that repeats its children.
        let group: Bool?
    }

    private struct RawIncident: Decodable {
        let id: String?
        let name: String?
        let impact: String?
        let started_at: String?
        let created_at: String?
        let shortlink: String?
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
