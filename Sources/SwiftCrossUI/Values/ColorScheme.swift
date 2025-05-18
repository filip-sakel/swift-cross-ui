public enum ColorScheme: Sendable {
    case light
    case dark

    @MainActor
    public var defaultForegroundColor: Color {
        switch self {
            case .light: .black
            case .dark: .white
        }
    }
}
