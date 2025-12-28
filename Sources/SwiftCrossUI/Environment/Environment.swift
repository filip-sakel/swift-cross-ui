/// A property wrapper used to access environment values within a `View` or
/// `App`. Must not be used before the view graph accesses the view or app's
/// `body` (i.e. don't access it from an initializer).
///
/// ```
/// struct ContentView: View {
///     @Environment(\.colorScheme) var colorScheme
///
///     var body: some View {
///         Text("Current color scheme: \(colorScheme)")
///             .background(colorScheme == .light ? Color.black : Color.white)
///     }
/// }
/// ```
///
/// The environment also contains UI-related actions, such as the
/// ``EnvironmentValues/chooseFile`` action used to present 'Open file' dialogs.
///
/// ```
/// struct ContentView: View {
///     @Environment(\.chooseFile) var chooseFile
///
///     var body: some View {
///         Button("Open") {
///             Task {
///                 guard let file = await chooseFile() else {
///                     print("No file chosen")
///                     return
///                 }
///
///                 print("The user chose: \(file.path)")
///             }
///         }
///     }
/// }
/// ```
@propertyWrapper
public struct Environment<Value>: DynamicProperty {
    struct ReflectionStorage {
        let keyPath: KeyPath<EnvironmentValues, Value>
        var value: Box<Value?>

        func getValue() -> Value? {
            value.value
        }
        func getPropertyPath() -> String {
            "\(keyPath)"
        }
    }

    struct StaticStorage {
        var box: Box<(value: Value, propertyPath: String)?>

        func getValue() -> Value? {
            box.value?.value
        }
        func getPropertyPath() -> String {
            box.value?.propertyPath ?? "<unknown property>"
        }
    }

    #if !hasFeature(Embedded)
    var _storage: ReflectionStorage
    #else
    var _storage: StaticStorage
    #endif

    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        #if !hasFeature(Embedded)
        self._storage = ReflectionStorage(
            keyPath: keyPath,
            value: Box(value: nil)
        )
        #else
        self._storage = StaticStorage(
            box: Box(value: nil)
        )
        #endif
    }

    public func update(
        with environment: EnvironmentValues,
        propertyName: String,
        previousValue: Self?
    ) {
        #if !hasFeature(Embedded)
        _storage.value.value = environment[keyPath: _storage.keyPath]
        #endif
        // If we're in Embedded mode, the dynamic-property container will call 
        // `_updateValue(_: Value, _propertyPath: String)`
    }

    #if hasFeature(Embedded)
    @_documentation(visibility: private)
    public func _updateValue(_ value: Value, _propertyPath: String) {
        _storage.box.value = (value, _propertyPath)
    }
    #endif

    public var wrappedValue: Value {
        guard let value = _storage.getValue() else {
            fatalError(
                """
                Environment value \\.\(_storage.getPropertyPath()) used before initialization. Don't \
                use @Environment properties before SwiftCrossUI requests the \
                view's body.
                """
            )
        }
        return value
    }

    public func _updateDynamicProperties(with environment: EnvironmentValues, propertyName: String, previousValue: Environment<Value>?) {
        update(with: environment, propertyName: propertyName, previousValue: previousValue)
    }

    public func _observeState() -> [_AnyStateProperty] {
        []
    }
}
