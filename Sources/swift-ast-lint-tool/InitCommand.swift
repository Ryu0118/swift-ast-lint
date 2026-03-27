import ArgumentParser
import Foundation
import Logging
import SwiftASTLintScaffold

private let logger = Logger(label: "swiftastlinttool")

struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Generate a new linter package",
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
            // swiftlint:disable:next no_raw_print
            Swift.print("Enter the path for the linter package (default: ./MyLinter):", terminator: " ")
            if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
                targetPath = input
            } else {
                targetPath = "./MyLinter"
            }
        }

        let resolvedURL = URL(filePath: targetPath).standardized
        let resolvedPath = resolvedURL.path(percentEncoded: false)
        let packageName = name ?? resolvedURL.lastPathComponent

        do {
            try await Scaffold().generate(at: resolvedPath, name: packageName)
            logger.info("Generated linter package '\(packageName)' at \(resolvedPath)")
        } catch {
            logger.error("\(error)")
            throw ExitCode(1)
        }
    }
}
