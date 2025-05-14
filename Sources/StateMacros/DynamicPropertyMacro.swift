import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public struct DynamicPropertyMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let structDecl = try extractStructDecl(from: declaration, macroName: "DynamicProperty")
        let dynamicProps = extractDynamicProperties(structDecl: structDecl, context: context)

        // Create update method
        let selfUpdateStatement: StmtSyntax = """
            self.update(with: environment, previousValue: previousValue)
        """
        let updateMethod = createUpdateMethod(structDecl: structDecl, prelude: selfUpdateStatement, dynamicProps: dynamicProps, context: context)

        // Create observe method
        let observeMethod = createObserveMethod(structDecl: structDecl, dynamicProps: dynamicProps, context: context)

        // Create extension decl
        let extDecl: DeclSyntax = """
        extension \(raw: type.trimmed): DynamicProperty {
            \(updateMethod)
            \(observeMethod)
        }
        """

        return [ExtensionDeclSyntax(extDecl)!]
    }
}

struct CustomError: Error, CustomStringConvertible {
    var description: String
    init(_ desc: String) { self.description = desc }
}