/// A description
/// - Parameters:
///
@attached(extension, conformances: DynamicProperty, names: named(_observeState), named(_updateDynamicProperties))
public macro DynamicProperty() =
    #externalMacro(module: "StateMacros", type: "DynamicPropertyMacro")

// @attached(memberAttribute)
@attached(extension, conformances: View, names: named(_name), named(_observeState), named(_updateDynamicProperties))
public macro View(checkBody: _const Bool = true, checkConformance: _const Bool = true) =
    #externalMacro(module: "StateMacros", type: "ViewMacro")

// @attached(memberAttribute)
@attached(extension, conformances: App, names: named(_name), named(_observeState), named(_updateDynamicProperties))
public macro App() =
    #externalMacro(module: "StateMacros", type: "AppMacro")

// @attached(memberAttribute)
@attached(extension, conformances: Shape, names: named(_name), named(_observeState), named(_updateDynamicProperties))
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
struct MyView<T: View, U>: View {
    let name: String 
    @State var state: String
    let state2: State<String>

    var body: some View {
        Text("Hello, world!")
        .padding()
    }
}

@View(checkBody: false)
struct MyView2<T: View, U>: View, ElementaryView {
    struct MyVector {
        var x = 0.0
        var y = 0.0
    }

    @State var state: String
    let state2: State<String>
    let name: String 
    @State var myVec = MyVector()

    func update<Backend>(_ widget: Backend.Widget, proposedSize: SIMD2<Int>, environment: EnvironmentValues, backend: Backend, dryRun: Bool) -> ViewUpdateResult where Backend : AppBackend {
        fatalError()   
    }
    func asWidget<Backend>(backend: Backend) -> Backend.Widget where Backend : AppBackend {
        fatalError()
    }

    var xBinding: Binding<Double> {
        $myVec[dynamicMember: \.x]
    }
}

@View
struct MyView3: View {
    @State var state: String
    static var state2: State<String> = State(wrappedValue: "Hello")

    var body: EmptyView

    static var body: some View {
        Text("Hello, world!")
        .padding()
    }
}

@View 
struct MyView4: View {
    @State var state: String
    static var state2: State<String> = State(wrappedValue: "Hello")

    var body: EmptyView
}