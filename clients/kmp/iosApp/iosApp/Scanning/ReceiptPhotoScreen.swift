import SwiftUI
import UIKit

/// A receipt's photo full screen, to read it against its draft or record:
/// pinch to zoom, × to close.
internal struct ReceiptPhotoScreen: View {
    internal let photoId: String

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @Environment(\.dismiss)
    private var dismiss: DismissAction

    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    internal var body: some View {
        NavigationStack {
            Group {
                if let image = self.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(self.zoom * self.pinch)
                        .gesture(self.zoomGesture)
                        .accessibilityLabel("レシートの写真")
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Scanning.photoBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .close) {
                        self.dismiss()
                    }
                    .accessibilityIdentifier("receipt-photo-close")
                }
            }
        }
        .accessibilityIdentifier("receipt-photo-full")
        .task(id: self.photoId) {
            self.image = await self.scanStore.photo(id: self.photoId)
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating(self.$pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let zoomed: CGFloat = max(self.zoom * value.magnification, 1)
                self.zoom = min(zoomed, Theme.Scanning.photoMaxZoom)
            }
    }
}
