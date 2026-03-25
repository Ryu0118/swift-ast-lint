import Testing
import Foundation
@testable import SwiftASTLint

@Suite("ConfigurationLoader")
struct ConfigurationLoaderTests {
    private func tempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "swift-ast-lint-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("load valid yml")
    func validYml() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let yml = """
        included_paths:
          - "Sources/**/*.swift"
        excluded_paths:
          - ".build/**"
        """
        try yml.write(toFile: "\(dir)/.swift-ast-lint.yml", atomically: true, encoding: .utf8)
        let config = try ConfigurationLoader.load(from: "\(dir)/.swift-ast-lint.yml")
        #expect(config.includedPaths == ["Sources/**/*.swift"])
        #expect(config.excludedPaths == [".build/**"])
    }

    @Test("missing file throws")
    func missingFile() {
        #expect(throws: (any Error).self) {
            try ConfigurationLoader.load(from: "/nonexistent/.swift-ast-lint.yml")
        }
    }

    @Test("empty yml returns empty config")
    func emptyYml() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "".write(toFile: "\(dir)/cfg.yml", atomically: true, encoding: .utf8)
        let config = try ConfigurationLoader.load(from: "\(dir)/cfg.yml")
        #expect(config.includedPaths.isEmpty)
        #expect(config.excludedPaths.isEmpty)
    }

    @Test("malformed yml throws")
    func malformedYml() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "{{{{not yaml".write(toFile: "\(dir)/bad.yml", atomically: true, encoding: .utf8)
        #expect(throws: (any Error).self) {
            try ConfigurationLoader.load(from: "\(dir)/bad.yml")
        }
    }

    @Test("non-dictionary YAML throws invalidFormat")
    func nonDictYml() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "- foo\n- bar\n".write(toFile: "\(dir)/list.yml", atomically: true, encoding: .utf8)
        #expect(throws: ConfigurationError.self) {
            try ConfigurationLoader.load(from: "\(dir)/list.yml")
        }
    }
}
