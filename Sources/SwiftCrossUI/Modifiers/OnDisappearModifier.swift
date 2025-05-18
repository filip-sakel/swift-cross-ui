extension View {
    /// Adds an action to be performed after this view disappears.
    ///
    /// `onDisappear` actions on outermost views are called first and propagate
    /// down to the leaf views due to essentially relying on the `deinit` of the
    /// modifier view's ``ViewGraphNode``.
    public nonisolated func onDisappear(perform action: @escaping @Sendable () -> Void) -> some View {
        OnDisappearModifier(body: TupleView1(self), action: action)
    }
}

@View(checkConformance: false)
struct OnDisappearModifier<Content: View> {
    var body: TupleView1<Content>
    var action: @Sendable () -> Void

    @MainActor
    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> OnDisappearModifierChildren {
        OnDisappearModifierChildren(
            wrappedChildren: defaultChildren(
                backend: backend,
                snapshots: snapshots,
                environment: environment
            ),
            action: action
        )
    }

    @MainActor
    func layoutableChildren<Backend: AppBackend>(
        backend: Backend,
        children: OnDisappearModifierChildren
    ) -> [LayoutSystem.LayoutableChild] {
        defaultLayoutableChildren(
            backend: backend,
            children: children.wrappedChildren
        )
    }

    @MainActor
    func asWidget<Backend: AppBackend>(
        _ children: OnDisappearModifierChildren,
        backend: Backend
    ) -> Backend.Widget {
        defaultAsWidget(children.wrappedChildren, backend: backend)
    }

    @MainActor
    func update<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: OnDisappearModifierChildren,
        proposedSize: SIMD2<Int>,
        environment: EnvironmentValues,
        backend: Backend,
        dryRun: Bool
    ) -> ViewUpdateResult {
        defaultUpdate(
            widget,
            children: children.wrappedChildren,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend,
            dryRun: dryRun
        )
    }
}

final class OnDisappearModifierChildren: ViewGraphNodeChildren {
    let wrappedChildren: any ViewGraphNodeChildren
    var action: @Sendable () -> Void

    var widgets: [AnyWidget] {
        wrappedChildren.widgets
    }

    var erasedNodes: [ErasedViewGraphNode] {
        wrappedChildren.erasedNodes
    }

    init(
        wrappedChildren: any ViewGraphNodeChildren,
        action: @escaping @Sendable () -> Void
    ) {
        self.wrappedChildren = wrappedChildren
        self.action = action
    }

    isolated deinit {
        for child in wrappedChildren.erasedNodes {
            child.destroy()
        }
        action()
    }
}
