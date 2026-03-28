import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import Testing

@Suite(
    """
    FileCollector: Swift file enumeration, include/exclude glob filtering, \
    rule applicability check, and relative path computation
    """,
)
struct FileCollectorTests {
    private let collector = FileCollector()

    // MARK: - collectSwiftFiles

    @Test("collects only .swift files, sorted alphabetically")
    func collectSwiftFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try "".write(toFile: "\(root)/b.swift", atomically: true, encoding: .utf8)
            try "".write(toFile: "\(root)/a.swift", atomically: true, encoding: .utf8)
            try "".write(toFile: "\(root)/c.txt", atomically: true, encoding: .utf8)

            let files = try collector.collectSwiftFiles(rootPath: root)
            #expect(files.count == 2)
            #expect(files[0].hasSuffix("a.swift"))
            #expect(files[1].hasSuffix("b.swift"))
        }
    }

    @Test("collects files in subdirectories")
    func collectNestedFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try FileManager.default.createDirectory(
                atPath: "\(root)/Sources/Foo",
                withIntermediateDirectories: true,
            )
            try "".write(toFile: "\(root)/Sources/Foo/Bar.swift", atomically: true, encoding: .utf8)

            let files = try collector.collectSwiftFiles(rootPath: root)
            #expect(files.count == 1)
            #expect(files[0].contains("Sources/Foo/Bar.swift"))
        }
    }

    @Test("returns empty for non-existent directory")
    func collectNonExistent() throws {
        let files = try collector.collectSwiftFiles(rootPath: "/nonexistent-path-12345")
        #expect(files.isEmpty)
    }

    // MARK: - applyFilters

    @Test("include filters to matching files only")
    func applyIncludeFilter() {
        let files = ["/root/Sources/a.swift", "/root/Tests/b.swift"]
        let filtered = collector.applyFilters(
            files: files,
            include: ["Sources/**"],
            exclude: [],
            rootPath: "/root",
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].contains("Sources"))
    }

    @Test("exclude removes matching files")
    func applyExcludeFilter() {
        let files = ["/root/a.swift", "/root/Generated.swift"]
        let filtered = collector.applyFilters(
            files: files,
            include: [],
            exclude: ["*Generated.swift"],
            rootPath: "/root",
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].hasSuffix("a.swift"))
    }

    @Test("empty include means no restriction")
    func emptyInclude() {
        let files = ["/root/a.swift", "/root/b.swift"]
        let filtered = collector.applyFilters(
            files: files,
            include: [],
            exclude: [],
            rootPath: "/root",
        )
        #expect(filtered.count == 2)
    }

    @Test("include and exclude together use intersection")
    func includeAndExclude() {
        let files = [
            "/root/Sources/a.swift",
            "/root/Sources/Generated.swift",
            "/root/Tests/b.swift",
        ]
        let filtered = collector.applyFilters(
            files: files,
            include: ["Sources/**"],
            exclude: ["**/*Generated.swift"],
            rootPath: "/root",
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].hasSuffix("a.swift"))
    }

    // MARK: - ruleApplies

    @Test("empty include/exclude applies to all files")
    func ruleAppliesAll() {
        #expect(FileCollector.ruleApplies(include: [], exclude: [], to: "any/path.swift"))
    }

    @Test("include only applies to matching files")
    func ruleAppliesInclude() {
        #expect(FileCollector.ruleApplies(include: ["Sources/**"], exclude: [], to: "Sources/a.swift"))
        #expect(!FileCollector.ruleApplies(include: ["Sources/**"], exclude: [], to: "Tests/b.swift"))
    }

    @Test("exclude skips matching files")
    func ruleAppliesExclude() {
        #expect(FileCollector.ruleApplies(include: [], exclude: ["**/*Generated.swift"], to: "a.swift"))
        #expect(!FileCollector.ruleApplies(include: [], exclude: ["**/*Generated.swift"], to: "FooGenerated.swift"))
    }

    @Test("include and exclude together")
    func ruleAppliesBoth() {
        let include = ["Sources/**"]
        let exclude = ["**/*Generated.swift"]
        #expect(FileCollector.ruleApplies(include: include, exclude: exclude, to: "Sources/a.swift"))
        #expect(!FileCollector.ruleApplies(include: include, exclude: exclude, to: "Sources/FooGenerated.swift"))
        #expect(!FileCollector.ruleApplies(include: include, exclude: exclude, to: "Tests/b.swift"))
    }

    // MARK: - makeRelative

    @Test("strips root prefix from absolute path")
    func makeRelativeStripsPrefix() {
        #expect(FileCollector.makeRelative("/root/Sources/a.swift", to: "/root") == "Sources/a.swift")
    }

    @Test("returns path unchanged when root does not match")
    func makeRelativeNoMatch() {
        #expect(FileCollector.makeRelative("/other/b.swift", to: "/root") == "/other/b.swift")
    }

    @Test("handles file directly in root")
    func makeRelativeDirectChild() {
        #expect(FileCollector.makeRelative("/root/a.swift", to: "/root") == "a.swift")
    }

    @Test("trailing slash on root does not produce double slash")
    func makeRelativeTrailingSlash() {
        #expect(FileCollector.makeRelative("/root/Sources/a.swift", to: "/root/") == "Sources/a.swift")
    }

    // MARK: - collectSwiftFiles path normalization

    @Test("collected paths never contain double slashes")
    func collectSwiftFilesNoDoubleSlash() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let trailingSlashRoot = root.hasSuffix("/") ? root : root + "/"
            try "".write(toFile: "\(root)/a.swift", atomically: true, encoding: .utf8)

            let files = try collector.collectSwiftFiles(rootPath: trailingSlashRoot)
            #expect(files.count == 1)
            #expect(!files[0].contains("//"))
        }
    }
}
