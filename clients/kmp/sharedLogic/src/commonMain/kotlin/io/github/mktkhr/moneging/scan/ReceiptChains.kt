package io.github.mktkhr.moneging.scan

/** A well-known chain: the [name] a draft gives its store, and the [spellings] a receipt prints it in. */
data class ReceiptChain(
    /** The store name of a draft from one of its receipts. */
    val name: String,
    /** How its receipts print it, compared without case. */
    val spellings: List<String>,
)

/**
 * The well-known chains kept on the device (PRODUCT.md §3, Draft): a
 * receipt that prints one of their spellings is read as that chain's store.
 */
object ReceiptChains {
    /** The chains, each with the spellings its receipts print. */
    val known: List<ReceiptChain> =
        listOf(
            ReceiptChain(name = "ライフ", spellings = listOf("ライフ")),
            ReceiptChain(name = "マルエツ プチ", spellings = listOf("マルエツ プチ", "マルエツプチ", "maruetsu petit")),
            ReceiptChain(name = "マルエツ", spellings = listOf("マルエツ", "maruetsu")),
            ReceiptChain(name = "セブン-イレブン", spellings = listOf("セブン-イレブン", "セブンイレブン", "7-eleven")),
            ReceiptChain(name = "ゴンチャ", spellings = listOf("ゴンチャ", "gong cha")),
            ReceiptChain(name = "ファミリーマート", spellings = listOf("ファミリーマート", "familymart")),
            ReceiptChain(name = "ローソン", spellings = listOf("ローソン", "lawson")),
            ReceiptChain(name = "ミニストップ", spellings = listOf("ミニストップ", "ministop")),
            ReceiptChain(name = "まいばすけっと", spellings = listOf("まいばすけっと")),
            ReceiptChain(name = "イトーヨーカドー", spellings = listOf("イトーヨーカドー")),
            ReceiptChain(name = "西友", spellings = listOf("西友", "seiyu")),
            ReceiptChain(name = "スターバックス", spellings = listOf("スターバックス", "starbucks")),
            ReceiptChain(name = "マクドナルド", spellings = listOf("マクドナルド", "mcdonald's")),
        )

    /**
     * The name of the chain whose spelling appears first in [lines], joined
     * by spaces and compared without case; `null` when none appears. A
     * chain listed earlier wins a spelling found at the same place (`マルエツ
     * プチ` before `マルエツ`).
     */
    fun nameIn(lines: List<String>): String? {
        val text = lines.joinToString(separator = " ").lowercase()
        val found =
            known.mapNotNull { chain ->
                chain.spellings
                    .map { spelling -> text.indexOf(spelling.lowercase()) }
                    .filter { index -> index >= 0 }
                    .minOrNull()
                    ?.let { index -> index to chain.name }
            }
        return found.minByOrNull { (index, _) -> index }?.second
    }
}
