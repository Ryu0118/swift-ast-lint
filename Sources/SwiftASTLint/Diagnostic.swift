public struct Diagnostic: Sendable, Equatable, Comparable {
    public let ruleID: String
    public let severity: Severity
    public let message: String
    public let filePath: String
    public let line: Int
    public let column: Int

    public var formatted: String {
        "\(filePath):\(line):\(column): \(severity.rawValue): [\(ruleID)] \(message)"
    }

    public static func < (lhs: Diagnostic, rhs: Diagnostic) -> Bool {
        if lhs.filePath != rhs.filePath { return lhs.filePath < rhs.filePath }
        return lhs.line < rhs.line
    }
}
