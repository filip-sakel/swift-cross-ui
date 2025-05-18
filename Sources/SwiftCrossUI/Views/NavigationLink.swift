// TODO: This documentation could probably be clarified a bit more (potentially with
//   some practical examples).
/// A navigation primitive that appends a value to the current navigation path on click.
///
/// Unlike Apples SwiftUI API a `NavigationLink` can be outside of a `NavigationStack`
/// as long as they share the same `NavigationPath`.
@View(checkConformance: false)
public struct NavigationLink {
    @MainActor
    public var body: some View {
        Button(label) {
            path.wrappedValue.append(value)
        }
    }

    /// The label to display on the button.
    private let label: String
    #if !hasFeature(Embedded)
    /// The value to append to the navigation path when clicked.
    private let value: any Codable
    #else
    private let value: String
    #endif
    /// The navigation path to append to when clicked.
    private let path: Binding<NavigationPath>

    #if !hasFeature(Embedded)
    /// Creates a navigation link that presents the view corresponding to a value.
    /// The link is handled by whatever ``NavigationStack`` is sharing the same
    /// navigation path.
    public nonisolated init<C: Codable>(_ label: String, value: C, path: Binding<NavigationPath>) {
        self.label = label
        self.value = value
        self.path = path
    }
    #else
    /// Creates a navigation link that presents the view corresponding to a value.
    /// The link is handled by whatever ``NavigationStack`` is sharing the same
    /// navigation path.
    public nonisolated init(_ label: String, value: String, path: Binding<NavigationPath>) {
        self.label = label
        self.value = value
        self.path = path
    }
    #endif
}
