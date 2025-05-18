#if hasFeature(Embedded)
public struct SimpleError: Error {
    public let message: String
    public init(_ message: String) {
        self.message = message
    }
}
#else
public typealias SimpleError = any Error
#endif

@MainActor
public struct _UnsafeAnyAppBackend: AppBackend {
    public var erased: _UnsafeAnyAppBackend  { self }

    public struct Window {
        let _window: _UnsafeAnyType
        init(_unsafeType window: _UnsafeAnyType) {
            self._window = window
        }
        init<Window>(_ window: Window) {
            self.init(_unsafeType: _UnsafeAnyType(window))
        }
        subscript<T>(_ type: T.Type) -> T {
            _window[T.self]
        }

        func into<T>(_ type: T.Type = T.self) -> T {
            _window[T.self]
        }
    }
    public struct Menu {
        let _menu: _UnsafeAnyType
        init(_unsafeType menu: _UnsafeAnyType) {
            self._menu = menu
        }
        init<Menu>(_ menu: Menu) {
            self.init(_unsafeType: _UnsafeAnyType(menu))
        }
        subscript<T>(_ type: T.Type) -> T {
            _menu[T.self]
        }
    }
    public struct Alert {
        let _alert: _UnsafeAnyType
        init(_unsafeType alert: _UnsafeAnyType) {
            self._alert = alert
        }
        init<Alert>(_ alert: Alert) {
            self.init(_unsafeType: _UnsafeAnyType(alert))
        }
        subscript<T>(_ type: T.Type) -> T {
            _alert[T.self]
        }
    }
    public struct Path {
        let _path: _UnsafeAnyType
        init(_unsafeType path: _UnsafeAnyType) {
            self._path = path
        }
        init<Path>(_ path: Path) {
            self.init(_unsafeType: _UnsafeAnyType(path))
        }
        subscript<T>(_ type: T.Type) -> T {
            _path[T.self]
        }
    }
    public struct Widget {
        @usableFromInline
        let _widget: _UnsafeAnyType
        init(_unsafeType widget: _UnsafeAnyType) {
            self._widget = widget
        }
        init<Widget>(_ widget: Widget) {
            self.init(_unsafeType: _UnsafeAnyType(widget))
        }
        subscript<T>(_ type: T.Type) -> T {
            _widget[T.self]
        }

        @usableFromInline
        func into<T>(_ type: T.Type = T.self) -> T {
            _widget[T.self]
        }
    }

    private let _backend: _UnsafeAnyType

    private let _getWindowSize: (Window) -> SIMD2<Int>
    private let _setRootEnvironmentChangeHandler: (@escaping () -> Void) -> Void
    private let _setWindowEnvironmentChangeHandler: (Window, @escaping () -> Void) -> Void

    private let _createWindow: (SIMD2<Int>?) -> Window
    private let _setTitle: (Window, String) -> Void
    private let _setChild: (Window, Widget) -> Void
    private let _showWindow: (Window) -> Void
    private let _runMainLoop: (@escaping () -> Void) -> Void
    private let _runInMainThread: (@MainActor @escaping () -> Void) -> Void

    // Example constants
    public let defaultTableRowContentHeight: Int
    public let defaultTableCellVerticalPadding: Int
    public let defaultPaddingAmount: Int
    public let scrollBarWidth: Int
    public let requiresToggleSwitchSpacer: Bool
    public let defaultToggleStyle: ToggleStyle
    public let requiresImageUpdateOnScaleFactorChange: Bool
    public let menuImplementationStyle: MenuImplementationStyle
    public let canRevealFiles: Bool

    private let _setResizability: (Window, Bool) -> Void
    private let _isWindowResizable: (Window) -> Bool
    private let _setWindowSize: (Window, SIMD2<Int>) -> Void
    private let _setMinimumWindowSize: (Window, SIMD2<Int>) -> Void
    private let _setResizeHandler: (Window, @escaping (SIMD2<Int>) -> Void) -> Void
    private let _activateWindow: (Window) -> Void

    private let _showWidget: (Widget) -> Void
    private let _createContainer: () -> Widget
    private let _removeAllChildren: (Widget) -> Void
    private let _addChildToContainer: (Widget, Widget) -> Void
    private let _setChildPosition: (Int, Widget, SIMD2<Int>) -> Void
    private let _removeChildFromContainer: (Widget, Widget) -> Void

