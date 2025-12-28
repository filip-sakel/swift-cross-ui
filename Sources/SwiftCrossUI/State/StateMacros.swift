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

@freestanding(expression)
public macro _environmentValuesContext() = 
    #externalMacro(module: "StateMacros", type: "EnvironmentValuesMacro")

// @attached(accessor)
// public macro Environment<Value>(_ keyPath: _const KeyPath<EnvironmentValues, Value>) =
//     #externalMacro(module: "StateMacros", type: "EnvironmentMacro")

@freestanding(expression)
public macro _typesStaticallyEqual<V>(_ arg1: V, _ arg2: V) -> Bool =
    #externalMacro(module: "StateMacros", type: "TypeEqualityMacro")
@freestanding(expression)
public macro _typesStaticallyEqual<V1, V2>(_ arg1: V1, _ arg2: V2) -> Bool =
    #externalMacro(module: "StateMacros", type: "TypeInequalityMacro")


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

public struct _EmptyEnvironment {
    public func _updateValue<Value>(_ value: Value, _propertyName: String) {}
}

@_transparent
@_disfavoredOverload
public func _isEnvironmentProperty<T>(_ prop: T) -> Bool { 
    false
}

@_transparent
public func _isEnvironmentProperty<Value>(_ prop: Environment<Value>) -> Bool {
    true
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
    // static var state2: State<String> = State(wrappedValue: "Hello")

    var body: EmptyView

    static var body: some View {
        Text("Hello, world!")
        .padding()
    }
}

extension KeyPath {
    public var __valueType: Value.Type {
        return Value.self
    }
}

@View 
struct MyView4: View {
    @State var state: String
    static let keyPath = \EnvironmentValues.colorScheme
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    static var state2: State<String> = State(wrappedValue: "Hello")

    var body: EmptyView

    var hello: ColorScheme {
        get {
            // #assert(#_typesStaticallyEqual((\EnvironmentValues.chooseFile).__valueType, ColorScheme.self))
            return _colorScheme.wrappedValue
        }
    }

    func body2() {
        colorScheme.defaultForegroundColor
    }
}

@View
struct MyPseudoView: View {
    @Environment(\.colorScheme) var scheme

    var body: some View {
        Text("Hello, world!")
            .padding()
            .foregroundColor(scheme.defaultForegroundColor)
    }
}

struct MyStruct {
    func useContext(_ context: Void = #_environmentValuesContext) {}

    func run() {
        // useContext()
        // useContext(#_environmentValuesContext)
    }
}

// struct Hello {
//     @Environment(\.colorScheme) var colorScheme
// }