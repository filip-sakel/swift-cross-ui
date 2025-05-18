// import Foundation

/// Opens a URL with the default application. May present an application picker
/// if multiple applications are registered for the given URL protocol.
public struct OpenURLAction {
    let action: (URL) -> Void

    @MainActor
    init<Backend: AppBackend>(backend: Backend) {
        action = { url in
            do throws(SimpleError) {
                try backend.openExternalURL(url)
            } catch(let error) {
                print("warning: Failed to open external url: \(error)")
            }
        }
    }

    public func callAsFunction(_ url: URL) {
        action(url)
    }
}
