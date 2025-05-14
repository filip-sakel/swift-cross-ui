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
            return \(literal: typeName)
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

func createUpdateMethod(structDecl: StructDeclSyntax, prelude: StmtSyntax? = nil, dynamicProps: [String], context: some MacroExpansionContext) -> DeclSyntax {
    let envParam = "with environment: EnvironmentValues"
    let prevParam = "previousValue: Self?"
    let updateMethod: DeclSyntax = """
        public func _updateDynamicProperties(\(raw: envParam), \(raw: prevParam)) {
            \(prelude)
            \(raw: dynamicProps.map {
                """
                    _processDynamicProperty(self.\($0)) { $0._updateDynamicProperties(with: environment, previousValue: previousValue?.\($0)) }
                """
            }.joined(separator: "\n"))
        }
        """

    return updateMethod
}

func createDynamicPropertyExtension(
    protocolName: String,
    typeDecl: some DeclGroupSyntax,
    type: some TypeSyntaxProtocol,
    context: some MacroExpansionContext
) throws -> (structDecl: StructDeclSyntax, extensionDecl: ExtensionDeclSyntax) {
    let structDecl = try extractStructDecl(from: typeDecl, macroName: protocolName)
    let dynamicProps = extractDynamicProperties(structDecl: structDecl, context: context)

    let updateMethod = createUpdateMethod(structDecl: structDecl, dynamicProps: dynamicProps, context: context)
    let observeMethod = createObserveMethod(structDecl: structDecl, dynamicProps: dynamicProps, context: context)
    let nameMethod = createNameMember(structDecl: structDecl, type: type, context: context)

    let extensionDecl: DeclSyntax = """
    extension \(raw: type.trimmed): \(raw: protocolName) {
        \(updateMethod)
        \(observeMethod)
        \(nameMethod)
    }
    """

    return (structDecl, ExtensionDeclSyntax(extensionDecl)!)
}