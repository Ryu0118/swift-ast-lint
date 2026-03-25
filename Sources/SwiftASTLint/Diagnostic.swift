public struct Diagnostic: Sendable, Equatable, Comparable {
    public let ruleID: String
    public let severity: Severity
    public let message: String
    public let filePath: String
    public let line: Int
    public let column: Int

    public var formatted: String {
        let severityStr = severity == .error ? "error" : "warning"
        return "\(filePath):\(line):\(column): \(severityStr): [\(ruleID)] \(message)"
    }

    public static func < (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.filePath != rhs.filePath { return lhs.filePath < rhs.filePath }
        return lhs.line < rhs.line
    }
}
