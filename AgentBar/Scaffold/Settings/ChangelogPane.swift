import SwiftUI

/// The Changelog pane: the app's own CHANGELOG.md, bundled at build time and read here.
/// One release per block, newest first, folded to its first lines with an App Store-style
/// "more" link until opened.
struct ChangelogPane: View {
    let releases: [Changelog.Release]

    init(releases: [Changelog.Release] = Changelog.bundled()) {
        self.releases = releases
    }

    var body: some View {
        if releases.isEmpty {
            Section {
                Text("No release notes in this build.")
                    .foregroundStyle(.secondary)
            }
        }
        ForEach(releases) { release in
            Section {
                ReleaseView(release: release)
            }
        }
    }
}

private struct ReleaseView: View {
    let release: Changelog.Release
    @State private var expanded = false

    private static let foldAfter = 3

    private var visibleLines: [Changelog.Line] {
        expanded ? release.lines : Array(release.lines.prefix(Self.foldAfter))
    }
    private var folded: Bool { release.lines.count > Self.foldAfter }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(release.version == "Unreleased" ? "Unreleased" : "Version \(release.version)")
                    .font(.title3.weight(.semibold))
                Spacer()
                if let date = release.date {
                    Text(Self.relative(date))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(visibleLines) { line in
                    LineView(line: line)
                }
            }
            if folded {
                // The way the App Store folds release notes: a plain "more" in the accent
                // colour at the end of the text, "less" once it is open.
                Button(expanded ? "less" : "more") {
                    withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help(expanded ? "Show less" : "Show everything in this release")
            }
        }
        .padding(.vertical, 4)
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct LineView: View {
    let line: Changelog.Line

    var body: some View {
        switch line.kind {
        case .heading:
            Text(line.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 4)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("·")
                Text(Self.inline(line.text))
            }
            .fixedSize(horizontal: false, vertical: true)
        case .paragraph:
            Text(Self.inline(line.text))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Inline Markdown (bold, code, links) as attributed text; the raw line if it does not parse.
    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// A Keep-a-Changelog file, read into releases.
nonisolated enum Changelog {
    struct Release: Identifiable, Sendable {
        let version: String
        let date: Date?
        let lines: [Line]
        var id: String { version }
    }

    struct Line: Identifiable, Sendable {
        enum Kind: Sendable { case heading, bullet, paragraph }
        let kind: Kind
        let text: String
        let id: Int
    }

    /// The CHANGELOG.md copied into the bundle by the build (see project.yml).
    static func bundled() -> [Release] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    /// `## [1.2.3] - 2026-09-02` starts a release; `### Added` is a heading; `- x` a bullet;
    /// other text a paragraph. Everything before the first release, and empty releases
    /// (an "Unreleased" section with nothing under it), are dropped. Wrapped bullet lines
    /// are joined back into one.
    static func parse(_ text: String) -> [Release] {
        var releases: [Release] = []
        var version: String?
        var date: Date?
        var lines: [Line] = []
        var counter = 0

        func flush() {
            if let version, !lines.isEmpty {
                releases.append(Release(version: version, date: date, lines: lines))
            }
            lines = []
        }
        func add(_ kind: Line.Kind, _ text: String) {
            counter += 1
            lines.append(Line(kind: kind, text: text, id: counter))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                let heading = line.dropFirst(3)
                // "[1.2.3] - 2026-09-02" or "[Unreleased]"
                let parts = heading.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                version = parts.first?.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                date = parts.count > 1 ? dateFormatter.date(from: parts[1]) : nil
            } else if version == nil || line.hasPrefix("[") && line.contains("]: ") {
                continue // preamble, or the link references at the end
            } else if line.hasPrefix("### ") {
                add(.heading, String(line.dropFirst(4)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                add(.bullet, String(line.dropFirst(2)))
            } else if line.isEmpty {
                continue
            } else if let last = lines.last, last.kind != .heading, !raw.hasPrefix("#") {
                // A wrapped continuation of the previous bullet or paragraph.
                lines[lines.count - 1] = Line(kind: last.kind, text: last.text + " " + line, id: last.id)
            } else {
                add(.paragraph, line)
            }
        }
        flush()
        return releases
    }
}
