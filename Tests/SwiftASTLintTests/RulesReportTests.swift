import Foundation
@testable import SwiftASTLint
import Testing

@Suite("Rules report: rule metadata enumeration for the `rules` subcommand")
struct RulesReportTests {
    private struct DepthArgs: Codable, Sendable {
        var warningDepth: Int = 4
        var errorDepth: Int = 6

        enum CodingKeys: String, CodingKey {
            case warningDepth = "warning_depth"
            case errorDepth = "error_depth"
        }
    }

    private func makeRules() -> RuleSet {
        RuleSet {
            Rule(id: "no-force-try", description: "Flags force try expressions") { _, _ in }
            ParameterizedRule(id: "deep-nesting", defaultArguments: DepthArgs()) { _, _, _ in }
        }
    }

    private func report(
        rules: RuleSet,
        config: Configuration? = nil,
        configPath: String? = nil,
    ) throws -> [String: Any] {
        let json = try RulesReportBuilder.json(rules: rules, config: config, configPath: configPath)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try #require(object as? [String: Any])
    }

    private func ruleEntries(in report: [String: Any]) throws -> [[String: Any]] {
        try #require(report["rules"] as? [[String: Any]])
    }

    // MARK: - description metadata

    @Test("Rule stores an optional description, defaulting to nil")
    func ruleDescriptionDefaultsToNil() {
        let bare = Rule(id: "bare") { _, _ in }
        let described = Rule(id: "described", description: "Explains the rule") { _, _ in }
        #expect(bare.description == nil)
        #expect(described.description == "Explains the rule")
    }

    @Test("ParameterizedRule stores an optional description, defaulting to nil")
    func parameterizedRuleDescriptionDefaultsToNil() {
        let bare = ParameterizedRule(id: "bare", defaultArguments: DepthArgs()) { _, _, _ in }
        let described = ParameterizedRule(
            id: "described",
            description: "Explains the rule",
            defaultArguments: DepthArgs(),
        ) { _, _, _ in }
        #expect(bare.description == nil)
        #expect(described.description == "Explains the rule")
    }

    @Test("isParameterized distinguishes EmptyArguments from custom arguments")
    func isParameterized() {
        let plain = Rule(id: "plain") { _, _ in }
        let parameterized = ParameterizedRule(id: "custom", defaultArguments: DepthArgs()) { _, _, _ in }
        #expect(plain.isParameterized == false)
        #expect(parameterized.isParameterized == true)
    }

    // MARK: - JSON report without config

    @Test("JSON report without config lists all rules enabled with defaults")
    func jsonWithoutConfig() throws {
        let report = try report(rules: makeRules())
        #expect(report["config_path"] is NSNull)

        let entries = try ruleEntries(in: report)
        #expect(entries.count == 2)

        let plain = try #require(entries.first { $0["id"] as? String == "no-force-try" })
        #expect(plain["description"] as? String == "Flags force try expressions")
        #expect(plain["parameterized"] as? Bool == false)
        #expect(plain["enabled"] as? Bool == true)
        #expect((plain["default_args"] as? [String: Any])?.isEmpty == true)
        #expect((plain["include"] as? [String])?.isEmpty == true)
        #expect((plain["exclude"] as? [String])?.isEmpty == true)

        let parameterized = try #require(entries.first { $0["id"] as? String == "deep-nesting" })
        #expect(parameterized["description"] is NSNull)
        #expect(parameterized["parameterized"] as? Bool == true)
        let defaults = try #require(parameterized["default_args"] as? [String: Any])
        #expect(defaults["warning_depth"] as? Int == 4)
        #expect(defaults["error_depth"] as? Int == 6)
        let effective = try #require(parameterized["effective_args"] as? [String: Any])
        #expect(effective["warning_depth"] as? Int == 4)
        #expect(effective["error_depth"] as? Int == 6)
    }

    @Test("rules appear in RuleSet registration order")
    func registrationOrderIsPreserved() throws {
        let entries = try ruleEntries(in: report(rules: makeRules()))
        #expect(entries.map { $0["id"] as? String } == ["no-force-try", "deep-nesting"])
    }

    // MARK: - JSON report with config