    private let _getNaturalSize: (Widget) -> SIMD2<Int>
    private let _setWidgetSize: (Widget, SIMD2<Int>) -> Void

    // TextField
    private let _createTextField: () -> Widget
    private let _updateTextField: (Widget, String, EnvironmentValues, @escaping (String) -> Void, @escaping () -> Void) -> Void
    private let _setTextFieldContent: (Widget, String) -> Void
    private let _getTextFieldContent: (Widget) -> String

    // Picker
    private let _createPicker: () -> Widget
    private let _updatePicker: (Widget, [String], EnvironmentValues, @escaping (Int?) -> Void) -> Void
    private let _setSelectedPickerOption: (Widget, Int?) -> Void

    // Progress
    private let _createProgressSpinner: () -> Widget
    private let _createProgressBar: () -> Widget
    private let _updateProgressBar: (Widget, Double?, EnvironmentValues) -> Void

    // Popover Menu
    private let _createPopoverMenu: () -> Menu
    private let _updatePopoverMenu: (Menu, ResolvedMenu, EnvironmentValues) -> Void
    private let _showPopoverMenu: (Menu, SIMD2<Int>, Widget, @escaping () -> Void) -> Void

    // Alert
    private let _createAlert: () -> Alert
    private let _updateAlert: (Alert, String, [String], EnvironmentValues) -> Void
    private let _showAlert: (Alert, Window?, @escaping (Int) -> Void) -> Void
    private let _dismissAlert: (Alert, Window?) -> Void

    // File dialogs
    private let _showOpenDialog: (FileDialogOptions, OpenDialogOptions, Window?, @escaping (DialogResult<[URL]>) -> Void) -> Void
    private let _showSaveDialog: (FileDialogOptions, SaveDialogOptions, Window?, @escaping (DialogResult<URL>) -> Void) -> Void

    // Tap gestures
    private let _createTapTarget: (Widget, TapGesture) -> Widget
    private let _updateTapTarget: (Widget, TapGesture, @escaping () -> Void) -> Void

    // Paths
    private let _createPathWidget: () -> Widget
    private let _createPath: () -> Path
    private let _updatePath: (Path, SwiftCrossUI.Path, Bool) -> Void
    private let _renderPath: (Path, Widget, Color, Color, StrokeStyle?) -> Void

