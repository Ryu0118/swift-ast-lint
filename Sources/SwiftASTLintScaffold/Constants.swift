enum Constants {
    // MARK: - Dependencies

    static let swiftASTLintURL = "https://github.com/Ryu0118/swift-ast-lint.git"
    static let swiftASTLintMinVersion = "0.1.0"

    static let swiftSyntaxURL = "https://github.com/swiftlang/swift-syntax.git"
    static let swiftSyntaxMinVersion = "600.0.0"
    static let swiftSyntaxMaxVersion = "700.0.0"

    // MARK: - Package Names

    static let swiftASTLintPackage = "swift-ast-lint"
    static let swiftSyntaxPackage = "swift-syntax"

    // MARK: - Targets

    static let rulesTarget = "Rules"
    static let executableTarget = "swift-ast-lint"
    static let testTarget = "RulesTests"

    // MARK: - Products

    static let swiftASTLintProduct = "SwiftASTLint"
    static let testSupportProduct = "SwiftASTLintTestSupport"
    static let swiftSyntaxProduct = "SwiftSyntax"

    // MARK: - Config

    /// Must match SwiftASTLintConstants.defaultConfigFileName in SwiftASTLint module
    static let configFileName = ".swift-ast-lint.yml"

    // MARK: - Templates

    static let mainSwift =
        """
        import SwiftASTLint
        import Rules

        await Linter.lint(rules)
        """

    static let rulesSwift =
        """
        import SwiftASTLint
        import SwiftSyntax

        public let rules = RuleSet {
            // Add your rules here
        }
        """

    static let rulesTestsSwift =
        """
        @testable import Rules
        import SwiftASTLint
        import SwiftASTLintTestSupport
        import Testing

        struct RulesTests {
            // Add your rule tests here
        }
        """

    static let ymlTemplate =
        """
        included_paths:
          - "Sources/**/*.swift"
        excluded_paths:
          - ".build/**"
        """
}
