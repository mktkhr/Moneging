import Foundation

/// One line item as the entry sheet holds it while it is edited.
internal struct EntryItem: Identifiable, Equatable {
    /// Identifies the row while the sheet is open (not the item's record).
    internal let id: UUID = UUID()
    /// Its item name, blank for none.
    internal var name: String = ""
    /// Its category (`Category.id` as text), `nil` until one is chosen.
    internal var categoryId: String?
    /// Its amount as typed, digits only.
    internal var amountText: String = ""
    /// Whether it is a discount item: its amount is taken off (below zero).
    internal var isDiscount: Bool = false

    /// Its amount in yen, below zero for a discount, 0 while nothing valid is typed.
    internal var amount: Int64 {
        (Int64(self.amountText) ?? 0) * (self.isDiscount ? -1 : 1)
    }

    /// Whether a positive amount is typed (a discount's too, before its sign).
    internal var hasAmount: Bool {
        (Int64(self.amountText) ?? 0) > 0
    }

    /// Its amount as the shared logic reads it: `-250` for a discount.
    internal var signedAmountText: String {
        self.isDiscount ? "-" + self.amountText : self.amountText
    }
}
