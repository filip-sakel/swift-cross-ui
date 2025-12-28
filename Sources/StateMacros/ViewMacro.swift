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
        // Get macro arguments
        var checkBody = true
        var checkConformance = true
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            if arguments.count > 2 {
                context.diagnose(
                    Diagnostic(
                        node: node,
                        message: SimpleDiagnosticMessage(
                            message: "At most two arguments are allowed for @View",
                            severity: .error
                        )
                    )
                )
            }
            for arg in arguments {
                if let label = arg.label?.text, label == "checkBody",
                let boolValue = arg.expression.as(BooleanLiteralExprSyntax.self) {
                    checkBody = boolValue.literal.text == "true"
                } else if let  label = arg.label?.text, label == "checkConformance",
                    let boolValue = arg.expression.as(BooleanLiteralExprSyntax.self) {
                    checkConformance = boolValue.literal.text == "true"
                } else {
                    context.diagnose(
                        Diagnostic(
                            node: arg,
                            message: SimpleDiagnosticMessage(
                                message: "Invalid argument for @View. Expected `checkBody: Bool` or `checkConformance: Bool`.",
                                severity: .error
                            )
                        )
                    )
                }
                
            }
        }

        // Create the extension declaration
        let (structDecl, extDecl) = try createDynamicPropertyExtension(
            protocolName: "View",
            assertConformance: checkConformance,
            typeDecl: declaration,
            type: type,
            context: context
        )

        // Check for `body` property
        if checkBody {
            var foundBody = false
            for member in structDecl.memberBlock.members {
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

                for binding in varDecl.bindings {
                    guard let ident = binding.pattern.as(IdentifierPatternSyntax.self),
                        ident.identifier.text == "body" else { continue }

                    foundBody = true

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
        // return [annotateEnvironment(decl: declaration, context: context)].compactMap({ $0 })
        // // let builderAttributes = annotateBuilderProperty(
        // //     decl: member,
        // //     propertyName: "body",
        // //     builderMacroName: "ViewBuilder",
        // //     context: context
        // // )

        // // let isolationAttributes = annotateMainActor(decl: member, context: context)

        // // return [isolationAttributes, builderAttributes].compactMap { $0 }
        let attr: AttributeSyntax = """
            @_Environment(_propertyName: "colorScheme", _getValue: { $0.colorScheme })
            """

        return [attr]
    }
}