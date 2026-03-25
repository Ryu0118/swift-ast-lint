import Testing
@testable import SwiftASTLint

@Suite("GlobPattern")
struct GlobPatternTests {
    @Test("basic star matching", arguments: [
        ("*.swift", "File.swift", true),
        ("*.swift", "File.txt", false),
        ("*.swift", "dir/File.swift", false),
    ])
    func starMatch(pattern: String, path: String, expected: Bool) {
        #expect(GlobPattern.matches(pattern: pattern, path: path) == expected)
    }

    @Test("double star matching", arguments: [
        ("**/*.swift", "File.swift", true),
        ("**/*.swift", "a/b/File.swift", true),
        ("**/*.swift", "File.txt", false),
        ("Sources/**/*.swift", "Sources/Foo/Bar.swift", true),
        ("Sources/**/*.swift", "Tests/Foo.swift", false),
        ("Sources/**", "Sources/a/b/c.swift", true),
    ])
    func doubleStarMatch(pattern: String, path: String, expected: Bool) {
        #expect(GlobPattern.matches(pattern: pattern, path: path) == expected)
    }

    @Test("question mark matching", arguments: [
        ("?.swift", "A.swift", true),
        ("?.swift", "AB.swift", false),
    ])
    func questionMarkMatch(pattern: String, path: String, expected: Bool) {
        #expect(GlobPattern.matches(pattern: pattern, path: path) == expected)
    }

    @Test("exact match", arguments: [
        ("Sources/File.swift", "Sources/File.swift", true),
        ("Sources/File.swift", "Sources/Other.swift", false),
    ])
    func exactMatch(pattern: String, path: String, expected: Bool) {
        #expect(GlobPattern.matches(pattern: pattern, path: path) == expected)
    }

    @Test("empty pattern matches nothing")
    func emptyPattern() {
        #expect(GlobPattern.matches(pattern: "", path: "File.swift") == false)
    }

    @Test("matchesAny with multiple patterns")
    func matchesAny() {
        #expect(GlobPattern.matchesAny(patterns: ["**/*.swift", "**/*.txt"], path: "a/b.swift") == true)
        #expect(GlobPattern.matchesAny(patterns: ["**/*.txt"], path: "a/b.swift") == false)
        #expect(GlobPattern.matchesAny(patterns: [], path: "a/b.swift") == false)
    }
}
