import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import Testing

@Suite("ConfigurationLoader YAML parsing: valid configs, empty files, malformed input, and non-dictionary rejection")
struct ConfigurationLoaderTests {
    @Test("load valid yml")
    func validYml() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let yml = """
            included_paths:
              - "Sources/**/*.swift"
            excluded_paths:
              - ".build/**"
            """
            let path = dir.appendingPathComponent(".swift-ast-lint.yml")
            try yml.write(to: path, atomically: true, encoding: .utf8)
            let config = try #require(try ConfigurationLoader().load(from: path.path(percentEncoded: false)))
            #expect(config.includedPaths == ["Sources/**/*.swift"])
            #expect(config.excludedPaths == [".build/**"])
        }
    }

    @Test("missing file returns nil")
    func missingFile() throws {
        let config = try ConfigurationLoader().load(from: "/nonexistent/.swift-ast-lint.yml")
        #expect(config == nil)
    }

    @Test("empty yml returns empty config")
    func emptyYml() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("cfg.yml")
            try "".write(to: path, atomically: true, encoding: .utf8)
            let config = try #require(try ConfigurationLoader().load(from: path.path(percentEncoded: false)))
            #expect(config.includedPaths.isEmpty)
            #expect(config.excludedPaths.isEmpty)
        }
    }

    @Test("malformed yml throws")
    func malformedYml() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("bad.yml")
            try "{{{{not yaml".write(to: path, atomically: true, encoding: .utf8)
            #expect(throws: (any Error).self) {
                try ConfigurationLoader().load(from: path.path(percentEncoded: false))
            }
        }
    }

    @Test("non-dictionary YAML throws DecodingError")
    func nonDictYml() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("list.yml")
            try "- foo\n- bar\n".write(to: path, atomically: true, encoding: .utf8)
            #expect(throws: DecodingError.self) {
                try ConfigurationLoader().load(from: path.path(percentEncoded: false))
            }
        }
    }

    @Test("included_paths only, excluded_paths absent")
    func includeOnly() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let yml = "included_paths:\n  - \"Sources/**\"\n"
            let path = dir.appendingPathComponent("inc.yml")
            try yml.write(to: path, atomically: true, encoding: .utf8)
            let config = try #require(try ConfigurationLoader().load(from: path.path(percentEncoded: false)))
            #expect(config.includedPaths == ["Sources/**"])
            #expect(config.excludedPaths.isEmpty)
        }
    }

    @Test("excluded_paths only, included_paths absent")
    func excludeOnly() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let yml = "excluded_paths:\n  - \".build/**\"\n"
            let path = dir.appendingPathComponent("exc.yml")
            try yml.write(to: path, atomically: true, encoding: .utf8)
            let config = try #require(try ConfigurationLoader().load(from: path.path(percentEncoded: false)))
            #expect(config.includedPaths.isEmpty)
            #expect(config.excludedPaths == [".build/**"])
        }
    }
}
