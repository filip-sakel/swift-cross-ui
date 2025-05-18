import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

public struct ViewMacro: ExtensionMacro, MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let (structDecl, extDecl) = try createDynamicPropertyExtension(
            protocolName: "View",
            typeDecl: declaration,
            type: type,
            context: context
        )

        // Get macro arguments
        var checkBody = true
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            if arguments.count > 1 {
                context.diagnose(
                    Diagnostic(
                        node: node,
                        message: SimpleDiagnosticMessage(
                            message: "Only one argument is allowed for @View",
                            severity: .error
                        )
                    )
                )
            }
            for arg in arguments {
                guard let label = arg.label?.text, label == "checkBody",
                let boolValue = arg.expression.as(BooleanLiteralExprSyntax.self) else {
                    context.diagnose(
                        Diagnostic(
                            node: arg,
                            message: SimpleDiagnosticMessage(
                                message: "Invalid argument for @View. Expected `checkBody: Bool`.",
                                severity: .error
                            )
                        )
                    )
                    continue
                }
                checkBody = boolValue.literal.text == "true"
            }
        }

        // Check for `body` property
        if checkBody {
            var foundBody = false
            for member in structDecl.memberBlock.members {
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

                for binding in varDecl.bindings {
                    guard let ident = binding.pattern.as(IdentifierPatternSyntax.self),
                        ident.identifier.text == "body" else { continue }

                    foundBody = true
                    break

                    if let accessorBlock = binding.accessorBlock {
                        let accessors = accessorBlock.accessors

                        switch accessors {
                        case .accessors(let declList):
                            // e.g. `var body { get }` or `var body { get set }`
                            let accessors = declList
                            guard accessors.count == 1,
                                let first = accessors.first,
                                first.accessorSpecifier.tokenKind == .keyword(.get) 
                            else {
                                context.diagnose(
                                    Diagnostic(
                                        node: accessors._syntaxNode,
                                        message: SimpleDiagnosticMessage(
                                            message: "`body` must have only a `get` accessor",
                                            severity: .error
                                        )
                                    )
                                )
                                break
                            }

                        case .getter:
                            // This is shorthand: `var body: some View { ... }` — implicitly get-only
                            break
                        }
                    } else {
                        // It's fine if it's just a let property too
                    }
                }
            }
            if !foundBody {
                context.diagnose(
                    Diagnostic(
                        node: structDecl.name,
                        message: SimpleDiagnosticMessage(
                            message: "Missing required `var body: some View { get }` declaration",
                            severity: .error
                        )
                    )
                )
            }
        }

        return [extDecl]
    }


    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let attribute = annotateBuilderProperty(
            decl: member,
            propertyName: "body",
            builderMacroName: "ViewBuilder",
            context: context
        ) else {
            return []
        }

        return [attribute]
    }
}