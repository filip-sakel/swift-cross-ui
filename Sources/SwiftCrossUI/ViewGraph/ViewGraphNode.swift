@MainActor
private struct ViewGraphNodes {
    var lastID = 0
    var all = [Int: _UnsafeViewGraphNode]()

    mutating func generateID() -> Int {
        lastID += 1
        return lastID
    }

    mutating func removeNode(_ id: Int) -> _UnsafeViewGraphNode? {
        let instance = all[id]
        all.removeValue(forKey: id)
        return instance
    }
    @MainActor
    fileprivate static var shared = ViewGraphNodes()
}

@MainActor
public struct ViewGraphNode<NodeView: View, Backend: AppBackend> {
    public let id: Int

    public var value: Value? {
        @lifetime(borrow self)
        _read {
            let opaqueNode = ViewGraphNodes.shared.all[id]
            guard let opaqueNode else {
                yield nil
            }
            
            yield Value(node: opaqueNode)
        }
        nonmutating _modify {
            let opaqueNode = ViewGraphNodes.shared.all[id]
            var value: Value?
            if let opaqueNode {
                value = Value(node: opaqueNode)
            } else {
                value = nil
            }

            defer {
                // If the node isn't nil, update its value in the view graph.
                if let value {
                    ViewGraphNodes.shared.all[id] = value.node
                } else {
                    // If the node is nil, remove it from the view graph.
                    destroy()
                }
            }

            yield &value
        }
    }

    /// Creates a node for a given view while also creating the nodes for its children, creating
    /// the view's widget, and starting to observe its state for changes.
    public init(
        for nodeView: NodeView,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot? = nil,
        environment: EnvironmentValues
    ) {
        // Generate a unique ID for the node.
        let id = ViewGraphNodes.shared.generateID()

        // Create the node instance.
        let instance = _UnsafeViewGraphNode(
            id: id,
            for: nodeView,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )

        // Store the node instance in the view graph.
        ViewGraphNodes.shared.all[id] = instance

        // Return the reference to the node.
        self.id = id
    }

    public func destroy() {
        guard let removedNode = ViewGraphNodes.shared.removeNode(id) else {
            fatalError("ViewGraphNode with id \(id) not found")
        }
        removedNode.destroy(viewType: NodeView.self, backendType: Backend.self)
    }

    /// Get the properties
    @MainActor
    public struct Value: ~Copyable, ~Escapable {
        @usableFromInline
        var node: _UnsafeViewGraphNode

        @usableFromInline
        @_transparent
        init(node: borrowing _UnsafeViewGraphNode) {
            self.node = node
        }
        
        @_transparent
        public var widget: Backend.Widget {
            node.getWidget(Backend.self)
        }

        @_transparent
        public var view: NodeView {
            node[viewType: NodeView.self]
        }

        @_transparent
        public var children: any ViewGraphNodeChildren {
            node.children
        }


        public var currentResult: ViewUpdateResult? {
            @_transparent
            get {
                node.currentResult
            }
            @lifetime(&self)
            @_transparent
            _modify {
                yield &node.currentResult
            }
        }

        public var resultCache: [SIMD2<Int>: ViewUpdateResult] {
            @_transparent
            get {
                node.resultCache
            }
            @lifetime(&self)
            @_transparent
            _modify {
                yield &node.resultCache
            }
        }

        public var lastProposedSize: SIMD2<Int> {
            @_transparent
            get {
                node.lastProposedSize
            }
            @lifetime(&self)
            @_transparent
            _modify {
                yield &node.lastProposedSize
            }
        }
        public var parentEnvironment: EnvironmentValues {
            @_transparent
            get {
                node.parentEnvironment
            }
            @lifetime(&self)
            @_transparent
            _modify {
                yield &node.parentEnvironment
            }
        }

        // Replicate the functions
        @lifetime(&self)
        public mutating func update(
            with newView: NodeView? = nil,
            proposedSize: SIMD2<Int>,
            environment: EnvironmentValues,
            dryRun: Bool,
            backend: Backend
        ) -> ViewUpdateResult {
            node.update(
                with: newView,
                proposedSize: proposedSize,
                environment: environment,
                dryRun: dryRun,
                backend: backend
            )
        }
    }
}

/// A view graph node storing a view, its widget, and its children (likely a collection of more nodes).
///
/// This is where updates are initiated when a view's state updates, and where state is persisted
/// even when a view gets recomputed by its parent.
@MainActor
public struct _UnsafeViewGraphNode {
    // FIXME: Make ~Copyable when non-copyable dictionaries are available in Swift.

