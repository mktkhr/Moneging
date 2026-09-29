import Foundation

/// One line item as the entry sheet holds it while it is edited.
internal struct EntryItem: Identifiable, Equatable {
    /// Identifies the row while the sheet is open (not the item's record).
    internal let id: UUID = UUID()
    /// Its item name, blank for none.
    internal var name: String = ""
    /// Its category (`Category.id` as text), `nil` until one is chosen.
    internal var categoryId: String?
    /// Its amount as typed.
    internal var amountText: String = ""

    /// Its amount in yen, 0 while nothing valid is typed.
    internal var amount: Int64 {
        Int64(self.amountText) ?? 0
    }
}
