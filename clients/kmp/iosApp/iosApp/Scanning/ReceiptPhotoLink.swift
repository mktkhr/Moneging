import SwiftUI

/// A receipt's photo, small, beside レシートの写真を見る; choosing either shows
/// the photo full screen.
///
/// The draft (`Draft5.dc.html`) and a record linked to a photo show it. A
/// draft also says below the link how it was read (`readingMethod`,
/// `draft-reading-method`), a line of its own.
internal struct ReceiptPhotoLink: View {
    internal let photoId: String
    internal let width: CGFloat
    internal let height: CGFloat
    /// A line below the link, or `nil`.
    internal var note: String?
    /// How the draft was read (`AI を使わずに読み取りました`), or `nil`.
    internal var readingMethod: String?

    @State private var isPhotoShown: Bool = false

    internal var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Button {
                self.isPhotoShown = true
            } label: {
                ReceiptThumbnail(photoId: self.photoId, width: self.width, height: self.height)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Button {
                    self.isPhotoShown = true
                } label: {
                    Text("レシートの写真を見る")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("receipt-photo-link")
                if let readingMethod = self.readingMethod {
                    Text(readingMethod)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .accessibilityIdentifier("draft-reading-method")
                }
                if let note = self.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedText)
                }
            }
            Spacer(minLength: 0)
        }
        .fullScreenCover(isPresented: self.$isPhotoShown) {
            ReceiptPhotoScreen(photoId: self.photoId)
        }
    }
}