    /// The view's single widget for the entirety of its lifetime in the view graph.
    ///
    @_transparent
    public func getWidget<Backend: AppBackend>(_ type: Backend.Type) -> Backend.Widget {
        // Cast it back to the widget type.
        _widget!.into()
    }
    /// Only optional because of some initialisation order requirements. Private and wrapped to
    /// hide this inconvenient detail.
    @usableFromInline
    internal var _widget: AnyWidget?
    /// The view's children (usually just contains more view graph nodes, but can handle extra logic
    /// such as figuring out how to update variable length array of children efficiently).
    ///
    /// It's type-erased because otherwise complex implementation details would be forced to the user
    /// or other compromises would have to be made. I believe that this is the best option with Swift's
    /// current generics landscape.
    public var children: any ViewGraphNodeChildren {
        @_transparent
        get {
            _children!
        }
        @_transparent
        set {
            _children = newValue
        }
    }
    /// Only optional because of some initialisation order requirements. Private and wrapped to
    /// hide this inconvenient detail.
    @usableFromInline
    var _children: (any ViewGraphNodeChildren)?
    /// A copy of the view itself (from the latest computed body of its parent).
    public subscript<NodeView: View>(viewType type: NodeView.Type) -> NodeView {
        @_transparent
        get {
            _view[type]
        }
        @_transparent
        set {
            _view[type] = newValue
        }
    }
    @usableFromInline
    internal var _view: _UnsafeAnyType

    /// The most recent update result for the wrapped view.
    @usableFromInline
    var currentResult: ViewUpdateResult?
    /// A cache of update results keyed by the proposed size they were for. Gets cleared before the
    /// results' sizes become invalid.
    @usableFromInline
    var resultCache: [SIMD2<Int>: ViewUpdateResult]
    /// The most recent size proposed by the parent view. Used when updating the wrapped
    /// view as a result of a state change rather than the parent view updating.
    @usableFromInline
    var lastProposedSize: SIMD2<Int>

    /// A cancellable handle to the view's state property observations.
    @usableFromInline
    var cancellables: [Cancellable]

    /// The environment most recently provided by this node's parent.
    @usableFromInline
    var parentEnvironment: EnvironmentValues

    @usableFromInline
    let id: Int

    fileprivate init<NodeView: View, Backend: AppBackend>(
        id: Int,
        for nodeView: NodeView,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot? = nil,
        environment: EnvironmentValues
    ) {
        self.id = id

        // Restore node snapshot if present.
        self._view = _UnsafeAnyType(nodeView)
        snapshot?.restore(to: nodeView)

        // First create the view's child nodes and widgets
        let childSnapshots =
            snapshot?.isValid(for: NodeView.self) == true
            ? snapshot?.children : snapshot.map { [$0] }

        currentResult = nil
        resultCache = [:]
        lastProposedSize = .zero
        parentEnvironment = environment
        cancellables = []

        let viewEnvironment = updateEnvironment(
            viewType: NodeView.self, backend: backend, 
            environment: environment
        )

        nodeView._updateDynamicProperties(with: viewEnvironment, previousValue: nil)

        let children = nodeView.children(
            backend: backend,
            snapshots: childSnapshots,
            environment: viewEnvironment
        )
        self.children = children

        // Then create the widget for the view itself
        let widget = nodeView.asWidget(
            children,
            backend: backend
        )
        _widget = AnyWidget(widget)

        let tag = String(NodeView._name().split(separator: "<")[0])
        backend.tag(widget: widget, as: tag)

        // Update the view and its children when state changes (children are always updated first).
        self.cancellables = nodeView._observeState().map { state in
            state.didChange.observeAsUIUpdater(backend: backend) { @MainActor in
                guard ViewGraphNodes.shared.all[id] != nil else { return }
                ViewGraphNodes.shared.all[id]!.bottomUpUpdate(viewType: NodeView.self, backend: backend)
            }
        }
    }

    /// Triggers the view to be updated as part of a bottom-up chain of updates (where either the
    /// current view gets updated due to a state change and has potential to trigger its parent to
    /// update as well, or the current view's child has propagated such an update upwards).
    private mutating func bottomUpUpdate<NodeView: View, Backend: AppBackend>(viewType: NodeView.Type, backend: Backend) {
        // First we compute what size the view will be after the update. If it will change size,
        // propagate the update to this node's parent instead of updating straight away.
        let currentSize = currentResult?.size
        let newResult = self.update(
            with: Optional<NodeView>.none, // We don't pass nil to specify the type
            proposedSize: lastProposedSize,
            environment: parentEnvironment,
            dryRun: true,
            backend: backend
        )

        if newResult.size != currentSize {
            self.currentResult = newResult
            resultCache[lastProposedSize] = newResult
            parentEnvironment.onResize(newResult.size)
        } else {
            let finalResult = self.update(
                with: Optional<NodeView>.none, // We don't pass nil to specify the type
                proposedSize: lastProposedSize,
                environment: parentEnvironment,
                dryRun: false,
                backend: backend
            )
            if finalResult.size != newResult.size {
                print(
                    """
                    warning: State-triggered view update had mismatch \
                    between dry-run size and final size.
                          -> dry-run size: \(newResult.size)
                          -> final size:   \(finalResult.size)
                    """
                )
            }
            self.currentResult = finalResult
        }
    }

