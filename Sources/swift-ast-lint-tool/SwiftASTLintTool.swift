import ArgumentParser

@main
struct SwiftASTLintTool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftastlinttool",
        abstract: "Swift AST Lint scaffolding tool",
        version: SwiftASTLintToolVersion.current,
        subcommands: [InitCommand.self],
    )
}
