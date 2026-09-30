import Foundation
import SharedLogic

/// A draft as its sheet holds it while it is corrected: every field
/// editable, each with how sure the scanner was of it, which becomes 1 once
/// the user changes it (and so is no longer marked 要確認).
internal struct DraftFormState: Equatable {
    /// The store name (店名).
    internal var store: String
    /// How sure the scanner was of `store`.
    internal var storeConfidence: Double
    /// The date (日付).
    internal var date: Date
    /// How sure the scanner was of `date`.
    internal var dateConfidence: Double
    /// The total as typed, digits only (合計).
    internal var totalText: String
    /// How sure the scanner was of the total.
    internal var totalConfidence: Double
    /// The whole expense's category when there are no items, `nil` for その他.
    internal var categoryId: String?
    /// The items.
    internal var items: [DraftItemState]

    /// The items' sum, in yen.
    internal var itemsTotal: Int64 {
        self.items.reduce(0) { $0 + $1.amount }
    }

    /// Whether it can be confirmed: a total, and every item with an amount.
    internal var canConfirm: Bool {
        (Int64(self.totalText) ?? 0) > 0 && self.items.allSatisfy { $0.amount > 0 }
    }

    /// The draft as the shared logic's form holds it.
    internal var form: DraftForm {
        DraftForm(
            store: self.store,
            storeConfidence: self.storeConfidence,
            date: IsoDate.iso(from: self.date),
            dateConfidence: self.dateConfidence,
            totalText: self.totalText,
            totalConfidence: self.totalConfidence,
            categoryId: self.items.isEmpty ? self.categoryId : nil,
            items: self.items.map(\.form),
        )
    }

    /// The draft `editing` opens with.
    internal static func from(_ editing: DraftEditing) -> Self {
        let source: DraftForm = editing.form
        return Self(
            store: source.store,
            storeConfidence: source.storeConfidence,
            date: IsoDate.date(fromIso: source.date),
            dateConfidence: source.dateConfidence,
            totalText: source.totalText.filter(\.isNumber),
            totalConfidence: source.totalConfidence,
            categoryId: source.categoryId,
            items: source.items.map(DraftItemState.from),
        )
    }
}
