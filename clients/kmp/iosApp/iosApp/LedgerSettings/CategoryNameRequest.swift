/// What the category name editor is opened for.
internal enum CategoryNameRequest: Hashable, Identifiable {
    /// Adding a category.
    case add
    /// Renaming the category with this `Category.id` (as text), now named
    /// with the second value.
    case rename(String, String)

    /// Identifies the sheet for `sheet(item:)`.
    internal var id: String {
        switch self {
        case .add:
            "add"

        case .rename(let categoryId, _):
            "rename-\(categoryId)"
        }
    }
}
