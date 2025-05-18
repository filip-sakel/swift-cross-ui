// import Foundation

/// A view which attempts to persist the state of its view subtree even
/// when the subtree's structure changes. Uses state serialization (via
/// view graph snapshotting) to persist view state even when a child
/// view's implementation gets swapped out with an implementation from
/// a newly-loaded dylib (this is what makes this useful for hot reloading).
///
/// Only expected to be used directly by SwiftCrossUI itself or third
/// party libraries extending SwiftCrossUI's hot reloading capabilities.
@View
public struct HotReloadableView: View, TypeSafeView {
    typealias Children = HotReloadableViewChildren

    public var body = EmptyView()

    var child: _UnsafeAnyType
    var childTypeName: String
    var getChildNode: (
        _ backend: _UnsafeAnyAppBackend,
        _ environment: EnvironmentValues,
        _ snapshot: ViewGraphSnapshotter.NodeSnapshot?
    ) -> ErasedViewGraphNode

    public init<V: View>(_ child: V) {
        self.child = _UnsafeAnyType(child)
        self.childTypeName = V._name()
        self.getChildNode = { backend, environment, snapshot in
            ErasedViewGraphNode(
                for: child,
                backend: backend,
                snapshot: snapshot,
                environment: environment
            )
        }
    }

    public init<V: View>(@ViewBuilder _ child: () -> V) {
        self.init(child())
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> HotReloadableViewChildren {
        let snapshot = snapshots?.count == 1 ? snapshots?.first : nil
        return HotReloadableViewChildren(
            node: getChildNode(
                backend.erased,
                environment,
                snapshot
            )
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: HotReloadableViewChildren,
        backend: Backend
    ) -> Backend.Widget {
        backend.createContainer()
    }

    /// Attempts to update the child. If the initial update succeeds then the child's concrete type
    /// hasn't changed and the ViewGraph has handled state persistence on our behalf. Otherwise,
    /// we must recreate the child node and swap out our current child widget with the new view's
    /// widget. Before displaying the child, we also attempt to transfer a snapshot of the old
    /// view graph sub tree's state onto the new view graph sub tree. This is not possible to do
    /// perfectly by definition, so if we can't successfully transfer the state of the sub tree
    /// we just fall back on the failing view's default state.
    func update<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: HotReloadableViewChildren,
        proposedSize: SIMD2<Int>,
        environment: EnvironmentValues,
        backend: Backend,
        dryRun: Bool
    ) -> ViewUpdateResult {
        var (viewTypeMatched, result) = children.node.updateWithNewView(
            childTypeName, 
            child,
            proposedSize,
            environment,
            dryRun
        )

        if !viewTypeMatched {
            let snapshotter = ViewGraphSnapshotter()
            let snapshot = children.node.transform(with: snapshotter, backend: backend)
            children.node = getChildNode(
                backend.erased,
                environment,
                snapshot
            )

            // We can assume that the view types match since we just recreated the view
            // on the line above.
            let (_, newResult) = children.node.updateWithNewView(
                childTypeName, 
                child,
                proposedSize,
                environment,
                dryRun
            )
            result = newResult
            children.hasChangedChild = true
        }

        if !dryRun {
            if children.hasChangedChild {
                backend.removeAllChildren(of: widget)
                backend.addChild(children.node.getWidget().into(), to: widget)
                backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
                children.hasChangedChild = false
            }

            backend.setSize(of: widget, to: result.size.size)
        }

        return result
    }
}

final class HotReloadableViewChildren: ViewGraphNodeChildren {
    /// The erased underlying node.
    var node: ErasedViewGraphNode

    var widgets: [AnyWidget] {
        [node.getWidget()]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node]
    }

    var hasChangedChild = true

    /// Creates the erased child node and wraps the child's widget in a single-child container.
    init(node: ErasedViewGraphNode) {
        self.node = node
    }

    isolated deinit {
        node.destroy()
    }
}
