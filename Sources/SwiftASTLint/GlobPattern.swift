import Foundation

public enum GlobPattern {
    public static func matches(pattern: String, path: String) -> Bool {
        let regex = convertToRegex(pattern)
        return path.range(of: regex, options: .regularExpression) != nil
    }

    public static func matchesAny(patterns: [String], path: String) -> Bool {
        patterns.contains { matches(pattern: $0, path: path) }
    }

    private static func convertToRegex(_ pattern: String) -> String {
        guard !pattern.isEmpty else { return "(?!)" }

        var regex = "^"
        var i = pattern.startIndex

        while i < pattern.endIndex {
            let c = pattern[i]
            switch c {
            case "*":
                let next = pattern.index(after: i)
                if next < pattern.endIndex && pattern[next] == "*" {
                    let afterStars = pattern.index(after: next)
                    if afterStars < pattern.endIndex && pattern[afterStars] == "/" {
                        regex += "(.+/)?"
                        i = pattern.index(after: afterStars)
                        continue
                    } else {
                        regex += ".*"
                        i = pattern.index(after: next)
                        continue
                    }
                } else {
                    regex += "[^/]*"
                }
            case "?":
                regex += "[^/]"
            case ".":
                regex += "\\."
            default:
                regex += String(c)
            }
            i = pattern.index(after: i)
        }

        regex += "$"
        return regex
    }
}
