import SwiftDiagnostics
import SwiftSyntax

/// Applies fix-its to source text using SwiftSyntax's `SourceEdit`.
public enum FixApplier {
    /// Collects `SourceEdit`s from the given fix-its and applies them to `source`.
    ///
    /// Edits are applied from the end of the file toward the beginning so that
    /// earlier byte offsets remain valid. Overlapping edits are skipped.
    ///
    /// - Returns: The fixed source text and the number of edits that were applied.
    public static func applyFixes(fixIts: [FixIt], to source: String) -> (result: String, appliedCount: Int) {
        var allEdits: [SourceEdit] = []
        for fixIt in fixIts {
            allEdits.append(contentsOf: fixIt.edits)
        }

        guard !allEdits.isEmpty else {
            return (source, 0)
        }

        allEdits.sort { $0.range.lowerBound.utf8Offset > $1.range.lowerBound.utf8Offset }

        // Edits are sorted by descending lowerBound, so lastAcceptedLowerBound is
        // always the minimum among accepted edits. If the current edit's upperBound
        // does not exceed it, the edit cannot reach any earlier accepted edit either.
        var applied: [SourceEdit] = []
        var lastAcceptedLowerBound: Int?
        for edit in allEdits {
            let upperBound = edit.range.upperBound.utf8Offset
            if let lastLower = lastAcceptedLowerBound, upperBound > lastLower {
                continue
            }
            applied.append(edit)
            lastAcceptedLowerBound = edit.range.lowerBound.utf8Offset
        }

        var utf8 = Array(source.utf8)
        for edit in applied {
            let start = edit.range.lowerBound.utf8Offset
            let end = edit.range.upperBound.utf8Offset
            utf8.replaceSubrange(start ..< end, with: edit.replacementBytes)
        }

        let result = String(bytes: utf8, encoding: .utf8) ?? source
        return (result, applied.count)
    }
}
