import SwiftCompilerPlugin
import SwiftSyntaxMacros
@main
struct StateMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DynamicPropertyMacro.self,
        ViewMacro.self
        // DynamicPropertyContainerMacro.self,
    ]
}