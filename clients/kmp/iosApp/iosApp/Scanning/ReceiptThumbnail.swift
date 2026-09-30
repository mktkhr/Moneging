import SwiftUI
import UIKit

/// A receipt's photo, small (`Drafts5.dc.html`, `Draft5.dc.html`): read
/// from the app's private storage, a plain paper shape until it is.
internal struct ReceiptThumbnail: View {
    internal let photoId: String
    internal let width: CGFloat
    internal let height: CGFloat

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @State private var image: UIImage?

    internal var body: some View {
        Group {
            if let image = self.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(Theme.mutedText)
            }
        }
        .frame(width: self.width, height: self.height)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Scanning.thumbnailRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Scanning.thumbnailRadius)
                .strokeBorder(Theme.line, lineWidth: Theme.Scanning.thumbnailBorderWidth)
        }
        .accessibilityHidden(true)
        .task(id: self.photoId) {
            self.image = await self.scanStore.photo(id: self.photoId)
        }
    }
}
