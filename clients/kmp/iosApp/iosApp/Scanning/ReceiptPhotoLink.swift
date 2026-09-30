import SwiftUI

/// A receipt's photo, small, beside レシートの写真を見る; choosing it shows
/// the photo full screen.
///
/// The draft (`Draft5.dc.html`) and a record linked to a photo show it.
internal struct ReceiptPhotoLink: View {
    internal let photoId: String
    internal let width: CGFloat
    internal let height: CGFloat
    /// A line below the link, or `nil`.
    internal var note: String?

    @State private var isPhotoShown: Bool = false

    internal var body: some View {
        Button {
            self.isPhotoShown = true
        } label: {
            HStack(spacing: Theme.Spacing.medium) {
                ReceiptThumbnail(photoId: self.photoId, width: self.width, height: self.height)
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    Text("レシートの写真を見る")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                    if let note = self.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Theme.mutedText)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("receipt-photo-link")
        .fullScreenCover(isPresented: self.$isPhotoShown) {
            ReceiptPhotoScreen(photoId: self.photoId)
        }
    }
}
