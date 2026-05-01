import SwiftDiagnostics

/// A lint diagnostic produced by a rule.
public struct Diagnostic: Sendable, Comparable {
    /// Rule identifier that produced the diagnostic.
    public let ruleID: String
    /// Diagnostic severity.
    public let severity: Severity
    /// Human-readable diagnostic message.
    public let message: String
    /// Absolute or display path of the source file.
    public let filePath: String
    /// One-based source line.
    public let line: Int
    /// One-based source column.
    public let column: Int
    /// Fix-its associated with this diagnostic.
    public let fixIts: [FixIt]
    /// Whether this diagnostic has an autofix available.
    public let isFixable: Bool

    /// Creates a diagnostic.
    public init(
        ruleID: String,
        severity: Severity,
        message: String,
        filePath: String,
        line: Int,
        column: Int,
        fixIts: [FixIt] = [],
        isFixable: Bool? = nil,
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.line = line
        self.column = column
        self.fixIts = fixIts
        self.isFixable = isFixable ?? !fixIts.isEmpty
    }

    /// Diagnostic formatted for plain text output.
    public var formatted: String {
        let fixable = isFixable ? " [fixable]" : ""
        return "\(filePath):\(line):\(column): \(severity.rawValue): [\(ruleID)] \(message)\(fixable)"
    }

    /// Orders diagnostics by file path and line.
    public static func < (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.filePath != rhs.filePath { return lhs.filePath < rhs.filePath }
        return lhs.line < rhs.line
    }
}

extension Diagnostic: Equatable {
    /// Compares diagnostics by user-visible fields and fixability.
    public static func == (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        lhs.ruleID == rhs.ruleID
            && lhs.severity == rhs.severity
            && lhs.message == rhs.message
            && lhs.filePath == rhs.filePath
            && lhs.line == rhs.line
            && lhs.column == rhs.column
            && lhs.isFixable == rhs.isFixable
    }
}
