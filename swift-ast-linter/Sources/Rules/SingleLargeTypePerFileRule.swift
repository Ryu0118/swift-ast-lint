import SwiftASTLint
import SwiftSyntax

struct SingleLargeTypeArgs: Codable {
    var warningLines: Int = 50
    var errorLines: Int = 100

    enum CodingKeys: String, CodingKey {
        case warningLines = "warning_lines"
        case errorLines = "error_lines"
    }
}

let singleLargeTypePerFileRule = ParameterizedRule(
    id: "single-large-type-per-file",
    defaultArguments: SingleLargeTypeArgs(),
) { file, context, args in
    let converter = context.sourceLocationConverter
    let largeTypes = file.statements.compactMap { stmt -> (decl: any DeclGroupSyntax, lines: Int)? in
        guard let decl = stmt.item.asTopLevelTypeDecl else { return nil }
        let startLine = converter.location(for: decl.memberBlock.leftBrace.positionAfterSkippingLeadingTrivia).line
        let endLine = converter.location(for: decl.memberBlock.rightBrace.positionAfterSkippingLeadingTrivia).line
        let bodyLines = endLine - startLine - 1
        return bodyLines >= args.warningLines ? (decl, bodyLines) : nil
    }
    guard largeTypes.count > 1 else { return }
    for (decl, bodyLines) in largeTypes {
        let severity: Severity = bodyLines >= args.errorLines ? .error : .warning
        context.report(
            on: decl,
            message: "Multiple large types (\(bodyLines) lines) in one file. Split into separate files.",
            severity: severity,
        )
    }
}

private extension SyntaxProtocol {
    var asTopLevelTypeDecl: (any DeclGroupSyntax)? {
        if let cls = self.as(ClassDeclSyntax.self) { return cls }
        if let str = self.as(StructDeclSyntax.self) { return str }
        if let enm = self.as(EnumDeclSyntax.self) { return enm }
        if let act = self.as(ActorDeclSyntax.self) { return act }
        return nil
    }
}
