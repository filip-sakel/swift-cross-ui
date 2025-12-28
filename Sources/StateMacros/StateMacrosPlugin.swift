import SwiftCompilerPlugin
import SwiftSyntaxMacros
@main
struct StateMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DynamicPropertyMacro.self,
        ViewMacro.self,
        ShapeMacro.self,
        AppMacro.self,
        EnvironmentMacro.self,
        TypeEqualityMacro.self,
        TypeInequalityMacro.self,
        EnvironmentValuesMacro.self,
        EnvironmentEntryMacro.self,
    ]
}