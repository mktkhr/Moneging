import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// Hands receipt photos over to be read, when the 記録する sheet asks.
///
/// When `AppRouter.receiptCapture` is set, レシートを撮る opens the OS document
/// scanner (one receipt per page), 写真を選ぶ the photo library (several
/// at once). Every photo handed over is kept as it is and its scan started
/// (`ScanStore.accept`). In a UI test the fixture pictures stand in for
/// both (`UITestScanning`).
internal struct ReceiptCaptureModifier: ViewModifier {
    @Environment(AppRouter.self)
    private var router: AppRouter

    @Environment(ScanStore.self)
    private var scanStore: ScanStore

    @State private var isScannerPresented: Bool = false
    @State private var isPickerPresented: Bool = false
    @State private var pickedItems: [PhotosPickerItem] = []

    // The picked items' photos, each in its own encoding.
    private static func photos(of items: [PhotosPickerItem]) async -> [ReceiptPhoto] {
        var photos: [ReceiptPhoto] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }
            let type: UTType = item.supportedContentTypes.first { $0.conforms(to: .image) } ?? .jpeg
            let contentType: String = type.preferredMIMEType ?? ReceiptPhoto.jpegType
            photos.append(ReceiptPhoto(data: data, contentType: contentType))
        }
        return photos
    }

    // JPEG pictures as photos to read.
    private static func jpegs(_ pictures: [Data]) -> [ReceiptPhoto] {
        pictures.map { picture in ReceiptPhoto(data: picture, contentType: ReceiptPhoto.jpegType) }
    }

    internal func body(content: Content) -> some View {
        content
            .onChange(of: self.router.receiptCapture) { _, option in
                guard let option else {
                    return
                }
                self.router.receiptCapture = nil
                self.start(option)
            }
            .fullScreenCover(isPresented: self.$isScannerPresented) {
                DocumentScannerView { pages in
                    self.isScannerPresented = false
                    self.accept(Self.jpegs(pages))
                }
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: self.$isPickerPresented,
                selection: self.$pickedItems,
                matching: .images,
                preferredItemEncoding: .current,
            )
            .onChange(of: self.pickedItems) { _, items in
                guard !items.isEmpty else {
                    return
                }
                self.pickedItems = []
                Task {
                    await self.scanStore.accept(await Self.photos(of: items))
                }
            }
    }

    private func start(_ option: RecordOption) {
        #if DEBUG
            if UITestScanning.isFixtureCapture {
                let pictures: [Data] =
                    option == .receiptScan
                    ? UITestScanning.scannedPages : UITestScanning.pickedPhotos
                self.accept(Self.jpegs(pictures))
                return
            }
        #endif
        switch option {
        case .manual:
            return

        case .photoPick:
            self.isPickerPresented = true

        case .receiptScan:
            if VNDocumentCameraViewController.isSupported {
                self.isScannerPresented = true
            } else {
                self.scanStore.failureMessage = String(localized: "この端末ではレシートを撮れません")
            }
        }
    }

    private func accept(_ photos: [ReceiptPhoto]) {
        Task {
            await self.scanStore.accept(photos)
        }
    }
}

extension View {
    /// Hands receipt photos over when asked; see `ReceiptCaptureModifier`.
    internal func receiptCapture() -> some View {
        self.modifier(ReceiptCaptureModifier())
    }
}
