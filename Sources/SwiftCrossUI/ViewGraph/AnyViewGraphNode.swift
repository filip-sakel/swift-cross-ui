/// A type-erased ``ViewGraphNode``. Used by implementations of ``ViewGraphNodeChildren``
/// to avoid leaking the selected backend into ``View`` implementations (which would be
/// an annoying complexity for users of the library and it worth the slight sacrifice
/// in performance and strong-typing). The user never sees such type-erased wrappers.
@MainActor
public class AnyViewGraphNode<NodeView: View> {
    /// The node's widget (type-erased).
    public var widget: AnyWidget {
        _getWidget()
    }

    /// The node's type-erased update method for update the view.
    private var _updateWithNewView:
        (
            _ newView: NodeView?,
            _ proposedSize: SIMD2<Int>,
            _ environment: EnvironmentValues,
            _ dryRun: Bool
        ) -> ViewUpdateResult
    /// The node's state properties
    private var _observeState: @MainActor @Sendable () -> [_AnyStateProperty]
    /// The type-erased getter for the node's widget.
    private var _getWidget: () -> AnyWidget
    /// The type-erased getter for the node's view.
    private var _getNodeView: () -> NodeView
    /// The type-erased getter for the node's children.
    private var _getNodeChildren: () -> any ViewGraphNodeChildren
    /// The underlying erased backend.
    private var _getBackend: () -> any AppBackend

    private var _transform: (
        _ transformer: ViewGraphSnapshotter,
        _ backend: _UnsafeAnyAppBackend
    ) -> ViewGraphSnapshotter.NodeSnapshot

    private let _destroy: () -> Void

    /// Type-erases a view graph node.
    public init<Backend: AppBackend>(_ nodeRef: ViewGraphNode<NodeView, Backend>, backend: Backend) {
        precondition(nodeRef.value != nil, "Cannot create an AnyViewGraphNode from a nil node")

        _updateWithNewView = { view, proposedSize, environment, dryRun in
            nodeRef.value!.update(
                with: view,
                proposedSize: proposedSize,
                environment: environment,
                dryRun: dryRun,
                backend: backend
            )
        }

        let view = (nodeRef.value?.view)!
        _observeState = {
            view._observeState()
        }
        _getWidget = {
            guard let widget = nodeRef.value?.widget else {
                fatalError("Cannot get widget from nil node")
            }
            return AnyWidget(_UnsafeAnyType(widget))
        }
        _getNodeView = {
            guard let view = nodeRef.value?.view else {
                fatalError("Cannot get view from nil node")
            }
            return view
        }
        _getNodeChildren = {
            guard let children = nodeRef.value?.children else {
                fatalError("Cannot get children from nil node")
            }
            return children
        }
        _getBackend = {
            backend
        }

        _transform = { transformer, backend in
            // Transform the node using the provided transformer
            transformer.transform(node: nodeRef, backend: backend.getBackend(as: Backend.self))
        }
        _destroy = {
            precondition(nodeRef.value != nil, "Node is already destroyed.")
            nodeRef.destroy()
        }
    }

    /// Creates a new view graph node and immediately type-erases it.
    public convenience init<Backend: AppBackend>(
        for view: NodeView,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot? = nil,
        environment: EnvironmentValues
    ) {
        self.init(
            ViewGraphNode(
                for: view,
                backend: backend,
                snapshot: snapshot,
                environment: environment
            ),
            backend: backend
        )
    }

    /// Updates the view after it got recomputed (e.g. due to the parent's state changing)
    /// or after its own state changed (depending on the presence of `newView`).
    /// - Parameter dryRun: If `true`, only compute sizing and don't update the underlying widget.
    public func update(
        with newView: NodeView?,
        proposedSize: SIMD2<Int>,
        environment: EnvironmentValues,
        dryRun: Bool
    ) -> ViewUpdateResult {
        _updateWithNewView(newView, proposedSize, environment, dryRun)
    }

    /// Observes the state properties of the node.
    /// - Returns: The state properties of the node.
    public func observeState() -> [_AnyStateProperty] {
        _observeState()
    }

    /// Gets the node's wrapped view.
    public func getView() -> NodeView {
        _getNodeView()
    }

    public func getChildren() -> any ViewGraphNodeChildren {
        _getNodeChildren()
    }

    public func getBackend() -> any AppBackend {
        _getBackend()
    }

    /// Converts the node back to its original type. Crashes if the requested backend doesn't
    /// match the node's original backend.
    // public func concreteNode<Backend: AppBackend>(
    //     for backend: Backend.Type
    // ) -> ViewGraphNode<NodeView, Backend> {
    //     guard let node = node as? ViewGraphNode<NodeView, Backend> else {
    //         fatalError("AnyViewGraphNode used with incompatible backend \(backend)")
    //     }
    //     return node
    // }

    public func transform<Backend: AppBackend>(
        with transformer: ViewGraphSnapshotter,
        backend: Backend
    ) -> ViewGraphSnapshotter.NodeSnapshot {
        _transform(transformer, backend.erased)
    }

    func destroy() {
        _destroy()
    }
}
