import Foundation
import Testing

/// `AgentBar/Scaffold/` is the boilerplate every app in the family shares. Nothing in it may
/// know this app's name: names come from the bundle, everything else is injected.
@Suite("Scaffold")
struct ScaffoldTests {
    @Test func nothingInTheScaffoldKnowsTheAppsName() throws {
        let scaffold = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("AgentBar/Scaffold")
        let files = try #require(FileManager.default.enumerator(at: scaffold, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count >= 10)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.components(separatedBy: "\n").enumerated() where line.contains("AgentBar") {
                Issue.record("\(file.lastPathComponent):\(number + 1) mentions the app by name: \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
}
