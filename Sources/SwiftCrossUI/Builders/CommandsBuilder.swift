/// A builder for ``Commands``.
@resultBuilder
@MainActor
public struct CommandsBuilder {
    public static func buildBlock(_ menus: CommandMenu...) -> Commands {
        Commands(menus: menus)
    }
}
