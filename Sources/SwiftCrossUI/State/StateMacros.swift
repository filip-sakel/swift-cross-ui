/// A description
/// - Parameters:
///
@attached(extension, conformances: DynamicProperty)
public macro DynamicProperty() =
    #externalMacro(module: "StateMacros", type: "DynamicPropertyMacro")

@attached(extension, conformances: View)
public macro View() =
    #externalMacro(module: "StateMacros", type: "ViewMacro")

// public macro _DynamicPropertyContainer() =
//     #externalMacro(module: "StateMacros", type: "DynamicPropertyContainerMacro")


public struct _EmptyDynamicProperty {
    // To allow passing in previousValue?.value
    public func _updateDynamicProperties<T>(with environment: EnvironmentValues, previousValue: T?) {}

    // To match DynamicProperty protocol
    public func _observeState() -> [_AnyStateProperty] { [] }
}

// Handle the property as a no-op since it's not a dynamic property.
@_transparent
@_disfavoredOverload
public func _processDynamicProperty<T>(_ prop: T, _ process: (_EmptyDynamicProperty) -> Void) {}

// Handle the property by calling the process function since this is a dynamic property
@_transparent
public func _processDynamicProperty<T: DynamicProperty>(_ prop: T, _ process: (T) -> Void) {
    process(prop)
}

@_transparent
@_disfavoredOverload
public func _getGenericParameterViewNameOrDefault<T>(_ type: T.Type, name: String) -> String {
    name
}

@_transparent
public func _getGenericParameterViewNameOrDefault<T: View>(_ type: T.Type, name: String) -> String {
    type._name()
}

// enum _DynamicPropertyProxy<T> {
//     case empty 
//     case dynamicProp(
//         _updateDynamicPropertie: (_ environment: EnvironmentValues, _ previousValue: T?) -> Void,
//         _observeState: () -> [_AnyStateProperty])
//     init(_ prop: T) {
//         self = .empty
//     }

//     init(_ prop: T) where T: DynamicProperty {
//         self = .dynamicProp(
//             _updateDynamicPropertie: prop._updateDynamicProperties,
//             _observeState: prop._observeState)
//     }
// }



@DynamicProperty
struct MyDynProp {
    let value: String
    @State var state: String
}

@View
struct MyView<T: View, U> {
    @State var state: String
    let name: String 
    let state2: State<String>

    var body: some View {
        Text("Hello, world!")
        .padding()
    }
}
