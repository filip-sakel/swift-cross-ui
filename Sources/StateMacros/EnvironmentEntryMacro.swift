import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin
import SwiftDiagnostics

public struct EnvironmentEntryMacro: AccessorMacro, PeerMacro {
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