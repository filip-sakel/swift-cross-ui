import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

public struct AppMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let (_, extDecl) = try createDynamicPropertyExtension(
            protocolName: "App",
            typeDecl: declaration,
            type: type,
            context: context
        )

        return [extDecl]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let attribute = annotateBuilderProperty(
            decl: declaration,
            propertyName: "body",
            builderMacroName: "SceneBuilder",
            context: context
        ) else {
            return []
        }

        return [attribute] + ["@MainActor"]
    }
}