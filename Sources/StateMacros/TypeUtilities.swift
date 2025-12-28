import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

// No-op; types are equal for this to be called
public struct TypeEqualityMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax, 
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        return "true"
    }
}

// Throw error in parent decl.
public struct TypeInequalityMacro: ExpressionMacro {
    struct TypeInequalityError: Error {
        let message: String
    }
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax, 
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        // context.diagnose(Diagnostic(
        //     node: node, //context.lexicalContext.dropLast().last ?? Syntax(node),
        //     message: SimpleDiagnosticMessage(
        //         message: "Types are not equal.",
        //         severity: .error
        //     )
        // ))
        return "false"
    }
}