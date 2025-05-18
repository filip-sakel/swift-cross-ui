/// A property wrapper updated by the view graph before each access to
/// ``View/body``. Conforming types should use internal mutability (see ``Box``)
/// to implement this protocol's non-mutable methods if required. This
/// protocol avoids mutation to allow state properties and such to be
/// captured even though views are structs.
public protocol DynamicProperty {
    /// Updates the property. Called by SwiftCrossUI before every access it
    /// makes to an ``App/body`` or ``View/body``.
    func update(
        with environment: EnvironmentValues,
        propertyName: String,
        previousValue: Self?
    )

    /// Update the dynamic properties of a value given a previous instance (if available).
    /// - Parameters:
    ///   - environment: The environment to use when updating the properties.
    ///   - previousValue: The previous value of the dynamic property. This is
    ///                 used to determine whether the property has changed.
    func _updateDynamicProperties(
        with environment: EnvironmentValues,
        propertyName: String,
        previousValue: Self?
    )

    /// Publishers to all the state properties that need to be
    /// observed. This is used to automatically cancel the subscriptions when the 
    // view is removed from the view graph.
    func _observeState() -> [_AnyStateProperty]
}

extension DynamicProperty {
    /// Updates the property. Called by SwiftCrossUI before every access it
    /// makes to an ``App/body`` or ``View/body``.
    /// A no-op by default.
    public func update(
        with environment: EnvironmentValues,
        propertyName: String,
        previousValue: Self?
    ) {}
}

#warning("Restore functionality for View, App, Shape + updateDynamicProperties")
#if !hasFeature(Embedded)
extension DynamicProperty {
    func _updateDynamicProperties(
        with environment: EnvironmentValues,
        previousValue: Self?
    ) -> [Publisher] {
        updateDynamicProperties(
            of: self,
            previousValue: previousValue,
            environment: environment
        )
    }

    func _observeState() -> [AnyStateProperty] {
        let mirror = Mirror(reflecting: self)
        var states: [AnyStateProperty] = []

        for property in mirror.children {
            if property.label == "state" && property.value is ObservableObject {
                print(
                    """

                    warning: The App.state protocol requirement has been removed in favour of
                                SwiftUI-style @State annotations. Decorate \(AppRoot.self).state
                                with the @State property wrapper to restore previous behaviour.

                    """
                )
            }

            guard let value = property.value as? StateProperty else {
                continue
            }

            states.append(value.erased())
        }

        return statePublishers
    }
}

/// Updates the dynamic properties of a value given a previous instance of the
/// type (if one exists) and the current environment.
func updateDynamicProperties<T>(
    of value: T,
    previousValue: T?,
    environment: EnvironmentValues
) {
    let newMirror = Mirror(reflecting: value)
    let previousMirror = previousValue.map(Mirror.init(reflecting:))

    if let previousChildren = previousMirror?.children {
        let propertySequence = zip(newMirror.children, previousChildren)
        for (newProperty, previousProperty) in propertySequence {
            guard
                let newValue = newProperty.value as? any DynamicProperty,
                let previousValue = previousProperty.value as? any DynamicProperty
            else {
                continue
            }

            updateDynamicProperty(
                newProperty: newValue,
                previousProperty: previousValue,
                environment: environment,
                enclosingTypeName: "\(T.self)",
                propertyName: newProperty.label
            )
        }
    } else {
        for property in newMirror.children {
            guard let newValue = property.value as? any DynamicProperty else {
                continue
            }

            updateDynamicProperty(
                newProperty: newValue,
                previousProperty: nil,
                environment: environment,
                enclosingTypeName: "\(T.self)",
                propertyName: property.label
            )
        }
    }
}

/// Updates a dynamic property. Required to unmask the concrete type of the
/// property. Since the two properties can technically be two different
/// types, Swift correctly wouldn't allow us to assume they're both the
/// same. So we unwrap one and then dynamically check whether the other
/// matches using a type cast.
private func updateDynamicProperty<Property: DynamicProperty>(
    newProperty: Property,
    previousProperty: (any DynamicProperty)?,
    environment: EnvironmentValues,
    enclosingTypeName: String,
    propertyName: String?
) {
    let castedPreviousProperty: Property?
    if let previousProperty {
        guard let previousProperty = previousProperty as? Property else {
            fatalError(
                """
                Supposedly unreachable... previous and current types of \
                \(enclosingTypeName).\(propertyName ?? "<unknown property>") \
                don't match.
                """
            )
        }

        castedPreviousProperty = previousProperty
    } else {
        castedPreviousProperty = nil
    }

    newProperty.update(
        with: environment,
        previousValue: castedPreviousProperty
    )
}

#endif