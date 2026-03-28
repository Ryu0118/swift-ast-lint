import SwiftDiagnostics

public struct Diagnostic: Sendable, Comparable {
    public let ruleID: String
    public let severity: Severity
    public let message: String
    public let filePath: String
    public let line: Int
    public let column: Int
    public let fixIts: [FixIt]

    public init(
        ruleID: String,
        severity: Severity,
        message: String,
        filePath: String,
        line: Int,
        column: Int,
        fixIts: [FixIt] = [],
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.filePath = filePath
        self.line = line
        self.column = column
        self.fixIts = fixIts
    }

    public var isFixable: Bool {
        !fixIts.isEmpty
    }

    public var formatted: String {
        let fixable = isFixable ? " [fixable]" : ""
        return "\(filePath):\(line):\(column): \(severity.rawValue): [\(ruleID)] \(message)\(fixable)"
    }

    public static func < (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.filePath != rhs.filePath { return lhs.filePath < rhs.filePath }
        return lhs.line < rhs.line
    }
}

extension Diagnostic: Equatable {
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
