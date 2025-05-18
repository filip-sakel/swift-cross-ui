import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    var diagnosticID: MessageID { .init(domain: "ViewMacro", id: message) }
}


func extractStructDecl(from typeDecl: some DeclGroupSyntax, macroName: String) throws -> StructDeclSyntax {
    guard let structDecl = typeDecl.as(StructDeclSyntax.self) else {
        throw CustomError("Only structs can use @\(macroName).")
    }
    return structDecl
}

func extractDynamicProperties(structDecl: StructDeclSyntax, context: some MacroExpansionContext) -> [String] {
    let memberList = structDecl.memberBlock.members
    var dynamicProps: [String] = []

    for member in memberList {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        for binding in varDecl.bindings {
            guard let identPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            // Skip properties with accessors
            guard binding.accessorBlock == nil else { continue }
            // Skip static properties
            guard !varDecl.modifiers.contains(where: { $0.name.text == "static" }) else { continue }

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
    }
    return dynamicProps
}

func createNameMember(structDecl: StructDeclSyntax, type: some TypeSyntaxProtocol, context: some MacroExpansionContext) -> DeclSyntax {
    // Attempt to extract generic parameters if the type is generic
    let genericParams: [String]
    if let genericType = structDecl.genericParameterClause {
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
    let typeName = "\(type)\(genericsSuffix)"

    let nameMethod: DeclSyntax = """
        public static func _name() -> String {
            return "\(raw: typeName)"
        }
        """
    return nameMethod
}

func createObserveMethod(structDecl: StructDeclSyntax, dynamicProps: [String], context: some MacroExpansionContext) -> DeclSyntax {
    let observeMethod: DeclSyntax = """
        public func _observeState() -> [_AnyStateProperty] {
            var observers: [_AnyStateProperty] = []
            \(raw: dynamicProps.map {
                """
                    _processDynamicProperty(self.\($0)) { observers.append(contentsOf: $0._observeState()) }
                """
            }.joined(separator: "\n"))
            return observers
        }
        """

    return observeMethod
}

func createUpdateMethod(structDecl: StructDeclSyntax, prelude: StmtSyntax? = nil, acceptsSourceName: Bool, dynamicProps: [String], context: some MacroExpansionContext) -> DeclSyntax {
    let envParam = "with environment: EnvironmentValues"
    let prevParam = "previousValue: Self?"

    let sourceParam = acceptsSourceName ? "propertyName: String, " : ""

    let sourceName: ExprSyntax = acceptsSourceName ? #"(propertyName + ".") + "# : ""

    let updateMethod: DeclSyntax = """
        public func _updateDynamicProperties(\(raw: envParam),\(raw:sourceParam)\(raw: prevParam)) {
            \(prelude)
            \(raw: dynamicProps.map {
                """
                    _processDynamicProperty(self.\($0)) { 
                        $0._updateDynamicProperties(
                            with: environment, 
                            propertyName: \(sourceName)"\($0)", 
                            previousValue: previousValue?.\($0)
                        ) 
                    }
                """
            }.joined(separator: "\n"))
        }
        """

    return updateMethod
}

func assertNoConformance(
    structDecl: StructDeclSyntax,
    protocolName: String,
    macroName: String,
    context: some MacroExpansionContext
) -> Bool {
    // Check if the struct already conforms to the protocol
    let conformsToProtocol = structDecl.inheritanceClause?.inheritedTypes.contains { conformance in
        guard let type = conformance.type.as(IdentifierTypeSyntax.self) else { return false }
        return type.name.text == protocolName
    } ?? false

    if conformsToProtocol {
        context.diagnose(
            Diagnostic(
                node: structDecl.name,
                message: SimpleDiagnosticMessage(
                    message: "Type '\(structDecl.name)' redeclares conformance to '\(protocolName)' that's implied by the '\(macroName)' attribute.",
                    severity: .error
                )
            )
        )
    }

    return conformsToProtocol
}

func createDynamicPropertyExtension(
    protocolName: String,
    typeDecl: some DeclGroupSyntax,
    type: some TypeSyntaxProtocol,
    context: some MacroExpansionContext
) throws -> (structDecl: StructDeclSyntax, extensionDecl: ExtensionDeclSyntax) {
    let structDecl = try extractStructDecl(from: typeDecl, macroName: protocolName)

    // Check if the struct already conforms to the protocol
    let conformsToProtocol = assertNoConformance(
        structDecl: structDecl, 
        protocolName: protocolName, macroName: "@\(protocolName)", 
        context: context
    )
    
    // Get the dynamic properties
    let dynamicProps = extractDynamicProperties(structDecl: structDecl, context: context)

    // Create the requirements
    let updateMethod = createUpdateMethod(
        structDecl: structDecl, 
        // Containers don't have a "sourceName"; they're the source.
        acceptsSourceName: false, 
        dynamicProps: dynamicProps, 
        context: context
    )
    let observeMethod = createObserveMethod(structDecl: structDecl, dynamicProps: dynamicProps, context: context)
    let nameMethod = createNameMember(structDecl: structDecl, type: type, context: context)

    // Create the extension declaration
    let inheritenceClause = conformsToProtocol ? "" : ": \(protocolName)"
    let extensionDecl: DeclSyntax = """
    extension \(raw: type.trimmed)\(raw: inheritenceClause) {
        \(updateMethod)
        \(observeMethod)
        \(nameMethod)
    }
    """

    return (structDecl, ExtensionDeclSyntax(extensionDecl)!)
}

func annotateBuilderProperty(
    decl: some DeclSyntaxProtocol,
    propertyName: String,
    builderMacroName: String,
    context: some MacroExpansionContext
) -> AttributeSyntax? {
    // Check if the property is the one with `propertyName`
    guard let varDecl = decl.as(VariableDeclSyntax.self),
          let binding = varDecl.bindings.first,
          let identPattern = binding.pattern.as(IdentifierPatternSyntax.self),
          identPattern.identifier.trimmedDescription == propertyName,
          // Check if the property is not static
          !varDecl.modifiers.contains(where: { $0.name.text == "static" }),
          // Check that the property is a computed property
          let accessorBlock = binding.accessorBlock
    else {
        return nil
    }

    // Warn if the property's accessor is not a getter
    guard case .getter = accessorBlock.accessors else {
        context.diagnose(
            Diagnostic(
                node: decl,
                message: SimpleDiagnosticMessage(
                    message: "Cannot annotate property \(propertyName) with @\(builderMacroName) because it's not a getter.",
                    severity: .warning
                )
            )
        )
        return nil
    }

    // Check that there's only one binding before we apply the macro; otherwise warn the user.
    guard varDecl.bindings.count == 1 else {
        context.diagnose(
            Diagnostic(
                node: decl,
                message: SimpleDiagnosticMessage(
                    message: "Cannot annotate property \(propertyName) with @\(builderMacroName) because it's declared alongside other properties.",
                    severity: .warning
                )
            )
        )
        return nil
    }

    let builderAttr: AttributeSyntax = "@\(raw: builderMacroName)"

    // Check if the property is already annotated with the builder macro
    if varDecl.attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == builderMacroName }) {
        return nil
    }

    return builderAttr
}