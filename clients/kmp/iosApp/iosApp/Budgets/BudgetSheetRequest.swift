/// Which budget the budget sheet opens: the whole month's, a category's,
/// or a new one for a category chosen in the sheet.
internal enum BudgetSheetRequest: Identifiable, Hashable {
    /// A budget for a category chosen in the sheet (＋ 予算を追加).
    case add
    /// The budget of the category with this `Category.id`.
    case category(String)
    /// The whole-month budget.
    case whole

    /// Identifies the sheet presented.
    internal var id: String {
        switch self {
        case .add:
            "add"

        case .category(let categoryId):
            "category-\(categoryId)"

        case .whole:
            "whole"
        }
    }

    /// The category the sheet opens on, or `nil` for the whole month and
    /// for a new one.
    internal var categoryId: String? {
        if case .category(let categoryId) = self {
            return categoryId
        }
        return nil
    }
}
