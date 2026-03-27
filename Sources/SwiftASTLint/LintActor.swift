/// Global actor that serializes all lint execution (rule checks and context mutation).
@globalActor
public actor LintActor {
    /// Shared instance.
    public static let shared = LintActor()
}
