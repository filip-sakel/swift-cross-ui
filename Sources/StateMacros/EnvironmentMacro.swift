import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

func getPropertyWrapperProp(
    decl: some DeclSyntaxProtocol, 
    propertyWrapperName: String,
    isMutable: Bool,
    acceptsInitializer: Bool,
    context: some MacroExpansionContext
) -> (
    accessModifier: DeclModifierSyntax?, 
    name: TokenSyntax, type: TypeSyntax?, 
    didSetBlock: AccessorDeclSyntax?, willSetBlock: AccessorDeclSyntax?
)? {
    // Ensure we're inside a struct
    if let structDecl = context.lexicalContext.last?.as(StructDeclSyntax.self) {
        // Check that struct is marked `@View` or conforms to `: View` or an equivalent protocol
        let usesViewMacro = !structDecl.attributes.contains(where: { 
            dynamicPropertyContainers.contains($0.as(AttributeSyntax.self)?.attributeName.trimmedDescription ?? "")
        })
        let conformsToView = structDecl.inheritanceClause?.inheritedTypes.contains(where: { 
            dynamicPropertyContainers.contains($0.type.trimmedDescription)
        }) ?? false

        // Diagnose if the struct is not a `@View`-like type
        if !usesViewMacro && !conformsToView {
            let structName = structDecl.name.text
            context.diagnose(Diagnostic(
                node: decl,
                message: SimpleDiagnosticMessage(
                    message: "'@\(propertyWrapperName)'-annotated variable declared in struct '\(structName)' which isn't a 'View'-like type.",
                    severity: .error
                )
            ))
            context.diagnose(Diagnostic(
                node: structDecl,
                message: SimpleDiagnosticMessage(
                    message: "Struct '\(structName)' must be a 'View'-like type in order to include '@\(propertyWrapperName)' variables.",
                    severity: .note
                )
            ))
        }
    } else if let otherDecl = context.lexicalContext.last?.as(DeclSyntax.self) {
        // Diagnose that decl isn't a struct

        context.diagnose(Diagnostic(
            node: decl,
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' variable declared in non-struct type.",
                severity: .error
            )
        ))
        context.diagnose(Diagnostic(
            node: otherDecl,
            message: SimpleDiagnosticMessage(
                message: "Only 'View'-like types can include '@\(propertyWrapperName)' variables.",
                severity: .note
            )
        ))
    } else {
        // No context means we're in a global context (i.e. not inside a struct)
        context.diagnose(Diagnostic(
            node: decl,
            message: SimpleDiagnosticMessage(
                message: "Found '@\(propertyWrapperName)' variable in global context but it should be declared inside a `@View`-like struct.",
                severity: .error
            )
        ))
    } 

    // Ensure the base decl is a variable decl
    guard let varDecl = decl.as(VariableDeclSyntax.self),
          let binding: PatternBindingSyntax = varDecl.bindings.first 
    else {
        context.diagnose(Diagnostic(
            node: decl,
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' can only be attached to a variable declaration.",
                severity: .error
            )
        ))
        return nil
    }

    // Ensure it's one binding
    if varDecl.bindings.count != 1 {
        context.diagnose(Diagnostic(
            // Attach error to the additional bindings
            node: PatternBindingListSyntax(varDecl.bindings.dropFirst()),
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' can only be attached to one variable at a time.",
                severity: .error
            )
        ))
    }
    
    // Ensure it's an identifier pattern
    guard let bindingPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        context.diagnose(Diagnostic(
            // Attach error to the additional bindings
            node: binding.pattern,
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' can only be attached to a variable with an identifier.",
                severity: .error
            )
        ))
        // We can't generate anything if we don't know the variable name
        return nil
    }
    let identifier = bindingPattern.identifier.trimmed

    // Ensure the var decl has no accessors other than didSet, willSet
    var didSetBlock: AccessorDeclSyntax? = nil
    var willSetBlock: AccessorDeclSyntax? = nil
    if let accessorBlock = binding.accessorBlock {
        switch accessorBlock.accessors {
        case .getter:
            context.diagnose(Diagnostic(
                node: accessorBlock.accessors,
                message: SimpleDiagnosticMessage(
                    message: "'@\(propertyWrapperName)' variable cannot have a getter accessor; it will be automatically generated.",
                    severity: .error
                )
            ))
        case .accessors(let accessorList):
            // Gather the willSet/didSet blocks (could be in any order)
            for accessor: AccessorDeclListSyntax.Element in accessorList {
                if accessor.accessorSpecifier == .keyword(.willSet) {
                    willSetBlock = accessor
                } else if accessor.accessorSpecifier == .keyword(.didSet) {
                    didSetBlock = accessor
                } else {
                    context.diagnose(Diagnostic(
                        node: accessor,
                        message: SimpleDiagnosticMessage(
                            message: "'@\(propertyWrapperName)' variable cannot have any accessors; they'll be automatically generated.",
                            severity: .error
                        )
                    ))
                }
            }

            // Ensure we don't have any accessors if the property wrapper is immutable
            if !isMutable && (willSetBlock != nil || didSetBlock != nil) {
                context.diagnose(Diagnostic(
                    node: accessorList,
                    message: SimpleDiagnosticMessage(
                        message: "'@\(propertyWrapperName)' variable is immutable and cannot have willSet/didSet accessors.",
                        severity: .error
                    )
                ))
            }
        } 
    }

    // Ensure no other attributes are attached
    if varDecl.attributes.contains(where: { 
        $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription != propertyWrapperName
    }) {
        context.diagnose(Diagnostic(
            node: varDecl.attributes,
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' variable cannot have other attributes.",
                severity: .error
            )
        ))
    }

    // Ensure no unknown modifiers are present (anything other than access-control modifiers)]
    let accessControlModifiers: Set<String> = [
        "private", "fileprivate", "package", "internal", "public", "open"
    ]
    var accessModifier: DeclModifierSyntax? = nil
    for modifier in varDecl.modifiers {
        if !accessControlModifiers.contains(modifier.name.text) {
            context.diagnose(Diagnostic(
                node: modifier,
                message: SimpleDiagnosticMessage(
                    message: "'@\(propertyWrapperName)' variable cannot have non access-control modifiers (i.e. public, private, etc.).",
                    severity: .error
                )
            ))
        } else {
            // Save the access modifier
            accessModifier = modifier
        }
    }

    // Extract the type
    let type: TypeSyntax?
    if let extractedType = binding.typeAnnotation?.type {
        type = extractedType
    } else {
        // If no type annotation, we can't generate anything
        // context.diagnose(Diagnostic(
        //     node: binding,
        //     message: SimpleDiagnosticMessage(
        //         message: "'@\(propertyWrapperName)' variable must have a type annotation.",
        //         severity: .error
        //     )
        // ))
        type = nil
    }

    // Check if there's an initial value and diagnose if it's not allowed
    if let initializer = binding.initializer, !acceptsInitializer {
        context.diagnose(Diagnostic(
            node: initializer,
            message: SimpleDiagnosticMessage(
                message: "'@\(propertyWrapperName)' variable cannot have an initial value.",
                severity: .error
            )
        ))
    }

    // Return the props
    return (
        accessModifier: accessModifier, 
        name: identifier, type: type, 
        didSetBlock: didSetBlock, willSetBlock: willSetBlock
    )
}

