/// Severity level for a lint diagnostic.
public enum Severity: String, Sendable, Comparable {
    case warning
    case error

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs == .warning && rhs == .error
    }
}
