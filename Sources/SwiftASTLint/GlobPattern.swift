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
        var index = pattern.startIndex

        while index < pattern.endIndex {
            let char = pattern[index]
            let (fragment, nextIndex) = convertCharacter(char, in: pattern, at: index)
            regex += fragment
            index = nextIndex
        }

        regex += "$"
        return regex
    }

    private static func convertCharacter(
        _ char: Character,
        in pattern: String,
        at index: String.Index,
    ) -> (fragment: String, nextIndex: String.Index) {
        switch char {
        case "*":
            handleStar(in: pattern, at: index)
        case "?":
            ("[^/]", pattern.index(after: index))
        case ".":
            ("\\.", pattern.index(after: index))
        default:
            (String(char), pattern.index(after: index))
        }
    }

    private static func handleStar(
        in pattern: String,
        at index: String.Index,
    ) -> (fragment: String, nextIndex: String.Index) {
        let next = pattern.index(after: index)
        guard next < pattern.endIndex, pattern[next] == "*" else {
            return ("[^/]*", pattern.index(after: index))
        }
        // Double star **
        let afterStars = pattern.index(after: next)
        if afterStars < pattern.endIndex, pattern[afterStars] == "/" {
            return ("(.+/)?", pattern.index(after: afterStars))
        }
        return (".*", afterStars)
    }
}
