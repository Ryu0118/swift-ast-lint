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

    // MARK: - Products

    static let swiftASTLintProduct = "SwiftASTLint"
    static let swiftSyntaxProduct = "SwiftSyntax"

    // MARK: - Templates

    static let mainSwift =
        """
        import SwiftASTLint
        import Rules

        Linter.lint(rules)
        """

    static let rulesSwift =
        """
        import SwiftASTLint
        import SwiftSyntax

        public let rules = RuleSet {
            // Add your rules here
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
