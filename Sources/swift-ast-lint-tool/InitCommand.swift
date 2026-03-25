import ArgumentParser
import SwiftASTLintScaffold
import Foundation

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Generate a new linter package"
    )

    @Option(name: .long, help: "Directory to generate the linter package")
    var path: String?

    @Option(name: .long, help: "Package name (defaults to directory name)")
    var name: String?

    func run() async throws {
        let targetPath: String

        if let path {
            targetPath = path
        } else {
            Swift.print("Enter the path for the linter package (default: ./MyLinter):", terminator: " ")
            if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
                targetPath = input
            } else {
                targetPath = "./MyLinter"
            }
        }

        let resolvedPath = (targetPath as NSString).standardizingPath
        let packageName = name ?? (resolvedPath as NSString).lastPathComponent

        try await Scaffold.generate(at: resolvedPath, name: packageName)
        Swift.print("Generated linter package '\(packageName)' at \(resolvedPath)")
    }
}
