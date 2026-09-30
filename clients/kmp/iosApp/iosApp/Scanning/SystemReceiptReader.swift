import Foundation
import SharedLogic

/// How the app reads receipts on the device, for the shared logic.
///
/// The shared scanner (`IosReceiptReader`) asks it for Vision's text
/// recognition, then for Foundation Models on a device with Apple
/// Intelligence. On a device without it the shared rule-based parser
/// structures the text instead, and this is never asked to. Nothing leaves
/// the device.
internal final class SystemReceiptReader: NSObject, IosReceiptReader {
    /// Whether this device has Foundation Models available.
    internal var hasOnDeviceLlm: Bool {
        ReceiptStructurer.isAvailable
    }

    /// Recognises the text of `image` off the main thread.
    internal func recognizeText(
        image: Data,
        completion: @escaping (String?, String?) -> Void,
    ) {
        Task.detached(priority: .userInitiated) {
            do {
                completion(try ReceiptTextRecognizer.text(of: image), nil)
            } catch {
                completion(nil, String(localized: "文字を読み取れませんでした"))
            }
        }
    }

    /// Structures `text` with Foundation Models into the draft JSON.
    internal func structureText(
        text: String,
        completion: @escaping (String?, String?) -> Void,
    ) {
        Task.detached(priority: .userInitiated) {
            do {
                completion(try await ReceiptStructurer.json(for: text), nil)
            } catch {
                completion(nil, String(localized: "内容を読み取れませんでした"))
            }
        }
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}
