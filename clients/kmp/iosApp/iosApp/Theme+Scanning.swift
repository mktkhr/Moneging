import SwiftUI

extension Theme {
    /// Tokens of reading receipts: the status band on home, the notice,
    /// the list of scans, the draft and its photo, from the design's
    /// ステージ5 artboards (`Home5.dc.html`, `Drafts5.dc.html`,
    /// `Draft5.dc.html`, `RecordMenu5.dc.html`).
    internal enum Scanning {
        /// How long the notice that photos were accepted shows, in seconds.
        internal static let noticeSeconds: Int64 = 3
        /// `noticeSeconds` as a duration.
        internal static let noticeDuration: Duration = .seconds(Self.noticeSeconds)
        /// The notice's background: dark and nearly opaque, over any screen.
        internal static let noticeBackground: Color = Color(
            light: "#1F1B18E0",
            dark: "#F7F3EEE0",
        )
        /// The notice's text, on `noticeBackground`.
        internal static let noticeText: Color = Color(
            light: "#FFFFFF",
            dark: "#1F1B18",
        )
        /// How opaque the status band's tint of the accent is.
        internal static let bandTintOpacity: CGFloat = 0.10
        /// How opaque the status band's border of the accent is.
        internal static let bandBorderOpacity: CGFloat = 0.25
        /// The corner radius of the status band.
        internal static let bandRadius: CGFloat = 16
        /// The corner radius of a card of the list of scans and the draft.
        internal static let cardRadius: CGFloat = 18
        /// A receipt's thumbnail in the list of scans.
        internal static let rowThumbnailWidth: CGFloat = 44
        /// A receipt's thumbnail's height in the list of scans.
        internal static let rowThumbnailHeight: CGFloat = 56
        /// The receipt's photo, small, on the draft.
        internal static let draftThumbnailWidth: CGFloat = 72
        /// The receipt's photo's height, small, on the draft.
        internal static let draftThumbnailHeight: CGFloat = 96
        /// The corner radius of a receipt's thumbnail.
        internal static let thumbnailRadius: CGFloat = 8
        /// The width of a thumbnail's border.
        internal static let thumbnailBorderWidth: CGFloat = 1
        /// The 要確認 mark's text, and the draft's destructive action.
        internal static let review: Color = Color(
            light: "#B8432F",
            dark: "#E08A7A",
        )
        /// How opaque the 要確認 mark's tint is.
        internal static let reviewTintOpacity: CGFloat = 0.12
        /// The corner radius of the 要確認 mark.
        internal static let reviewRadius: CGFloat = 9
        /// The width of a draft field's name column (店名, 日付, 合計).
        internal static let fieldNameWidth: CGFloat = 44
        /// The corner radius of the buttons of a failed scan.
        internal static let actionRadius: CGFloat = 20
        /// The least height of the buttons of a failed scan.
        internal static let actionHeight: CGFloat = 40
        /// The full-screen photo's background.
        internal static let photoBackground: Color = Color(
            light: "#000000",
            dark: "#000000",
        )
        /// The JPEG quality a scanned page is kept at.
        internal static let jpegQuality: CGFloat = 0.9
        /// The confidence of a value the user entered or changed: certain.
        internal static let certain: Double = 1
        /// How far the full-screen photo may be zoomed in.
        internal static let photoMaxZoom: CGFloat = 4
        /// What dims the screen behind the notice that the AI cannot be used.
        internal static let noticeScrim: Color = Color(
            light: "#1813105C",
            dark: "#0000008A",
        )
        /// The corner radius of the notice that the AI cannot be used.
        internal static let unusableNoticeRadius: CGFloat = 26
        /// The space between the screen's edges and that notice.
        internal static let unusableNoticeInset: CGFloat = 40
        /// The least height of that notice's buttons.
        internal static let unusableNoticeButtonHeight: CGFloat = 46
        /// How faint an option that cannot be chosen is.
        internal static let unusableOpacity: CGFloat = 0.45
    }
}
