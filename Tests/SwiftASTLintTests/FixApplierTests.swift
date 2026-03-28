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
        let (result, count) = FixApplier.applyFixes(fixIts: [], to: source)
        #expect(result == source)
        #expect(count == 0)
    }

    @Test("empty source with no fix-its returns empty string")
    func emptySource() {
        let (result, count) = FixApplier.applyFixes(fixIts: [], to: "")
        #expect(result.isEmpty)
        #expect(count == 0)
    }

    // MARK: - Single replacement

    @Test("single token replacement via FixIt.Change.replace")
    @LintActor
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
    @LintActor
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
    @LintActor
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
    @LintActor
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

    @Test("deleting a node (replacing with empty string) removes it from source")
    @LintActor
    func nodeRemoval() throws {
        let source = "let x: Int = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let typeAnnotation = try #require(binding.typeAnnotation)

        let fixIt = FixIt(
            message: SimpleFixItMessage("Remove type annotation"),
            changes: [.replace(oldNode: Syntax(typeAnnotation), newNode: Syntax("" as TokenSyntax))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(!result.contains(": Int"))
        #expect(count == 1)
    }

    // MARK: - Replacement text longer/shorter than original

    @Test("replacement text shorter than original preserves offsets for prior edits")
    @LintActor
    func shorterReplacement() throws {
        // "private var x = 1" -> "var x = 1" by replacing whole decl
        let source = "var longName = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let pattern = binding.pattern

        // Replace the pattern (identifier) with a shorter name
        let shortName = pattern.with(
            \.description,
            "x",
        )
        _ = shortName // We'll use a different approach for cleaner test

        // Instead test via SourceEdit directly: replace "longName" with "x"
        let identifier = pattern.cast(IdentifierPatternSyntax.self)
        let newIdentifier = identifier.with(\.identifier, .identifier("x"))

        let fixIt = FixIt(
            message: SimpleFixItMessage("Shorten name"),
            changes: [.replace(oldNode: Syntax(identifier), newNode: Syntax(newIdentifier))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "var x = 1\n")
        #expect(count == 1)
    }

    @Test("replacement text longer than original preserves surrounding content")
    @LintActor
    func longerReplacement() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.as(VariableDeclSyntax.self))
        let binding = try #require(varDecl.bindings.first)
        let identifier = binding.pattern.cast(IdentifierPatternSyntax.self)
        let newIdentifier = identifier.with(\.identifier, .identifier("longVariableName"))

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
    @LintActor
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
    @LintActor
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
    @LintActor
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
}
