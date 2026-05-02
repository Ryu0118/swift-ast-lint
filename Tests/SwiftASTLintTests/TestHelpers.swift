import Logging
@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax

func makeLintContext(
    source: String,
    filePath: String = "test.swift",
    ruleID: String = "test",
) -> (SourceFileSyntax, LintContext) {
    let parsed = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: filePath, tree: parsed)
    let context = LintContext(
        filePath: filePath,
        sourceLocationConverter: converter,
        ruleID: ruleID,
    )
    return (parsed, context)
}

final class CapturingLogHandler: LogHandler, @unchecked Sendable {
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]
    private(set) var messages: [String] = []

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt,
    ) {
        messages.append(message.description)
    }
}

func makeCapturingLogger() -> (Logger, CapturingLogHandler) {
    let handler = CapturingLogHandler()
    let log = Logger(label: "test") { _ in handler }
    return (log, handler)
}

/// Creates a minimal FixIt for tests that only need to check isFixable/Equatable.
func makeStubFixIt() -> FixIt {
    let source = "var x = 1"
    let tree = Parser.parse(source: source)
    guard let token = tree.firstToken(viewMode: .sourceAccurate) else {
        preconditionFailure("stub source must parse to at least one token")
    }
    let newToken = token.with(\.tokenKind, .keyword(.let))
    return FixIt(
        message: SimpleFixItMessage("stub"),
        changes: [.replace(oldNode: Syntax(token), newNode: Syntax(newToken))],
    )
}
