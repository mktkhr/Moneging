package io.github.mktkhr.moneging.scan

import kotlinx.datetime.LocalDate

/** One item a scanner read from a receipt. */
data class ReceiptItem(
    /** Its name (品名). */
    val name: String,
    /** Its amount, in yen. */
    val amount: Long,
    /** The name of a default category it belongs to (`食費`), or `null` for none. */
    val category: String?,
    /** The scanner's confidence in the item. */
    val confidence: Double,
)

/**
 * What a scanner read from one receipt, whichever way it read it (the
 * fixture, the on-device LLM or the rule-based parser): the same shape
 * every time, so the product never branches on which one is in use
 * (PRODUCT.md §3, Scanner). A date or a total it could not read has the
 * value `null` and the confidence 0.
 */
data class ReceiptReading(
    /** The store name; empty when none was read. */
    val store: ScannedValue<String>,
    /** The date, or `null` when none was read. */
    val date: ScannedValue<LocalDate?>,
    /** The total in yen, or `null` when none was read. */
    val total: ScannedValue<Long?>,
    /** The items, in the receipt's order. */
    val items: List<ReceiptItem>,
) {
    /** Reading drafts from JSON. */
    companion object {
        /**
         * The draft in [json], in the format of `acceptance/fixtures/README.md`
         * (`{"store": {"value": …, "confidence": …}, "date": …, "total": …,
         * "items": [{"name", "amount", "category", "confidence"}]}`);
         * refuses anything else with [IllegalArgumentException].
         */
        fun fromJson(json: String): ReceiptReading {
            val root = readJson(json).asObject(what = "下書き")
            val store = root.field(name = "store")
            val date = root.field(name = "date")
            val total = root.field(name = "total")
            return ReceiptReading(
                store = ScannedValue(value = (store[VALUE] as? String).orEmpty(), confidence = store.confidence()),
                date =
                    ScannedValue(
                        value = (date[VALUE] as? String)?.let { LocalDate.parse(it) },
                        confidence = date.confidence(),
                    ),
                total = ScannedValue(value = (total[VALUE] as? JsonNumber)?.toYen(), confidence = total.confidence()),
                items =
                    (root["items"] as? List<*>).orEmpty().map { element ->
                        val item = element.asObject(what = "明細")
                        ReceiptItem(
                            name = (item["name"] as? String).orEmpty(),
                            amount = requireNotNull((item["amount"] as? JsonNumber)?.toYen()) { "明細の金額がありません" },
                            category = item["category"] as? String,
                            confidence = item.confidence(),
                        )
                    },
            )
        }
    }
}

private const val VALUE = "value"
private const val CONFIDENCE = "confidence"

private fun Any?.asObject(what: String): Map<*, *> =
    requireNotNull(this as? Map<*, *>) {
        "${what}が JSON のオブジェクトでありません"
    }

private fun Map<*, *>.field(name: String): Map<*, *> = this[name].asObject(what = name)

private fun Map<*, *>.confidence(): Double = (this[CONFIDENCE] as? JsonNumber)?.toConfidence() ?: 0.0
