import SwiftUI
import UIKit
import VisionKit

/// The OS document scanner (VisionKit): a session of several pages hands
/// over one receipt per page, each as a JPEG, when it ends; cancelling it
/// hands over nothing.
internal struct DocumentScannerView: UIViewControllerRepresentable {
    /// Relays the scanner's end to `onFinish`.
    internal final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onFinish: ([Data]) -> Void

        internal init(onFinish: @escaping ([Data]) -> Void) {
            self.onFinish = onFinish
        }

        internal func documentCameraViewController(
            _: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan,
        ) {
            let pages: [Data] = (0..<scan.pageCount).compactMap { index in
                scan.imageOfPage(at: index).jpegData(compressionQuality: Theme.Scanning.jpegQuality)
            }
            self.onFinish(pages)
        }

        internal func documentCameraViewControllerDidCancel(
            _: VNDocumentCameraViewController,
        ) {
            self.onFinish([])
        }

        internal func documentCameraViewController(
            _: VNDocumentCameraViewController,
            didFailWithError _: any Error,
        ) {
            self.onFinish([])
        }

        deinit {
            // No teardown needed; explicit per the project's lint policy.
        }
    }

    /// Called once with the pages scanned, empty when the session was
    /// cancelled or failed.
    internal let onFinish: ([Data]) -> Void

    internal func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: self.onFinish)
    }

    internal func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller: VNDocumentCameraViewController = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    internal func updateUIViewController(
        _: VNDocumentCameraViewController,
        context _: Context,
    ) {
        // Nothing changes while it is shown.
    }
}
