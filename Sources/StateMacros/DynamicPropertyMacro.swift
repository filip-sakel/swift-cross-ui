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

        let envParam = "with environment: EnvironmentValues"
        let prevParam = "previousValue: Self?"
        let updateMethod = """
        public func _updateDynamicProperties(\(envParam), \(prevParam)) {
            self.update(with: environment, previousValue: previousValue)
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

        let ext: DeclSyntax = """
        extension \(raw: type.trimmed): DynamicProperty {
            \(raw: updateMethod)
            \(raw: observeMethod)
        }
        """

        return [ExtensionDeclSyntax(ext)!]
    }
}

struct CustomError: Error, CustomStringConvertible {
    var description: String
    init(_ desc: String) { self.description = desc }
}