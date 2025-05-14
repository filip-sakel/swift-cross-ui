/// A description
/// - Parameters:
///
@attached(extension, conformances: DynamicProperty)
public macro DynamicProperty() =
    #externalMacro(module: "StateMacros", type: "DynamicPropertyMacro")

@attached(extension, conformances: View)
public macro View(checkBody: _const Bool = true) =
    #externalMacro(module: "StateMacros", type: "ViewMacro")

@attached(extension, conformances: App)
public macro App() =
    #externalMacro(module: "StateMacros", type: "AppMacro")

@attached(extension, conformances: Shape)
public macro Shape() =
    #externalMacro(module: "StateMacros", type: "ShapeMacro")

// FIXME: Attach view builder to body if it's an implicit getter

// public macro _DynamicPropertyContainer() =
//     #externalMacro(module: "StateMacros", type: "DynamicPropertyContainerMacro")


public struct _EmptyDynamicProperty {
    // To allow passing in previousValue?.value
    public func _updateDynamicProperties<T>(with environment: EnvironmentValues, propertyName: String, previousValue: T?) {}

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

@DynamicProperty
struct MyDynProp {
    let value: String
    @State var state: String
}

@View
struct MyView<T: View, U> {
    let name: String 
    @State var state: String
    let state2: State<String>

    var body: some View {
        Text("Hello, world!")
        .padding()
    }
}

@View(checkBody: false)
struct MyView2<T: View, U>: ElementaryView {
    @State var state: String
    let state2: State<String>
    let name: String 

    func update<Backend>(_ widget: Backend.Widget, proposedSize: SIMD2<Int>, environment: EnvironmentValues, backend: Backend, dryRun: Bool) -> ViewUpdateResult where Backend : AppBackend {
        fatalError()   
    }
    func asWidget<Backend>(backend: Backend) -> Backend.Widget where Backend : AppBackend {
        fatalError()
    }
}