    private mutating func updateEnvironment<NodeView: View, Backend: AppBackend>(
        viewType: NodeView.Type, backend: Backend, 
        environment: EnvironmentValues
    ) -> EnvironmentValues {
        environment.with(\.onResize) { _ in
            guard ViewGraphNodes.shared.all[id] != nil else { return }
            ViewGraphNodes.shared.all[id]!.bottomUpUpdate(viewType: viewType, backend: backend)
        }
    }

    /// Recomputes the view's body, and updates its widget accordingly. The view may or may not
    /// propagate the update to its children depending on the nature of the update. If `newView`
    /// is provided (in the case that the parent's body got updated) then it simply replaces the
    /// old view while inheriting the old view's state.
    /// - Parameter dryRun: If `true`, only compute sizing and don't update the underlying widget.
    public mutating func update<NodeView: View, Backend: AppBackend>(
        with newView: NodeView? = nil,
        proposedSize: SIMD2<Int>,
        environment: EnvironmentValues,
        dryRun: Bool,
        backend: Backend
    ) -> ViewUpdateResult {
        // Defensively ensure that all future scene implementations obey this
        // precondition. By putting the check here instead of only in views
        // that require `environment.window` (such as the alert modifier view),
        // we decrease the likelihood of a bug like this flying under the radar.
        precondition(
            environment.window != nil,
            "View graph updated without parent window present in environment"
        )

        if dryRun, let cachedResult = resultCache[proposedSize] {
            return cachedResult
        }

        // Attempt to cleverly reuse the current size if we can know that it
        // won't change. We must of course be in a dry run, have a known
        // current size, and must've run at least one proper dry run update
        // since the last update cycle (checked via`!sizeCache.isEmpty`) to
        // ensure that the view has been updated at least once with the
        // current view state.
        if dryRun, let currentResult, !resultCache.isEmpty {
            // If both the previous and current proposed sizes are larger than
            // the view's previously computed maximum size, reuse the previous
            // result (currentResult).
            if ((Double(lastProposedSize.x) >= currentResult.size.maximumWidth
                && Double(proposedSize.x) >= currentResult.size.maximumWidth)
                || proposedSize.x == lastProposedSize.x)
                && ((Double(lastProposedSize.y) >= currentResult.size.maximumHeight
                    && Double(proposedSize.y) >= currentResult.size.maximumHeight)
                    || proposedSize.y == lastProposedSize.y)
            {
                return currentResult
            }

            // If the view has already been updated this update cycle and claims
            // to be fixed size (maximumSize == minimumSize) then reuse the current
            // result.
            let maximumSize = SIMD2(
                currentResult.size.maximumWidth,
                currentResult.size.maximumHeight
            )
            let minimumSize = SIMD2(
                Double(currentResult.size.minimumWidth),
                Double(currentResult.size.minimumHeight)
            )
            if maximumSize == minimumSize {
                return currentResult
            }
        }

        parentEnvironment = environment
        lastProposedSize = proposedSize

        let viewEnvironment = updateEnvironment(
            viewType: NodeView.self, backend: backend, 
            environment: environment
        )

        let previousView: NodeView?
        let view: NodeView
        if let newView {
            previousView = _view[NodeView.self]
            view = newView
        } else {
            previousView = nil
            view = _view[NodeView.self]
        }

        view._updateDynamicProperties(with: viewEnvironment, previousValue: previousView)

        if !dryRun {
            backend.show(widget: getWidget(Backend.self))
        }
        let result = view.update(
            getWidget(Backend.self),
            children: children,
            proposedSize: proposedSize,
            environment: viewEnvironment,
            backend: backend,
            dryRun: dryRun
        )

        // We assume that the view's sizing behaviour won't change between consecutive dry run updates
        // and the following real update because groups of updates following that pattern are assumed to
        // be occurring within a single overarching view update. It may seem weird that we set it
        // to false after real updates, but that's because it may get invalidated between a real
        // update and the next dry-run update.
        if !dryRun {
            resultCache = [:]
        } else {
            resultCache[proposedSize] = result
        }

        // Save view
        _view[NodeView.self] = view

        currentResult = result
        return result
    }

    consuming func destroy<NodeView: View, Backend: AppBackend>(viewType: NodeView.Type, backendType: Backend.Type) {
        for cancellable in cancellables {
            cancellable.cancel()
        }
        _children = nil
    }
}