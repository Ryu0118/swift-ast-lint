import ArgumentParser

@main
struct SwiftASTLintTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swiftastlinttool",
        abstract: "Swift AST Lint scaffolding tool",
        subcommands: [InitCommand.self]
    )
}