    public init<B: AppBackend>(_ backend: B) where
        B.Window == Window,
        B.Widget == Widget,
        B.Menu == Menu,
        B.Alert == Alert,
        B.Path == Path
    {
        self._backend = _UnsafeAnyType(backend)

        _getWindowSize = { window in 
            backend.size(ofWindow: window[B.Window.self])
        }
        _setRootEnvironmentChangeHandler = { action in
            backend.setRootEnvironmentChangeHandler(to: action)
        }
        _setWindowEnvironmentChangeHandler = { window, action in
            backend.setWindowEnvironmentChangeHandler(of: window[B.Window.self], to: action)
        }

        _createWindow = backend.createWindow
        _setTitle = backend.setTitle
        _setChild = backend.setChild
        _showWindow = { window in 
            backend.show(window: window[B.Window.self])
        }
        _runMainLoop = backend.runMainLoop
        _runInMainThread = backend.runInMainThread

        defaultTableRowContentHeight = backend.defaultTableRowContentHeight
        defaultTableCellVerticalPadding = backend.defaultTableCellVerticalPadding
        defaultPaddingAmount = backend.defaultPaddingAmount
        scrollBarWidth = backend.scrollBarWidth
        requiresToggleSwitchSpacer = backend.requiresToggleSwitchSpacer
        defaultToggleStyle = backend.defaultToggleStyle
        requiresImageUpdateOnScaleFactorChange = backend.requiresImageUpdateOnScaleFactorChange
        menuImplementationStyle = backend.menuImplementationStyle
        canRevealFiles = backend.canRevealFiles

        _setResizability = { window, resizable in
            backend.setResizability(ofWindow: window[B.Window.self], to: resizable)
        }
        _isWindowResizable = { window in
            backend.isWindowProgrammaticallyResizable(window[B.Window.self])
        }
        _setWindowSize = { window, size in
            backend.setSize(ofWindow: window[B.Window.self], to: size)
        }
        _setMinimumWindowSize = { window, minSize in
            backend.setMinimumSize(ofWindow: window[B.Window.self], to: minSize)
        }
        _setResizeHandler = { window, action in
            backend.setResizeHandler(ofWindow: window[B.Window.self], to: action)
        }
        _activateWindow = { window in
            backend.activate(window: window[B.Window.self])
        }

        _showWidget = { widget in
            backend.show(widget: widget[B.Widget.self])
        }
        _createContainer = {
            Widget(_UnsafeAnyType(backend.createContainer()))
        }
        _removeAllChildren = { container in
            backend.removeAllChildren(of: container[B.Widget.self])
        }
        _addChildToContainer = { child, container in
            backend.addChild(child[B.Widget.self], to: container[B.Widget.self])
        }
        _setChildPosition = { index, container, pos in
            backend.setPosition(ofChildAt: index, in: container[B.Widget.self], to: pos)
        }
        _removeChildFromContainer = { child, container in
            backend.removeChild(child[B.Widget.self], from: container[B.Widget.self])
        }
        _getNaturalSize = { widget in
            backend.naturalSize(of: widget[B.Widget.self])
        }
        _setWidgetSize = { widget, size in
            backend.setSize(of: widget[B.Widget.self], to: size)
        }

        _createTextField = {
            Widget(_UnsafeAnyType(backend.createTextView()))
        }
        _updateTextField = { textField, placeholder, env, onChange, onSubmit in
            backend.updateTextField(
                textField[B.Widget.self],
                placeholder: placeholder,
                environment: env,
                onChange: onChange,
                onSubmit: onSubmit
            )
        }
        _setTextFieldContent = { textField, content in
            backend.setContent(ofTextField: textField[B.Widget.self], to: content)
        }
        _getTextFieldContent = { textField in
            backend.getContent(ofTextField: textField[B.Widget.self])
        }

        _createPicker = {
            backend.createPicker()
        }
        _updatePicker = { picker, options, env, onChange in
            backend.updatePicker(
                picker[B.Widget.self],
                options: options,
                environment: env,
                onChange: onChange
            )
        }
        _setSelectedPickerOption = { picker, index in
            backend.setSelectedOption(ofPicker: picker[B.Widget.self], to: index)
        }

        _createProgressSpinner = {
            backend.createProgressSpinner()
        }
        _createProgressBar = {
            backend.createProgressBar()
        }
        _updateProgressBar = { widget, progress, env in
            backend.updateProgressBar(widget[B.Widget.self], progressFraction: progress, environment: env)
        }

        _createPopoverMenu = {
            backend.createPopoverMenu()
        }
        _updatePopoverMenu = { menu, content, env in
            backend.updatePopoverMenu(menu[B.Menu.self], content: content, environment: env)
        }
        _showPopoverMenu = { menu, pos, relativeTo, closeHandler in
            backend.showPopoverMenu(
                menu[B.Menu.self],
                at: pos,
                relativeTo: relativeTo[B.Widget.self],
                closeHandler: closeHandler
            )
        }

        _createAlert = {
            backend.createAlert()
        }
        _updateAlert = { alert, title, actions, env in
            backend.updateAlert(alert[B.Alert.self], title: title, actionLabels: actions, environment: env)
        }
        _showAlert = { alert, window, handler in
            backend.showAlert(alert[B.Alert.self], window: window.map { $0[B.Window.self] }, responseHandler: handler)
        }
        _dismissAlert = { alert, window in
            backend.dismissAlert(alert[B.Alert.self], window: window.map { $0[B.Window.self] })
        }

        _showOpenDialog = { opts, openOpts, window, result in
            backend.showOpenDialog(
                fileDialogOptions: opts,
                openDialogOptions: openOpts,
                window: window.map { $0[B.Window.self] },
                resultHandler: result
            )
        }
        _showSaveDialog = { opts, saveOpts, window, result in
            backend.showSaveDialog(
                fileDialogOptions: opts,
                saveDialogOptions: saveOpts,
                window: window.map { $0[B.Window.self] },
                resultHandler: result
            )
        }

        _createTapTarget = { child, gesture in
            backend.createTapGestureTarget(wrapping: child[B.Widget.self], gesture: gesture)
        }
        _updateTapTarget = { target, gesture, action in
            backend.updateTapGestureTarget(target[B.Widget.self], gesture: gesture, action: action)
        }

        _createPathWidget = {
            backend.createPathWidget()
        }
        _createPath = {
            backend.createPath()
        }
        _updatePath = { path, src, pointsChanged in
            backend.updatePath(path[B.Path.self], src, pointsChanged: pointsChanged)
        }
        _renderPath = { path, container, stroke, fill, override in
            backend.renderPath(
                path[B.Path.self],
                container: container[B.Widget.self],
                strokeColor: stroke,
                fillColor: fill,
                overrideStrokeStyle: override
            )
        }
    }

