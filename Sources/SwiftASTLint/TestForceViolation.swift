// Test file for self-hosted linter validation — DO NOT use in production

enum LogLevel {
    case debug
    case info
    case warning
    case error

    var description: String {
        switch self {
        case .debug: "debug"
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        }
    }
}
