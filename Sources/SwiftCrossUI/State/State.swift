// import Foundation

@propertyWrapper
public struct State<Value>: DynamicProperty {
    class Storage {
        // This inner box is what stays constant between view updates. The
        // outer box (Storage) is used so that we can assign this box to
        // future state instances from the non-mutating
        // `update(with:previousValue:)` method. It's vital that the inner
        // box remains the same so that bindings can be stored across view
        // updates.
        var box: Box<Value>
        var didChange = Publisher()

        init(_ value: Value) {
            self.box = Box(value: value)
        }
    }

    var storage: Storage

    var didChange: Publisher {
        storage.didChange
    }

    public var wrappedValue: Value {
        get {
            storage.box.value
        }
        nonmutating set {
            storage.box.value = newValue
            didChange.send()
        }
    }

    public var projectedValue: Binding<Value> {
        // Specifically link the binding to the inner box instead of the outer
        // storage which changes with each view update.
        let box = storage.box
        return Binding(
            get: {
                box.value
            },
            set: { newValue in
                box.value = newValue
                didChange.send()
            }
        )
    }

    public init(wrappedValue initialValue: Value) {
        storage = Storage(initialValue)

        if let initialValue = initialValue as? ObservableObject {
            _ = didChange.link(toUpstream: initialValue.didChange)
        }
    }

    public func update(with environment: EnvironmentValues, previousValue: State<Value>?) {
        if let previousValue {
            storage.box = previousValue.storage.box
            storage.didChange = previousValue.storage.didChange
        }
    }
}

extension State: StateProperty {
    func tryRestoreFromSnapshot(_ snapshot: Data) {
        #if !hasFeature(Embedded)
        guard
            let decodable = Value.self as? Codable.Type,
            let state = try? JSONDecoder().decode(decodable, from: snapshot)
        else {
            return
        }

        storage.box.value = state as! Value
        #else 
        // TODO: Implement this for embedded platforms when Codable becomes available.
        return
        #endif
    }

    func snapshot() throws -> Data? {
        #if !hasFeature(Embedded)
        if let value = storage.box as? Codable {
            return try JSONEncoder().encode(value)
        } else {
            return nil
        }
        #else
        // TODO: Implement this for embedded platforms when Codable becomes available.
        return nil
        #endif
    }
}

extension State: _DynamicPropertyContainer {
    public func _updateDynamicProperties(with environment: EnvironmentValues, previousValue: State<Value>?) {
        update(with: environment, previousValue: previousValue)
    }

    public func _observeState() -> [_AnyStateProperty] {
        [erased()]
    }
}


/// A protocol that acts as a proxy for a state property.
protocol StateProperty {
    var didChange: Publisher { get }
    func tryRestoreFromSnapshot(_ snapshot: Data)
    func snapshot() throws -> Data?
}

/// A type-erased wrapper for a state property.
public struct _AnyStateProperty: StateProperty {
    var didChange: Publisher
    var snapshot: () throws -> Data?
    var tryRestoreFromSnapshot: (Data) -> Void

    init<P: StateProperty>(_ property: P) {
        self.didChange = property.didChange
        self.snapshot = { try property.snapshot() }
        self.tryRestoreFromSnapshot = { property.tryRestoreFromSnapshot($0) }
    }
}

extension StateProperty {
    /// Get the type-erased version of this state property.
    func erased() -> _AnyStateProperty {
        _AnyStateProperty(self)
    }
}
