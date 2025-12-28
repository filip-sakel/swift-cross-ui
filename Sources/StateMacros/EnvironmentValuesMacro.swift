import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

public struct EnvironmentValuesMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax, 
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        context.diagnose(Diagnostic(
            node: node, 
            message: SimpleDiagnosticMessage(
                message: "Lexical context: \(context.lexicalContext)", 
                severity: .error
            )
        ))
        return "()"
    }
}