/// An item of a ``Menu`` or ``CommandMenu``.
@MainActor
public enum MenuItem {
    case button(Button)
    case text(Text)
    case submenu(Menu)
}
