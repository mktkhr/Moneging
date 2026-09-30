import Foundation

/// A receipt photo handed over to be kept and read: its bytes as they are,
/// and their media type.
internal struct ReceiptPhoto {
    /// A JPEG: a page of the document scanner, a fixture picture.
    internal static let jpegType: String = "image/jpeg"

    /// The photo's bytes.
    internal let data: Data
    /// Their media type (`image/jpeg`, `image/heic`).
    internal let contentType: String
}
