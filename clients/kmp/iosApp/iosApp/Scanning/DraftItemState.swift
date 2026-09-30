import Foundation
import SharedLogic

/// One item of a draft as its sheet holds it while it is corrected.
internal struct DraftItemState: Identifiable, Equatable {
    /// Identifies the row while the sheet is open (not the item's record).
    internal let id: UUID = UUID()
    /// Its name (品名).
    internal var name: String
    /// Its amount as typed, digits only (金額).
    internal var amountText: String
    /// Its category (`Category.id` as text), `nil` for none (その他).
    internal var categoryId: String?
    /// How sure the scanner was of it; 1 once the user changed it.
    internal var confidence: Double

    /// Whether it is marked 要確認.
    internal var needsReview: Bool {
        SharedLogic.needsReview(confidence: self.confidence)
    }

    /// Its amount in yen, 0 while nothing valid is typed.
    internal var amount: Int64 {
        Int64(self.amountText) ?? 0
    }

    /// The item as the shared logic's form holds it.
    internal var form: DraftItemForm {
        DraftItemForm(
            name: self.name,
            amountText: self.amountText,
            categoryId: self.categoryId,
            confidence: self.confidence,
        )
    }

    /// A new item the user adds: nothing read, nothing to check.
    internal static func added() -> Self {
        Self(name: "", amountText: "", categoryId: nil, confidence: Theme.Scanning.certain)
    }

    /// `item` of the shared logic's form.
    internal static func from(_ item: DraftItemForm) -> Self {
        Self(
            name: item.name,
            amountText: item.amountText.filter(\.isNumber),
            categoryId: item.categoryId,
            confidence: item.confidence,
        )
    }
}