    public init() {
        fatalError("Must initialize with a backend instance")
    }

    public func getBackend<Backend: AppBackend>(as type: Backend.Type) -> Backend {
        _backend[Backend.self]
    }

    public func size(ofWindow window: Window) -> SIMD2<Int> {
        _getWindowSize(window)
    }

    public func isWindowProgrammaticallyResizable(_ window: Window) -> Bool {
        _isWindowResizable(window)
    }

    public func setRootEnvironmentChangeHandler(to action: @escaping () -> Void) {
        _setRootEnvironmentChangeHandler(action)
    }

    public func setWindowEnvironmentChangeHandler(of window: Window, to action: @escaping () -> Void) {
        _setWindowEnvironmentChangeHandler(window, action)
    }
    public func setResizeHandler(ofWindow window: Window, to action: @escaping (SIMD2<Int>) -> Void) {
        _setResizeHandler(window, action)
    }


    public func createWindow(withDefaultSize size: SIMD2<Int>?) -> Window {
        _createWindow(size)
    }

    public func setTitle(ofWindow window: Window, to title: String) {
        _setTitle(window, title)
    }

    public func setChild(ofWindow window: Window, to child: Widget) {
        _setChild(window, child)
    }

    public func show(window: Window) {
        _showWindow(window)
    }

    public func show(widget: Widget) {
        _showWidget(widget)
    }

    public func runMainLoop(_ callback: @escaping () -> Void) {
        _runMainLoop(callback)
    }

    public func runInMainThread(action: @MainActor @escaping () -> Void) {
        _runInMainThread(action)
    }

    public func computeRootEnvironment(defaultEnvironment: EnvironmentValues) -> EnvironmentValues {
        // Could store closure if needed
        defaultEnvironment
    }

    public func computeWindowEnvironment(window: Window, rootEnvironment: EnvironmentValues) -> EnvironmentValues {
        rootEnvironment
    }

    public func setResizability(ofWindow window: Window, to resizable: Bool) {
        _setResizability(window, resizable)
    }
    public func isWindowResizable(_ window: Window) -> Bool {
        _isWindowResizable(window)
    }
    public func setSize(ofWindow window: Window, to size: SIMD2<Int>) {
        _setWindowSize(window, size)
    }
    public func setMinimumSize(ofWindow window: Window, to minSize: SIMD2<Int>) {
        _setMinimumWindowSize(window, minSize)
    }
    public func activate(window: Window) {
        _activateWindow(window)
    }
    public func createContainer() -> Widget {
        _createContainer()
    }
    public func removeAllChildren(of container: Widget) {
        _removeAllChildren(container)
    }
    public func addChild(_ child: Widget, to container: Widget) {
        _addChildToContainer(child, container)
    }
    public func setPosition(ofChildAt index: Int, in container: Widget, to position: SIMD2<Int>) {
        _setChildPosition(index, container, position)
    }
    public func removeChild(_ child: Widget, from container: Widget) {
        _removeChildFromContainer(child, container)
    }
    public func naturalSize(of widget: Widget) -> SIMD2<Int> {
        _getNaturalSize(widget)
    }
    public func setSize(of widget: Widget, to size: SIMD2<Int>) {
        _setWidgetSize(widget, size)
    }
    
