import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

struct SimpleDiagnosticMessage: DiagnosticMessage {
    let message: String
    let severity: DiagnosticSeverity
    var diagnosticID: MessageID { .init(domain: "ViewMacro", id: message) }
}

var dynamicPropertyContainers: Set<String> {
    ["DynamicProperty", "View", "App", "Scene", "Shape"]
}

func extractStructDecl(from typeDecl: some DeclGroupSyntax, macroName: String) throws -> StructDeclSyntax {
    guard let structDecl = typeDecl.as(StructDeclSyntax.self) else {
        throw CustomError("Only structs can use @\(macroName).")
    }
    return structDecl
}

enum DynamicProp {
    case dynamicProperty(name: String)
    case environment(name: String, propertyPath: String)

    var asDynamicPropertyName: String? {
        switch self {
            case let .dynamicProperty(name):
                return name
            case .environment:
                return nil
        }
    }
}

func extractDynamicProperties(structDecl: StructDeclSyntax, context: some MacroExpansionContext) -> [DynamicProp] {
    let memberList = structDecl.memberBlock.members
    var dynamicProps: [DynamicProp] = []

    for member in memberList {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
            continue
        }

        for binding in varDecl.bindings {
            guard let identPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let propName = identPattern.identifier.text

            // Skip properties with accessors
            guard binding.accessorBlock == nil else { continue }
            // Skip static properties
            guard !varDecl.modifiers.contains(where: { $0.name.text == "static" }) else { continue }

            // Try to extract the property-wrapper name
            let wrapperAttr: AttributeSyntax? = varDecl.attributes
                .compactMap({ (attr) -> AttributeSyntax? in
                    // Get the attribute syntax
                    return attr.as(AttributeSyntax.self)
                })
                .first(where: { (attr) -> Bool in
                    // Check if the attribute name is potentially a dynamic property container
                    let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text
                    return attrName?.first?.isUppercase ?? false
                })

            switch wrapperAttr {
                case nil:
                    // Just add the regular property
                    dynamicProps.append(.dynamicProperty(name: propName))
                case let wrapperAttr? where wrapperAttr.attributeName.trimmedDescription != "Environment":
                    // Regular property wrapper (not @Environment)
                    //
                    // For property wrappers use the underlying property name not the generated one.
                    // E.g. @State var foo: String -> _foo
                    dynamicProps.append(.dynamicProperty(name: "_" + propName))
                    continue
                case let wrapperAttr?:
                    // It's the environment property wrapper
                    //
                    // Try to extract the key path
                    guard let envKeyPath = wrapperAttr.arguments?.as(LabeledExprListSyntax.self)?.first?.expression.as(KeyPathExprSyntax.self) else {
                        context.diagnose(
                            Diagnostic(
                                node: wrapperAttr,
                                message: SimpleDiagnosticMessage(
                                    message: "'@Environment' macro requires a static key-path literal argument.",
                                    severity: .error
                                )
                            )
                        )
                        break
                    }
                    // Get the path to the environment value dropping the leading "\EnvironmentValues."
                    let envValuePath = envKeyPath.components.description.dropFirst().description
                    // Add the environment property
                    dynamicProps.append(.environment(name: "_" + propName, propertyPath: envValuePath))
            }
        }
    }
    // context.diagnose(Diagnostic(
    //     node: structDecl,
    //     message: SimpleDiagnosticMessage(
    //         message: "Dynamic properties found: \(dynamicProps)",
    //         severity: .error
    //     )
    // ))
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
        public nonisolated static func _name() -> String {
            return "\(raw: typeName)"
        }
        """
    return nameMethod
}

func createObserveMethod(structDecl: StructDeclSyntax, dynamicProps: [DynamicProp], context: some MacroExpansionContext) -> DeclSyntax {
    // The body of the method
    let body: StmtSyntax 

    let filteredDynamicProps = dynamicProps.compactMap(\.asDynamicPropertyName)

    if filteredDynamicProps.isEmpty {
        // If there are no dynamic properties, return an empty array
        body = """
                return []
            """
    } else {
        // Otherwise, create an array of observers
        body = """
                var observers: [_AnyStateProperty] = []
                \(raw: filteredDynamicProps.map {
                    """
                        _processDynamicProperty(self.\($0)) { observers.append(contentsOf: $0._observeState()) }
                    """
                }.joined(separator: "\n"))
                return observers
            """
    }

    let observeMethod: DeclSyntax = """
        public func _observeState() -> [_AnyStateProperty] {
        \(body)
        }
        """

    return observeMethod
}

func createUpdateMethod(structDecl: StructDeclSyntax, prelude: StmtSyntax? = nil, acceptsSourceName: Bool, dynamicProps: [DynamicProp], context: some MacroExpansionContext) -> DeclSyntax {
    let envParam = "with environment: EnvironmentValues"
    let prevParam = "previousValue: Self?"

    let sourceParam = acceptsSourceName ? "propertyName: String, " : ""

    let sourceName: ExprSyntax = acceptsSourceName ? #"(propertyName + ".") + "# : ""

    func generateStatementForDynamicProperty(_ prop: DynamicProp) -> String {
        switch prop {
            case let .dynamicProperty(name):
                return """
                    _processDynamicProperty(self.\(name)) { 
                        $0._updateDynamicProperties(
                            with: environment, 
                            propertyName: \(sourceName)"\(name)", 
                            previousValue: previousValue?.\(name)
                        ) 
                    }
                    #assert(!_isEnvironmentProperty(self.\(name)), "Dynamic property '\(name)' should not be an environment property.")
                """
            case let .environment(name, propertyPath):
                return """
                    self.\(name)._updateValue(environment.\(propertyPath), _propertyPath: "\(propertyPath)")
                """
        }
    }

    let updateMethod: DeclSyntax = """
        public func _updateDynamicProperties(\(raw: envParam),\(raw:sourceParam)\(raw: prevParam)) {
            \(prelude)
            \(raw: dynamicProps.map(generateStatementForDynamicProperty(_:)).joined(separator: "\n"))
        }
        """

    return updateMethod
}

func checkConformance(
    assertExists: Bool,
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

    if !conformsToProtocol && assertExists {
        context.diagnose(
            Diagnostic(
                node: structDecl.name,
                message: SimpleDiagnosticMessage(
                    message: "Type '\(structDecl.name)' doesn't declare conformance to '\(protocolName)' which is required by the '\(macroName)' attribute.",
                    severity: .error
                )
            )
        )
    }

    return conformsToProtocol
}

func createDynamicPropertyExtension(
    protocolName: String,
    assertConformance: Bool = true,
    typeDecl: some DeclGroupSyntax,
    type: some TypeSyntaxProtocol,
    context: some MacroExpansionContext
) throws -> (structDecl: StructDeclSyntax, extensionDecl: ExtensionDeclSyntax) {
    let structDecl = try extractStructDecl(from: typeDecl, macroName: protocolName)

    // Check if the struct already conforms to the protocol
    let conformsToProtocol = checkConformance(
        assertExists: assertConformance,
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

func annotateMainActor(
    decl: some DeclSyntaxProtocol,
    context: some MacroExpansionContext
) -> AttributeSyntax? {
    let attributes = decl.as(VariableDeclSyntax.self)?.attributes 
        ?? decl.as(FunctionDeclSyntax.self)?.attributes 
        ?? decl.as(InitializerDeclSyntax.self)?.attributes 
        ?? decl.as(SubscriptDeclSyntax.self)?.attributes

    let modifiers = decl.as(VariableDeclSyntax.self)?.modifiers 
        ?? decl.as(FunctionDeclSyntax.self)?.modifiers 
        ?? decl.as(InitializerDeclSyntax.self)?.modifiers 
        ?? decl.as(SubscriptDeclSyntax.self)?.modifiers

    // Check if it's a property, func, init, subscript
    guard decl.is(VariableDeclSyntax.self) ||
          decl.is(FunctionDeclSyntax.self) ||
          decl.is(InitializerDeclSyntax.self) ||
          decl.is(SubscriptDeclSyntax.self),
          let attributes, let modifiers
    else {
        return nil
    }

    // Check if the property is already annotated with @MainActor
    if attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "MainActor" }) {
        return nil
    }
    // Check if the property has `nonisolated` modifier
    if modifiers.contains(where: { $0.name.text == "nonisolated" }) { 
        return nil
    }

    return "@MainActor "
}

func annotateEnvironment(
    decl: some DeclSyntaxProtocol,
    context: some MacroExpansionContext
) -> AttributeSyntax? {
    // Get environment attribute
    guard let environmentAttribute = decl.as(VariableDeclSyntax.self)?.attributes.first?.as(AttributeSyntax.self) else {
        return nil
    }

    // Get wrapper props
    guard let wrapperProps = getPropertyWrapperProp(
        decl: decl, 
        propertyWrapperName: "Environment", 
        isMutable: false, acceptsInitializer: false, 
        context: context
    ) else {
        return nil
    }

    // Get the property wrapper properties
    let (accessModifier, name, type, _, _) = wrapperProps

    let storageName: TokenSyntax = "_\(name)"
    let storageType: TypeSyntax = "Environment<\(type ?? "_")>"

    // Set up fake storage to return in case of errors but to still allow the user to use the generated property
    let fakeAttribute: AttributeSyntax? = type.map { (type) -> AttributeSyntax in 
        """
        @_Environment<\(type)>(_propertyName: "", _getValue: { _ in fatalError("Invalid @_Environment should not have compiled.") })
        """
    }

    // Ensure there's an argument in order to extract the key path
    guard let arguments = environmentAttribute.arguments?.as(LabeledExprListSyntax.self) else {
        context.diagnose(Diagnostic(
            node: environmentAttribute,
            message: SimpleDiagnosticMessage(
                message: "'@Environment' macro requires a key-path literal argument.",
                severity: .error
            )
        ))
        return fakeAttribute
    }
    guard let keyPathArg = arguments.first, arguments.count == 1 else {
        context.diagnose(Diagnostic(
            node: arguments,
            message: SimpleDiagnosticMessage(
                message: "'@Environment' macro expects exactly one argument: a key-path literal to an environment value.",
                severity: .error
            )
        ))
        return fakeAttribute
    }

    // Extract the key path
    guard let keyPathSyntax = keyPathArg.expression.as(KeyPathExprSyntax.self) else {
        context.diagnose(Diagnostic(
            node: keyPathArg.expression,
            message: SimpleDiagnosticMessage(
                message: "'@Environment' macro expects a static key path-literal to an environment value (e.g. '@Environment(\\.myProp)') and not a key-path variable (e.g. '@Environment(myKeyPath)').",
                severity: .error
            )
        ))
        return fakeAttribute
    }
    let environmentValuePath = KeyPathComponentListSyntax(
        keyPathSyntax.components.dropFirst())

    // Create the actual attribute
    let newAttribute: AttributeSyntax = """
        @_Environment<\(type ?? "_")>(_propertyName: "\(environmentValuePath)", _getValue: { $0.\(environmentValuePath) })
        """
    return newAttribute
}