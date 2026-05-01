@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import Testing

@Suite("FixApplier applies SourceEdits from FixIts to source text correctly")
struct FixApplierTests {
    // MARK: - Basic cases

    @Test("no fix-its returns original source unchanged")
    func emptyFixIts() {
        let source = "let x = 1\n"
        let (result, appliedCount) = FixApplier.applyFixes(fixIts: [], to: source)
        #expect(result == source)
        #expect(appliedCount == 0)
    }

    @Test("empty source with no fix-its returns empty string")
    func emptySource() {
        let (result, appliedCount) = FixApplier.applyFixes(fixIts: [], to: "")
        #expect(result.isEmpty)
        #expect(appliedCount == 0)
    }

    // MARK: - Single replacement

    @Test("single token replacement via FixIt.Change.replace")
    func singleReplace() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier
        let newKeyword = keyword.with(\.tokenKind, .keyword(.let))

        let fixIt = FixIt(
            message: SimpleFixItMessage("Use let"),
            changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let x = 1\n")
        #expect(count == 1)
    }

    // MARK: - Multiple non-overlapping

    @Test("multiple non-overlapping replacements on separate lines")
    func multipleNonOverlapping() {
        let source = "var a = 1\nvar b = 2\n"
        let tree = Parser.parse(source: source)

        var fixIts: [FixIt] = []
        for stmt in tree.statements {
            let varDecl = stmt.item.cast(VariableDeclSyntax.self)
            let keyword = varDecl.bindingSpecifier
            let newKeyword = keyword.with(\.tokenKind, .keyword(.let))
            fixIts.append(
                FixIt(
                    message: SimpleFixItMessage("Use let"),
                    changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword))],
                ),
            )
        }

        let (result, count) = FixApplier.applyFixes(fixIts: fixIts, to: source)
        #expect(result == "let a = 1\nlet b = 2\n")
        #expect(count == 2)
    }

    // MARK: - Overlapping

    @Test("overlapping edits skip the later one")
    func overlappingEditsSkipped() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier

        let fixIt1 = FixIt(
            message: SimpleFixItMessage("Fix 1"),
            changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(keyword.with(\.tokenKind, .keyword(.let))))],
        )
        let fixIt2 = FixIt(
            message: SimpleFixItMessage("Fix 2"),
            changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(keyword.with(\.tokenKind, .keyword(.let))))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt1, fixIt2], to: source)
        #expect(result == "let x = 1\n")
        #expect(count == 1)
    }

    // MARK: - UTF-8 multibyte

    @Test("multibyte UTF-8 identifiers are handled correctly")
    func multibyte() throws {
        let source = "var 名前 = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier
        let newKeyword = keyword.with(\.tokenKind, .keyword(.let))

        let fixIt = FixIt(
            message: SimpleFixItMessage("Use let"),
            changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let 名前 = 1\n")
        #expect(count == 1)
    }

    // MARK: - Node deletion

    @Test("deleting a node via replaceText with empty string removes it from source")
    func nodeRemoval() throws {
        let source = "let x: Int = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let typeAnnotation = try #require(binding.typeAnnotation)

        let fixIt = FixIt(
            message: SimpleFixItMessage("Remove type annotation"),
            changes: [
                .replaceText(
                    range: typeAnnotation.position ..< typeAnnotation.endPosition,
                    with: "",
                    in: Syntax(tree),
                ),
            ],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(!result.contains(": Int"))
        #expect(count == 1)
    }

    // MARK: - Replacement text longer/shorter than original

    @Test("replacement text shorter than original preserves surrounding content")
    func shorterReplacement() throws {
        let source = "var longName = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let identifier = binding.pattern.cast(IdentifierPatternSyntax.self)
        let oldToken = identifier.identifier
        let newToken = TokenSyntax(
            .identifier("x"),
            leadingTrivia: oldToken.leadingTrivia,
            trailingTrivia: oldToken.trailingTrivia,
            presence: .present,
        )
        let newIdentifier = identifier.with(\.identifier, newToken)

        let fixIt = FixIt(
            message: SimpleFixItMessage("Shorten name"),
            changes: [.replace(oldNode: Syntax(identifier), newNode: Syntax(newIdentifier))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "var x = 1\n")
        #expect(count == 1)
    }

    @Test("replacement text longer than original preserves surrounding content")
    func longerReplacement() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let identifier = binding.pattern.cast(IdentifierPatternSyntax.self)
        let oldToken = identifier.identifier
        let newToken = TokenSyntax(
            .identifier("longVariableName"),
            leadingTrivia: oldToken.leadingTrivia,
            trailingTrivia: oldToken.trailingTrivia,
            presence: .present,
        )
        let newIdentifier = identifier.with(\.identifier, newToken)

        let fixIt = FixIt(
            message: SimpleFixItMessage("Lengthen name"),
            changes: [.replace(oldNode: Syntax(identifier), newNode: Syntax(newIdentifier))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "var longVariableName = 1\n")
        #expect(count == 1)
    }

    // MARK: - Multiple changes in one FixIt

    @Test("single FixIt with multiple non-overlapping changes applies all")
    func multipleChangesInOneFixIt() {
        let source = "var a = 1\nvar b = 2\n"
        let tree = Parser.parse(source: source)
        let stmts = Array(tree.statements)

        var changes: [FixIt.Change] = []
        for stmt in stmts {
            let varDecl = stmt.item.cast(VariableDeclSyntax.self)
            let keyword = varDecl.bindingSpecifier
            let newKeyword = keyword.with(\.tokenKind, .keyword(.let))
            changes.append(.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword)))
        }

        let fixIt = FixIt(message: SimpleFixItMessage("Use let everywhere"), changes: changes)
        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let a = 1\nlet b = 2\n")
        #expect(count == 2)
    }

    // MARK: - Trivia replacement

    @Test("replaceLeadingTrivia removes extra spaces")
    func replaceLeadingTrivia() throws {
        let source = "  let x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier

        let fixIt = FixIt(
            message: SimpleFixItMessage("Remove indent"),
            changes: [.replaceLeadingTrivia(token: keyword, newTrivia: [])],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let x = 1\n")
        #expect(count == 1)
    }

    @Test("replaceTrailingTrivia normalizes whitespace")
    func replaceTrailingTrivia() throws {
        let source = "let   x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier

        let fixIt = FixIt(
            message: SimpleFixItMessage("Normalize space"),
            changes: [.replaceTrailingTrivia(token: keyword, newTrivia: .space)],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let x = 1\n")
        #expect(count == 1)
    }

    // MARK: - O(n) deduplication invariant

    @Test("three edits: third overlaps first but not second, O(n) algorithm rejects via transitivity")
    func transitivityInvariant() {
        // Source must be at least 130 UTF-8 bytes; use a long comment as filler.
        // Byte layout (all ASCII so byte offset == character offset):
        //   [0..<60)   — untouched prefix
        //   [60..<105) — edit 3 range (spans into edit 1's range; should be rejected)
        //   [70..<80)  — edit 2 range (accepted; lastAcceptedLowerBound becomes 70)
        //   [100..<130) — edit 1 range (accepted first; lastAcceptedLowerBound becomes 100)
        //   [130..)    — tail
        let source = String(repeating: "A", count: 150)
        let tree = Parser.parse(source: source)
        let root = Syntax(tree)

        let fixIt1 = FixIt(
            message: SimpleFixItMessage("Edit 1"),
            changes: [.replaceText(
                range: AbsolutePosition(utf8Offset: 100) ..< AbsolutePosition(utf8Offset: 130),
                with: "1",
                in: root,
            )],
        )
        let fixIt2 = FixIt(
            message: SimpleFixItMessage("Edit 2"),
            changes: [.replaceText(
                range: AbsolutePosition(utf8Offset: 70) ..< AbsolutePosition(utf8Offset: 80),
                with: "2",
                in: root,
            )],
        )
        // Edit 3 overlaps edit 1 ([100..<130)); the O(n) algorithm detects this because
        // edit 3's upperBound (105) > lastAcceptedLowerBound (70) after edit 2 is accepted.
        let fixIt3 = FixIt(
            message: SimpleFixItMessage("Edit 3"),
            changes: [.replaceText(
                range: AbsolutePosition(utf8Offset: 60) ..< AbsolutePosition(utf8Offset: 105),
                with: "3",
                in: root,
            )],
        )

        let (_, count) = FixApplier.applyFixes(fixIts: [fixIt1, fixIt2, fixIt3], to: source)
        // Only edits 1 and 2 are applied; edit 3 is rejected because it overlaps edit 1.
        #expect(count == 2)
    }

    @Test("adjacent half-open ranges that share a boundary are both applied")
    func touchingBoundaryBothApplied() {
        // "AAAAABBBBB": bytes [0..<5) replaced with "X", bytes [5..<10) replaced with "Y".
        // The ranges share the boundary at offset 5 but do not overlap under half-open semantics.
        let source = "AAAAABBBBB"
        let tree = Parser.parse(source: source)
        let root = Syntax(tree)

        let fixIt1 = FixIt(
            message: SimpleFixItMessage("Replace first half"),
            changes: [.replaceText(
                range: AbsolutePosition(utf8Offset: 0) ..< AbsolutePosition(utf8Offset: 5),
                with: "X",
                in: root,
            )],
        )
        let fixIt2 = FixIt(
            message: SimpleFixItMessage("Replace second half"),
            changes: [.replaceText(
                range: AbsolutePosition(utf8Offset: 5) ..< AbsolutePosition(utf8Offset: 10),
                with: "Y",
                in: root,
            )],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt1, fixIt2], to: source)
        #expect(count == 2)
        #expect(result == "XY")
    }
}
