// TODO: This could possibly be renamed to ``SceneGraph`` now that that's basically the role
//   it has taken on since introducing scenes.
/// A top-level wrapper providing an entry point for the app. Exists to be able to persist
/// the view graph alongside the app (we can't do that on a user's `App` implementation because
/// we can only add computed properties).
@MainActor
class _App<AppRoot: App> {
    /// The app being run.
    let app: AppRoot
    /// An instance of the app's selected backend.
    let backend: AppRoot.Backend
    /// The root of the app's scene graph.
    var sceneGraphRoot: AppRoot.Body.Node?
    /// Cancellables for observations of the app's state properties.
    var cancellables: [Cancellable]
    /// The root level environment.
    var environment: EnvironmentValues

    /// Wraps a user's app implementation.
    init(_ app: AppRoot) {
        backend = app.backend
        self.app = app
        self.environment = EnvironmentValues(backend: backend)
        self.cancellables = []
    }

    func forceRefresh() {
        // Update the app's dynamic properties
        self.app._updateDynamicProperties(
            with: self.environment,
            previousValue: nil
        )

        self.sceneGraphRoot?.update(
            self.app.body,
            backend: self.backend,
            environment: environment
        )
    }

    /// Runs the app using the app's selected backend.
    func run() {
        backend.runMainLoop {
            let baseEnvironment = EnvironmentValues(backend: self.backend)
            self.environment = self.backend.computeRootEnvironment(
                defaultEnvironment: baseEnvironment
            )

            // Update the app's dynamic properties
            self.app._updateDynamicProperties(
                with: self.environment,
                previousValue: nil
            )

            let body = self.app.body
            let rootNode = AppRoot.Body.Node(
                from: body,
                backend: self.backend,
                environment: self.environment
            )

            self.backend.setRootEnvironmentChangeHandler {
                self.environment = self.backend.computeRootEnvironment(
                    defaultEnvironment: baseEnvironment
                )
                self.forceRefresh()
            }

            // Update application-wide menu
            self.backend.setApplicationMenu(body.commands.resolve())

            rootNode.update(
                nil,
                backend: self.backend,
                environment: self.backend.computeRootEnvironment(
                    defaultEnvironment: baseEnvironment
                )
            )
            self.sceneGraphRoot = rootNode

            // Subscribe to the app's state properties
            let states = self.app._observeState()
            self.cancellables = states.map { state in
                #warning("Conditionalize for Embedded only.")
                // FIXME: Technically taking a strong reference to self causes a retain cycle
                // but the app should never be deallocated while the backend is running so this shouldn't
                // be a problem. We should probably use a weak reference to self here.
                state.didChange.observeAsUIUpdater(backend: self.backend) { @MainActor
                    [self] in
                    // guard let self = self else { return }

                    // Update the app's dynamic properties
                    self.app._updateDynamicProperties(
                        with: self.environment,
                        previousValue: nil
                    )

                    let body = self.app.body
                    self.sceneGraphRoot?.update(
                        body,
                        backend: self.backend,
                        environment: self.environment
                    )

                    self.backend.setApplicationMenu(body.commands.resolve())
                }
            }
        }
    }
}


struct _AppGlobalState {
    /// Force refresh the entire scene graph. Used by hot reloading. If you need to do
    /// this in your own code then something has gone very wrong...
    internal var _forceRefresh: () -> Void = {}

    /// Metadata embedded by Swift Bundler if present. Loaded at app start up.
    internal var swiftBundlerAppMetadata: AppMetadata? = nil

    @MainActor
    public static var shared = _AppGlobalState()
}