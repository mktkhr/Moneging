/// The draft whose sheet is presented (下書きを確認).
internal struct DraftSheetRequest: Hashable, Identifiable {
    /// The draft's id, as text.
    internal let draftId: String

    /// Identifies the sheet for `sheet(item:)`.
    internal var id: String {
        self.draftId
    }
}
