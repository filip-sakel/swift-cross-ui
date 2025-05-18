// import Foundation

/// Presents an 'Open file' dialog fit for selecting a single file. Some
/// backends only allow selecting either files or directories but not both
/// in a single dialog. Returns `nil` if the user cancels the operation.
public struct PresentSingleFileOpenDialogAction {
    let backend: _UnsafeAnyAppBackend
    let window: _UnsafeAnyAppBackend.Window?

    public func callAsFunction(
        title: String = "Open",
        message: String = "",
        defaultButtonLabel: String = "Open",
        initialDirectory: URL? = nil,
        showHiddenFiles: Bool = false,
        allowSelectingFiles: Bool = true,
        allowSelectingDirectories: Bool = false
    ) async -> URL? {
        func chooseFile<Backend: AppBackend>(backend: Backend) async -> URL? {
            await withCheckedContinuation { @MainActor continuation in
                backend.runInMainThread { @MainActor [window] in
                    let window: Backend.Window? =
                        if let window = window {
                            .some(window.into(Backend.Window.self))
                        } else {
                            nil
                        }

                    backend.showOpenDialog(
                        fileDialogOptions: FileDialogOptions(
                            title: title,
                            defaultButtonLabel: defaultButtonLabel,
                            allowedContentTypes: [],
                            showHiddenFiles: showHiddenFiles,
                            allowOtherContentTypes: true,
                            initialDirectory: initialDirectory
                        ),
                        openDialogOptions: OpenDialogOptions(
                            allowSelectingFiles: allowSelectingFiles,
                            allowSelectingDirectories: allowSelectingDirectories,
                            allowMultipleSelections: false
                        ),
                        window: window
                    ) { result in
                        switch result {
                            case .success(let url):
                                continuation.resume(returning: url[0])
                            case .cancelled:
                                continuation.resume(returning: nil)
                        }
                    }
                }
            }
        }

        return await chooseFile(backend: backend)
    }
}
