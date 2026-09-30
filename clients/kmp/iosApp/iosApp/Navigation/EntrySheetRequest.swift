import SharedLogic

/// Which entry sheet is presented: a new record, or the edit sheet of one.
internal enum EntrySheetRequest: Hashable, Identifiable {
    /// The edit sheet of this transaction.
    case edit(SharedLogic.Transaction)
    /// A new record (手で入力する), linked to the photo `photoId` when one
    /// is given (a receipt that could not be read).
    case new(photoId: String?)

    /// Identifies the sheet for `sheet(item:)`.
    internal var id: String {
        switch self {
        case .edit(let transaction):
            "edit-\(transaction.id.description)"

        case .new(let photoId):
            "new-\(photoId ?? "")"
        }
    }
}
