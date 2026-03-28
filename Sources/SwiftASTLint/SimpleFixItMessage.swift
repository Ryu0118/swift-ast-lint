import SwiftDiagnostics

/// A simple `FixItMessage` for rule authors to describe what a fix does.
public struct SimpleFixItMessage: FixItMessage, Sendable {
    public let message: String
    public var fixItID: MessageID {
        MessageID(domain: "SwiftASTLint", id: message)
    }

    /// Creates a fix-it message with the given description.
    public init(_ message: String) {
        self.message = message
    }
}
