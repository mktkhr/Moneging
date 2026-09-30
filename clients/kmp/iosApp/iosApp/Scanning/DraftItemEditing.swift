import Foundation

/// The item the sheet 明細を直す is open on: one of the draft's, or a new
/// one (＋ 明細を足す).
internal struct DraftItemEditing: Identifiable {
    /// Identifies the sheet for `sheet(item:)`.
    internal let id: UUID = UUID()
    /// The item's position among the draft's items, or `nil` for a new one.
    internal let index: Int?
    /// The item as the sheet opens it.
    internal let item: DraftItemState
}
