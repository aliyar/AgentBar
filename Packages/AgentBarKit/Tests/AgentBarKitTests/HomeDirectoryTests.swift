import Foundation
import Testing
@testable import AgentBarKit

@Suite("HomeDirectory")
struct HomeDirectoryTests {
    @Test func resolvesAnExistingAbsoluteDirectory() {
        let path = HomeDirectory.path
        #expect(path.hasPrefix("/"))
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test func neverAnswersASandboxContainer() {
        #expect(!HomeDirectory.path.contains("/Library/Containers/"))
        #expect(HomeDirectory.url.hasDirectoryPath)
    }
}
