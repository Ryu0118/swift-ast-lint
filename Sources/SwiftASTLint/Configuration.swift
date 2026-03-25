public struct Configuration: Sendable, Equatable {
    public let includedPaths: [String]
    public let excludedPaths: [String]

    public init(includedPaths: [String] = [], excludedPaths: [String] = []) {
        self.includedPaths = includedPaths
        self.excludedPaths = excludedPaths
    }
}
