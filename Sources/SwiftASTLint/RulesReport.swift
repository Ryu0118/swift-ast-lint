import Foundation

/// Builds machine- and human-readable reports of the rules registered in a ``RuleSet``,
/// resolved against an optional ``Configuration``. Backs the `rules` subcommand.
package enum RulesReportBuilder {
    /// Builds the report as a pretty-printed, sorted-keys JSON document.
    ///
    /// Top-level shape: `{"config_path": String|null, "rules": [entry...]}` where each entry has
    /// `id`, `description` (nullable), `parameterized`, `enabled`, `default_args`,
    /// `effective_args`, `include`, and `exclude`. Rules appear in registration order.
    package static func json(rules: RuleSet, config: Configuration?, configPath: String?) throws -> String {
        let report: [String: Any] = try [
            "config_path": configPath as Any? ?? NSNull(),
            "rules": entries(rules: rules, config: config),
        ]
        let data = try JSONSerialization.data(
            withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys],
        )
        // JSONSerialization always emits valid UTF-8; the fallback is unreachable in practice.
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    /// Builds the report as human-readable text.
    package static func text(rules: RuleSet, config: Configuration?, configPath: String?) -> String {
        var lines: [String] = []
        if let configPath {
            lines.append("config: \(configPath)")
            lines.append("")
        }
        for rule in rules.rules {
            let state = config?.disabledRules.contains(rule.id) == true ? "disabled" : "enabled"
            let kind = rule.isParameterized ? "parameterized" : "no arguments"
            lines.append("\(rule.id)  (\(kind), \(state))")
            if let description = rule.description {
                lines.append("    \(description)")
            }
            let ruleConfig = config?.rules[rule.id]
            if rule.isParameterized {
                lines.append("    default args:   \(compactJSON(of: rule, argsYAML: nil))")
                lines.append("    effective args: \(compactJSON(of: rule, argsYAML: ruleConfig?.argsYAML))")
            }
            if let include = ruleConfig?.include, !include.isEmpty {
                lines.append("    include: \(include.joined(separator: ", "))")
            }
            if let exclude = ruleConfig?.exclude, !exclude.isEmpty {
                lines.append("    exclude: \(exclude.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private static func entries(rules: RuleSet, config: Configuration?) throws -> [[String: Any]] {
        try rules.rules.map { rule in
            let ruleConfig = config?.rules[rule.id]
            return try [
                "id": rule.id,
                "description": rule.description as Any? ?? NSNull(),
                "parameterized": rule.isParameterized,
                "enabled": !(config?.disabledRules.contains(rule.id) ?? false),
                "default_args": rule.resolvedArgumentsJSONObject(argsYAML: nil),
                "effective_args": rule.resolvedArgumentsJSONObject(argsYAML: ruleConfig?.argsYAML),
                "include": ruleConfig?.include ?? [],
                "exclude": ruleConfig?.exclude ?? [],
            ]
        }
    }

    private static func compactJSON(of rule: any RuleProtocol, argsYAML: String?) -> String {
        guard let object = try? rule.resolvedArgumentsJSONObject(argsYAML: argsYAML),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }
}
