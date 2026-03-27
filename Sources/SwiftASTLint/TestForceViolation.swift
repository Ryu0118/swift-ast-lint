// Test file for self-hosted linter validation — DO NOT use in production

/// 12 lines body → warning (>= 10, < 20)
struct SmallType {
    var val01: Int = 0
    var val02: Int = 0
    var val03: Int = 0
    var val04: Int = 0
    var val05: Int = 0
    var val06: Int = 0
    var val07: Int = 0
    var val08: Int = 0
    var val09: Int = 0
    var val10: Int = 0
    var val11: Int = 0
    var val12: Int = 0
}

/// 22 lines body → error (>= 20)
struct BigType {
    var val01: Int = 0
    var val02: Int = 0
    var val03: Int = 0
    var val04: Int = 0
    var val05: Int = 0
    var val06: Int = 0
    var val07: Int = 0
    var val08: Int = 0
    var val09: Int = 0
    var val10: Int = 0
    var val11: Int = 0
    var val12: Int = 0
    var val13: Int = 0
    var val14: Int = 0
    var val15: Int = 0
    var val16: Int = 0
    var val17: Int = 0
    var val18: Int = 0
    var val19: Int = 0
    var val20: Int = 0
    var val21: Int = 0
    var val22: Int = 0
}

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
