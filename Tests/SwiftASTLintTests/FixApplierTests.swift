@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import Testing

@Suite("FixApplier applies SourceEdits from FixIts to source text correctly")
struct FixApplierTests {
    @Test("no fix-its returns original source")
    func emptyFixIts() {
        let source = "let x = 1\n"
        let (result, count) = FixApplier.applyFixes(fixIts: [], to: source)
        #expect(result == source)
        #expect(count == 0)
    }

    @Test("single node replacement via FixIt.Change.replace")
    @LintActor
    func singleReplace() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.cast(VariableDeclSyntax.self))
        let letKeyword = varDecl.bindingSpecifier
        let newKeyword = letKeyword.with(\.tokenKind, .keyword(.let))

        let fixIt = FixIt(
            message: SimpleFixItMessage("Use let"),
            changes: [.replace(oldNode: Syntax(letKeyword), newNode: Syntax(newKeyword))],
        )

        let (result, count) = FixApplier.applyFixes(fixIts: [fixIt], to: source)
        #expect(result == "let x = 1\n")
        #expect(count == 1)
    }

    @Test("multiple non-overlapping replacements applied correctly")
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

    @Test("overlapping edits skip the second one")
    @LintActor
    func overlappingEditsSkipped() throws {
        let source = "var x = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.cast(VariableDeclSyntax.self))

        // Both try to replace the same token
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

    @Test("multibyte UTF-8 source is handled correctly")
    @LintActor
    func multibyte() throws {
        let source = "var 名前 = 1\n"
        let tree = Parser.parse(source: source)
        let varDecl = try #require(tree.statements.first?.item.cast(VariableDeclSyntax.self))
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
}
