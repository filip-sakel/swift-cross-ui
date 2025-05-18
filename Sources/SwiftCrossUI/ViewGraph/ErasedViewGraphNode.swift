// import Foundation

/// A type-erased view graph node.
@MainActor
public struct ErasedViewGraphNode {
    // public var node: Any

    /// If the new view doesn't have the same type as the old view then the returned
    /// value will have `viewTypeMatched` set to `false`, allowing views such as `AnyView`
    /// to choose how to react to a mismatch. In `AnyView`'s case this means throwing away
    /// the current view graph node and creating a new one for the new view type.
    internal var updateWithNewView:
        (
            _ viewTypeName: String,
            _ newView: _UnsafeAnyType?,
            _ proposedSize: SIMD2<Int>,
            _ environment: EnvironmentValues,
            _ dryRun: Bool
        ) -> (viewTypeMatched: Bool, size: ViewUpdateResult)

    internal var getWidget: () -> AnyWidget
    internal var viewTypeName: String

    private var _transform: (ViewGraphSnapshotter, _UnsafeAnyAppBackend) -> ViewGraphSnapshotter.NodeSnapshot

    private var _destroy: () -> Void

    public init<V: View, Backend: AppBackend>(
        for view: V,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot? = nil,
        environment: EnvironmentValues
    ) { 
        self.init(wrapping: ViewGraphNode(
            for: view,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        ), backend: backend)
    }
    
    public init<V: View, Backend: AppBackend>(
        wrapping nodeRef: ViewGraphNode<V, Backend>,
        backend: Backend
    ) {
        precondition(nodeRef.value != nil, "Cannot create an ErasedViewGraphNode from a nil node")

        viewTypeName = V._name()
        updateWithNewView = { viewTypeName, erasedView, proposedSize, environment, dryRun in
            if let erasedView {
                precondition(nodeRef.value != nil, "Cannot update a nil node")

                // Cast to the expected view type; this is an *unsafe* operation
                guard viewTypeName == V._name() else {
                    // If the type doesn't match, we need to create a new node
                    return (false, ViewUpdateResult.leafView(size: .empty))
                }
                let view = erasedView[V.self]

                // Update if the graph; we just checked that nodeRef.value != nil so the node should exist
                let size = nodeRef.value!.update(
                    with: view,
                    proposedSize: proposedSize,
                    environment: environment,
                    dryRun: dryRun,
                    backend: backend
                )
                return (true, size)
            } else {
                // Update if the graph; we just checked that nodeRef.value != nil so the node should exist
                let size = nodeRef.value!.update(
                    with: nil,
                    proposedSize: proposedSize,
                    environment: environment,
                    dryRun: dryRun,
                    backend: backend
                )
                return (true, size)
            }
        }
        getWidget = {
            guard let widget = nodeRef.value?.widget else {
                fatalError("Cannot get widget from a nil node")
            }
            return AnyWidget(widget)
        }
        _transform = { transformer, backend in
            // Transform the node using the provided transformer
            transformer.transform(node: nodeRef, backend: backend.getBackend(as: Backend.self))
        }
        _destroy = {
            precondition(nodeRef.value != nil, "Cannot destroy a nil node")
            nodeRef.destroy()
        }
    }

    public init<V: View>(wrapping node: AnyViewGraphNode<V>) {
        self.init(wrapping: node, backend: node.getBackend())
    }

    private init<V: View, Backend: AppBackend>(
        wrapping node: AnyViewGraphNode<V>, backend: Backend
    ) {
        self.updateWithNewView = { viewTypeName, erasedView, proposedSize, environment, dryRun in
            // Cast view to the expected type; this is an *unsafe* operation
            guard viewTypeName == V._name() else {
                // If the type doesn't match, we need to create a new node
                return (false, ViewUpdateResult.leafView(size: .empty))
            }
            let castView = erasedView?[V.self]

            let updateResult = node.update(
                with: castView,
                proposedSize: proposedSize,
                environment: environment,
                dryRun: dryRun
            )
            return (true, updateResult)
        }
        self.viewTypeName = V._name()
        self.getWidget = { node.widget }
        self._transform = node.transform(with:backend:)
        self._destroy = node.destroy
    }

    func destroy() {
        _destroy()
    }

    public func transform<Backend: AppBackend>(with transformer: ViewGraphSnapshotter, backend: Backend) -> ViewGraphSnapshotter.NodeSnapshot {
        // Transform the node using the provided transformer
        _transform(transformer, backend.erased)
    }
}

// @MainActor
// public protocol ErasedViewGraphNodeTransformer<Return> {
//     associatedtype Return

//     func transform<V: View, Backend: AppBackend>(node: ViewGraphNode<V, Backend>) -> Return
// }