    @Test("disabled_rules marks the rule as disabled")
    func disabledRuleIsReported() throws {
        let config = Configuration(disabledRules: ["no-force-try"])
        let entries = try ruleEntries(in: report(rules: makeRules(), config: config))
        let plain = try #require(entries.first { $0["id"] as? String == "no-force-try" })
        #expect(plain["enabled"] as? Bool == false)
        let parameterized = try #require(entries.first { $0["id"] as? String == "deep-nesting" })
        #expect(parameterized["enabled"] as? Bool == true)
    }

    @Test("YAML args override is reflected in effective_args but not default_args")
    func argsOverrideIsResolved() throws {
        let config = Configuration(
            rules: ["deep-nesting": RuleConfiguration(argsYAML: "warning_depth: 3\nerror_depth: 5\n")],
        )
        let entries = try ruleEntries(in: report(rules: makeRules(), config: config))
        let parameterized = try #require(entries.first { $0["id"] as? String == "deep-nesting" })
        let defaults = try #require(parameterized["default_args"] as? [String: Any])
        #expect(defaults["warning_depth"] as? Int == 4)
        let effective = try #require(parameterized["effective_args"] as? [String: Any])
        #expect(effective["warning_depth"] as? Int == 3)
        #expect(effective["error_depth"] as? Int == 5)
    }

    @Test("per-rule include/exclude globs are surfaced")
    func includeExcludeAreSurfaced() throws {
        let config = Configuration(
            rules: ["deep-nesting": RuleConfiguration(include: ["Sources/**"], exclude: ["**/*Generated.swift"])],
        )
        let entries = try ruleEntries(in: report(rules: makeRules(), config: config))
        let parameterized = try #require(entries.first { $0["id"] as? String == "deep-nesting" })
        #expect(parameterized["include"] as? [String] == ["Sources/**"])
        #expect(parameterized["exclude"] as? [String] == ["**/*Generated.swift"])
    }

    @Test("config_path is surfaced when provided")
    func configPathIsSurfaced() throws {
        let report = try report(rules: makeRules(), config: Configuration(), configPath: ".swift-ast-lint.yml")
        #expect(report["config_path"] as? String == ".swift-ast-lint.yml")
    }

    @Test("invalid args YAML falls back to defaults in effective_args")
    func invalidArgsYAMLFallsBackToDefaults() throws {
        let config = Configuration(
            rules: ["deep-nesting": RuleConfiguration(argsYAML: "warning_depth: [not, an, int]\n")],
        )
        let entries = try ruleEntries(in: report(rules: makeRules(), config: config))
        let parameterized = try #require(entries.first { $0["id"] as? String == "deep-nesting" })
        let effective = try #require(parameterized["effective_args"] as? [String: Any])
        #expect(effective["warning_depth"] as? Int == 4)
    }

    // MARK: - text format

    @Test("text report lists ids, enabled state, and args")
    func textReport() throws {
        let config = Configuration(disabledRules: ["no-force-try"])
        let text = RulesReportBuilder.text(rules: makeRules(), config: config, configPath: nil)
        #expect(text.contains("no-force-try"))
        #expect(text.contains("disabled"))
        #expect(text.contains("deep-nesting"))
        #expect(text.contains("warning_depth"))
        #expect(text.contains("Flags force try expressions"))
    }
}

@Suite("Root command dispatch: `rules` reaches the subcommand, bare paths reach LintCommand")
struct CommandDispatchTests {
    @Test("`rules` dispatches to RulesCommand instead of being consumed as a lint path")
    func rulesDispatchesToSubcommand() throws {
        let command = try Linter.parseAsRoot(["rules"])
        #expect(command is RulesCommand)
    }

    @Test("`rules --format text` parses the format option")
    func rulesParsesFormatOption() throws {
        let command = try Linter.parseAsRoot(["rules", "--format", "text"])
        #expect(command is RulesCommand)
    }

    @Test("bare paths and lint flags route to the default LintCommand")
    func barePathsRouteToLintCommand() throws {
        let command = try Linter.parseAsRoot(["Sources/", "--no-cache"])
        #expect(command is LintCommand)
    }

    @Test("no arguments routes to the default LintCommand")
    func noArgumentsRoutesToLintCommand() throws {
        let command = try Linter.parseAsRoot([])
        #expect(command is LintCommand)
    }

    @Test("explicit `lint` subcommand still parses paths and flags")
    func explicitLintSubcommand() throws {
        let command = try Linter.parseAsRoot(["lint", "Sources/", "--fix"])
        #expect(command is LintCommand)
    }
}
