import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    var diagnosticID: MessageID { .init(domain: "ViewMacro", id: message) }
}

public struct ViewMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CustomError("Only structs can use @DynamicProperty.")
        }

        let memberList = structDecl.memberBlock.members
        var dynamicProps: [String] = []

        for member in memberList {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let hasWrapperAttr = varDecl.attributes.contains(where: { attr in
                guard let attrName = attr.as(AttributeSyntax.self)?
                        .attributeName.as(IdentifierTypeSyntax.self)?
                        .name.text else { return false }
                return attrName.first?.isUppercase == true
            })

            // For property wrappers use the underlying property name not the generated one.
            // E.g. @State var foo: String -> _foo
            let namePrefix = hasWrapperAttr ? "_" : ""
            let name = namePrefix + identPattern.identifier.text
            dynamicProps.append(name)
        }

        // Check for `body` property
        var foundBody = false
        for member in memberList {
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
                    context.diagnose(
                        Diagnostic(
                            node: binding,
                            message: SimpleDiagnosticMessage(
                                message: "`body` must be a computed property with a `get` accessor",
                                severity: .error
                            )
                        )
                    )
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

        // Attempt to extract generic parameters if the type is generic
        let genericParams: [String]
        if let genericType = declaration.as(StructDeclSyntax.self)?.genericParameterClause {
            genericParams = genericType.parameters.map { param in
                let paramName = param.name.text
                return #"\(_getGenericParameterViewNameOrDefault(\#(paramName).self, name: "\#(paramName)"))"#
            }
        } else {
            genericParams = []
        }

        let genericsSuffix = genericParams.isEmpty
            ? ""
            : "<" + genericParams.joined(separator: ", ") + ">"

        let envParam = "with environment: EnvironmentValues"
        let prevParam = "previousValue: Self?"
        let updateMethod = """
        public func _updateDynamicProperties(\(envParam), \(prevParam)) {
            \(dynamicProps.map {
                """
                _processDynamicProperty(self.\($0)) { $0._updateDynamicProperties(with: environment, previousValue: previousValue?.\($0)) }
                """
            }.joined(separator: "\n"))
        }
        """

        let observeMethod = """
        public func _observeState() -> [_AnyStateProperty] {
            var observers: [_AnyStateProperty] = []
            \(dynamicProps.map {
                """
                _processDynamicProperty(self.\($0)) { observers.append(contentsOf: $0._observeState()) }
                """
            }.joined(separator: "\n"))
            return observers
        }
        """

        let nameMethod = """
        public static func _name() -> String {
            return "\(type.trimmed)\(genericsSuffix)"
        }
        """

        let ext: DeclSyntax = """
        extension \(raw: type.trimmed): View {
            \(raw: updateMethod)
            \(raw: observeMethod)
            \(raw: nameMethod)
        }
        """

        return [ExtensionDeclSyntax(ext)!]
    }
}