import Foundation
import FoundationModels
import SharedLogic

/// Structures a receipt's recognised text with Foundation Models, on a
/// device with Apple Intelligence, into the draft JSON the shared logic
/// reads (`ReceiptReading.fromJson`, the format of
/// `acceptance/fixtures/README.md`).
internal enum ReceiptStructurer {
    /// What the model is told before every receipt: the reading of a
    /// receipt the rule-based parser follows too (PRODUCT.md §3, Draft), so
    /// both ways read a receipt alike.
    private static var instructions: String {
        let chains: String = ReceiptChains.shared.known.map(\.name).joined(separator: "・")
        return """
            あなたは家計簿アプリの読み取り係です。レシートから文字認識した文章（1行が\
            レシートの1行）を渡すので、店名・日付・合計・品目を読み取ってください。\
            文章にないものは作らないでください。読み方:
            - 店名: 文章に次のチェーンのどれかの名前があれば、そのチェーン1つの名前だけ: \(chains)。\
            なければ店の名前の行。
            - 日付: 文章の最初の 2026/09/28、2026年09月28日、2026年10月1日 を、2026-09-28 の形で。\
            日付・レジ・時刻の行は品目にしない。
            - 合計: 「合計」で始まる最初の行の金額。
            - 品目: 日付の行より後、「小計」「合計」「商品代金」「値引合計」で始まる行（前に「（」が\
            あってもよい）か、金額で終わらない「（」で始まる行より前の、金額で終わる行。
            - 金額に ¥ を付けて印字するレシート（金額で終わる品目の行の多くが ¥ 付き）では、¥ も - も\
            付かない数字（マックフライポテトL 11 の 11）は個数の読み違いで、金額にしない。
            - 数量の行（2コ×単178 ¥356、@159x 3 *477、＠159× 3 *477）は品目にしない。その金額を、すぐ上の\
            金額のない行（品名）の品目の金額にする。
            - 割引の行（ディスカウント・値引・割引）は印字の符号で決める。- 付き（値引額 -50、\
            ★割引(20%) -120）は品目にせず、上の品目の金額から引く。金額のない割引の行（シール割引 50%）\
            の次の数量の行（2コX単-99 -198）の金額も、上の品目から引く。
            - - の付かない割引（ディスカウント ¥250）は会計全体の割引で、どこにあっても、金額を\
            マイナスにした品目「ディスカウント」（-250）として品目の最後に置く。上の品目からは引かない。
            - 括弧で始まるセットの行（(…セット) *1060 (1コ) ¥1,060）は品目で、名前は最初の括弧の中、\
            金額は行末の金額（¥1,060）。途中の *1060 や (1コ)（(12) と読めることもある）は捨てる。\
            その下の「名前 1コ」（名前 11 と読めることもある）の行は中身なので品目にしない。
            - オプションの行（+ で始まる行、金額の前に ※ がある行: 氷Ice※通常 ¥120）は品目にしない。\
            上の品目の金額に足す。¥0 のオプションは何も足さない。
            - 品名の先頭の3桁の商品コード、軽減税率の印（* ＊）、チェック欄（ロ ■ □）は除く。
            - 外税のレシート（外税・外8%・税抜 のどれかがある）では、最後に品目「消費税」（分類は空）を\
            足し、その金額は合計から品目の和を引いた額。内税（内消費税等）なら足さない。
            - 品目の金額の和が合計と等しくなる。

            例:
            セブン-イレブン 芝店
            2026年09月28日（月）13:44
            651 大盛ペペロンチーノ *648
            値引額 -50
            キリンファイア600ml
            @159x 3 *477
            小計（税抜8%） ¥1,075
            消費税等（8%） ¥86
            合計 ¥1,161
            → 店名 セブン-イレブン、日付 2026-09-28、合計 1161、品目 大盛ペペロンチーノ 598、\
            キリンファイア600ml 477、消費税 86
            """
    }

    /// Why Apple Intelligence cannot be used when it is turned off.
    internal static let turnedOffReason: String = String(
        localized: "設定で Apple Intelligence がオフになっています。"
    )

    /// Whether this device has Foundation Models available now.
    internal static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Why Foundation Models cannot be used now, or `nil` when they can.
    internal static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil

        case .unavailable(.appleIntelligenceNotEnabled):
            return Self.turnedOffReason

        case .unavailable(.modelNotReady):
            return String(localized: "Apple Intelligence の準備ができていません。しばらくしてからお試しください。")

        case .unavailable(.deviceNotEligible):
            return String(localized: "この端末では使えません（Apple Intelligence に対応した端末で、オンにすると選べます）。")

        case .unavailable:
            return String(localized: "この端末では Apple Intelligence を使えません。")
        }
    }

    /// The draft JSON of the receipt whose text is `text`.
    ///
    /// A well-known chain the text names is its store, as the rule-based
    /// parser reads it, whatever the model answered.
    internal static func json(for text: String) async throws -> String {
        let session: LanguageModelSession = LanguageModelSession(instructions: Self.instructions)
        let response: LanguageModelSession.Response<GeneratedReceipt> = try await session.respond(
            to: text,
            generating: GeneratedReceipt.self,
        )
        let data: Data = try JSONSerialization.data(
            withJSONObject: Self.draft(
                of: response.content,
                chain: ReceiptChains.shared.nameIn(lines: text.components(separatedBy: "\n")),
            ),
        )
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }
        return json
    }

    /// `receipt` in the draft format, its store `chain` when there is one.
    ///
    /// A date or total not read is `null`.
    private static func draft(of receipt: GeneratedReceipt, chain: String?) -> [String: Any] {
        let date: Any = receipt.date.isEmpty ? NSNull() : receipt.date
        let total: Any = receipt.total > 0 ? receipt.total : NSNull()
        return [
            "store": ["value": chain ?? receipt.store, "confidence": receipt.storeConfidence],
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