public struct EnvironmentMacro: AccessorMacro, PeerMacro {
    static func getWrapperProps(decl: some DeclSyntaxProtocol, context: some MacroExpansionContext) -> (
        accessModifier: DeclModifierSyntax?,
        name: TokenSyntax, type: TypeSyntax?,
        didSetBlock: AccessorDeclSyntax?, willSetBlock: AccessorDeclSyntax?
    )? {
        // Get the property wrapper properties
        getPropertyWrapperProp(
            decl: decl, propertyWrapperName: "Environment", 
            isMutable: false, acceptsInitializer: false, 
            context: context
        )
    }

    public static func expansion(
        of node: AttributeSyntax, 
        providingPeersOf declaration: some DeclSyntaxProtocol, 
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // // Get the property wrapper properties
        // guard let wrapperProps = getWrapperProps(decl: declaration, context: context) else {
        //     // If we can't get basic wrapper properties, we can't generate anything
        //     return []
        // }
        // let (_, name, type, _, _) = wrapperProps
        // let storageName: TokenSyntax = "_\(name)"
        // let storageType: TypeSyntax = "Environment<\(type ?? "_")>"

        // // Set up fake storage to return in case of errors but to still allow the user to use the generated property
        // let fakeStorage: DeclSyntax = """
        //     private var \(storageName): \(storageType) = Environment(_propertyName: \(literal: name.description), _getValue: { _ in
        //         fatalError("@Environment value '\(name)' should never have compiled.")
        //     })
        //     """

        // // Ensure there's an argument in order to extract the key path
        // guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
        //     context.diagnose(Diagnostic(
        //         node: node,
        //         message: SimpleDiagnosticMessage(
        //             message: "'@Environment' macro requires a key-path literal argument.",
        //             severity: .error
        //         )
        //     ))
        //     return [fakeStorage]
        // }
        // guard let keyPathArg = arguments.first, arguments.count == 1 else {
        //     context.diagnose(Diagnostic(
        //         node: arguments,
        //         message: SimpleDiagnosticMessage(
        //             message: "'@Environment' macro expects exactly one argument: a key-path literal to an environment value.",
        //             severity: .error
        //         )
        //     ))
        //     return [fakeStorage]
        // }

        // // Extract the key path
        // guard let keyPathSyntax = keyPathArg.expression.as(KeyPathExprSyntax.self) else {
        //     context.diagnose(Diagnostic(
        //         node: keyPathArg.expression,
        //         message: SimpleDiagnosticMessage(
        //             message: "'@Environment' macro expects a static key path-literal to an environment value (e.g. '@Environment(\\.myProp)') and not a key-path variable (e.g. '@Environment(myKeyPath)').",
        //             severity: .error
        //         )
        //     ))
        //     return [fakeStorage]
        // }
        // let environmentValuePath = keyPathSyntax.components

        // // Create underlying storage property
        // let storage: DeclSyntax = """
        //    private var \(storageName): \(storageType) = \(storageType)(_propertyName: "\(name)", _getValue: { $0\(environmentValuePath) })
        // """

        // return [storage]

        // No-op; the real environment macro is implemented as a property-wrapper
        return []
    }

    public static func expansion(
        of node: AttributeSyntax, 
        providingAccessorsOf declaration: some DeclSyntaxProtocol, 
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        // Get the property wrapper properties
        guard let wrapperProps = getWrapperProps(decl: declaration, context: context) else {
            // If we can't get basic wrapper properties, we can't generate anything
            return []
        }
        let (_, name, _, _, _) = wrapperProps
        let storageName: TokenSyntax = "_\(name)"

        // let keyPath = node.arguments!.as(LabeledExprListSyntax.self)!.first!.expression.as(KeyPathExprSyntax.self)!.components

        // let hello = Swift.type(of: \String.count.hashValue).valueType.self
        // Create the getter
        let getter: AccessorDeclSyntax = """
            get { 
                \(storageName).wrappedValue 
            }
        """

        // Return the getter
        return [getter]   
    }
}