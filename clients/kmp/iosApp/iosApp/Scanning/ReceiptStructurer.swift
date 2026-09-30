import Foundation
import FoundationModels

/// Structures a receipt's recognised text with Foundation Models, on a
/// device with Apple Intelligence, into the draft JSON the shared logic
/// reads (`ReceiptReading.fromJson`, the format of
/// `acceptance/fixtures/README.md`).
internal enum ReceiptStructurer {
    /// What the model is told before every receipt.
    private static let instructions: String = """
        あなたは家計簿アプリの読み取り係です。レシートから文字認識した文章を渡すので、\
        店名・日付・合計・品目を読み取ってください。文章にないものは作らないでください。
        """

    /// Whether this device has Foundation Models available now.
    internal static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// The draft JSON of the receipt whose text is `text`.
    internal static func json(for text: String) async throws -> String {
        let session: LanguageModelSession = LanguageModelSession(instructions: Self.instructions)
        let response: LanguageModelSession.Response<GeneratedReceipt> = try await session.respond(
            to: text,
            generating: GeneratedReceipt.self,
        )
        let data: Data = try JSONSerialization.data(
            withJSONObject: Self.draft(of: response.content),
        )
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }
        return json
    }

    /// `receipt` in the draft format: a date or total not read is `null`.
    private static func draft(of receipt: GeneratedReceipt) -> [String: Any] {
        let date: Any = receipt.date.isEmpty ? NSNull() : receipt.date
        let total: Any = receipt.total > 0 ? receipt.total : NSNull()
        return [
            "store": ["value": receipt.store, "confidence": receipt.storeConfidence],
            "date": ["value": date, "confidence": receipt.dateConfidence],
            "total": ["value": total, "confidence": receipt.totalConfidence],
            "items": receipt.items.map { item in
                [
                    "name": item.name,
                    "amount": item.amount,
                    "category": item.category.isEmpty ? NSNull() : item.category,
                    "confidence": item.confidence,
                ] as [String: Any]
            },
        ]
    }
}
