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
    /// Whether this device has Foundation Models available now.
    internal var hasOnDeviceLlm: Bool {
        #if DEBUG
            if UITestScanning.deviceAi != nil {
                return UITestScanning.isDeviceAiOn
            }
        #endif
        return ReceiptStructurer.isAvailable
    }

    /// Why Foundation Models cannot be used now, or `nil` when they can.
    internal var onDeviceLlmUnavailableReason: String? {
        #if DEBUG
            if UITestScanning.deviceAi != nil {
                return UITestScanning.isDeviceAiOn ? nil : ReceiptStructurer.turnedOffReason
            }
        #endif
        return ReceiptStructurer.unavailableReason
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
                completion(nil, String(localized: "Apple Intelligence が組み立てられませんでした"))
            }
        }
    }

    deinit {
        // No teardown needed; explicit per the project's lint policy.
    }
}