    // Text Field
    public func createTextView() -> Widget {
        _createTextField()   
    }
    public func updateTextField(
        _ textField: Widget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        _updateTextField(textField, placeholder, environment, onChange, onSubmit)
    }

    public func setContent(ofTextField textField: Widget, to content: String) {
        _setTextFieldContent(textField, content)
    }

    public func getContent(ofTextField textField: Widget) -> String {
        _getTextFieldContent(textField)
    }

    // Picker
    public func createPicker() -> Widget {
        _createPicker()
    }

    public func updatePicker(
        _ picker: Widget,
        options: [String],
        environment: EnvironmentValues,
        onChange: @escaping (Int?) -> Void
    ) {
        _updatePicker(picker, options, environment, onChange)
    }

    public func setSelectedOption(ofPicker picker: Widget, to selectedOption: Int?) {
        _setSelectedPickerOption(picker, selectedOption)
    }

    // Progress
    public func createProgressSpinner() -> Widget {
        _createProgressSpinner()
    }

    public func createProgressBar() -> Widget {
        _createProgressBar()
    }

    public func updateProgressBar(
        _ widget: Widget,
        progressFraction: Double?,
        environment: EnvironmentValues
    ) {
        _updateProgressBar(widget, progressFraction, environment)
    }

    // Popover Menu
    public func createPopoverMenu() -> Menu {
        _createPopoverMenu()
    }

    public func updatePopoverMenu(
        _ menu: Menu,
        content: ResolvedMenu,
        environment: EnvironmentValues
    ) {
        _updatePopoverMenu(menu, content, environment)
    }

    public func showPopoverMenu(
        _ menu: Menu,
        at position: SIMD2<Int>,
        relativeTo widget: Widget,
        closeHandler handleClose: @escaping () -> Void
    ) {
        _showPopoverMenu(menu, position, widget, handleClose)
    }

    // Alert
    public func createAlert() -> Alert {
        _createAlert()
    }

    public func updateAlert(
        _ alert: Alert,
        title: String,
        actionLabels: [String],
        environment: EnvironmentValues
    ) {
        _updateAlert(alert, title, actionLabels, environment)
    }

    public func showAlert(
        _ alert: Alert,
        window: Window?,
        responseHandler handleResponse: @escaping (Int) -> Void
    ) {
        _showAlert(alert, window, handleResponse)
    }

    public func dismissAlert(_ alert: Alert, window: Window?) {
        _dismissAlert(alert, window)
    }

    // File dialogs
    public func showOpenDialog(
        fileDialogOptions: FileDialogOptions,
        openDialogOptions: OpenDialogOptions,
        window: Window?,
        resultHandler handleResult: @escaping (DialogResult<[URL]>) -> Void
    ) {
        _showOpenDialog(fileDialogOptions, openDialogOptions, window, handleResult)
    }

    public func showSaveDialog(
        fileDialogOptions: FileDialogOptions,
        saveDialogOptions: SaveDialogOptions,
        window: Window?,
        resultHandler handleResult: @escaping (DialogResult<URL>) -> Void
    ) {
        _showSaveDialog(fileDialogOptions, saveDialogOptions, window, handleResult)
    }

    // Tap gesture
    public func createTapGestureTarget(wrapping child: Widget, gesture: TapGesture) -> Widget {
        _createTapTarget(child, gesture)
    }

    public func updateTapGestureTarget(
        _ tapGestureTarget: Widget,
        gesture: TapGesture,
        action: @escaping () -> Void
    ) {
        _updateTapTarget(tapGestureTarget, gesture, action)
    }

    // Paths
    public func createPathWidget() -> Widget {
        _createPathWidget()
    }

    public func createPath() -> Path {
        _createPath()
    }

    public func updatePath(_ path: Path, _ source: SwiftCrossUI.Path, pointsChanged: Bool) {
        _updatePath(path, source, pointsChanged)
    }

    public func renderPath(
        _ path: Path,
        container: Widget,
        strokeColor: Color,
        fillColor: Color,
        overrideStrokeStyle: StrokeStyle?
    ) {
        _renderPath(path, container, strokeColor, fillColor, overrideStrokeStyle)
    }

}

public typealias AnyWidget = _UnsafeAnyAppBackend.Widget