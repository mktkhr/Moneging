package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.AmountText
import io.github.mktkhr.moneging.domain.Formats

// The name of the item that makes up the difference (PRODUCT.md §3, Draft).
private const val DIFFERENCE_NAME = "差額"

// The confidence of a value the user chose: certain.
private const val CERTAIN = 1.0

/**
 * How a draft's items fail to add up to its total, as its form shows it
 * (PRODUCT.md §5, Receipt reading): the warning, the two fixes and the
 * question asked before recording it.
 */
data class DraftMismatch(
    /** The items' sum, in yen. */
    val itemsSum: Long,
    /** The total, in yen. */
    val total: Long,
    /** The items' sum as shown in the warning colour (`830円`). */
    val itemsSumText: String,
    /** The warning: `明細の合計 830円 が合計 980円 と 150円 合いません。`. */
    val warningText: String,
    /** What the fixes below the warning answer: `次のどちらかで直せます。`. */
    val invitationText: String,
    /**
     * The item `差額` of the difference, in the items' category when every
     * item names the same one, else none (その他); `null` when the sum is
     * above the total, where adding it is not offered.
     */
    val differenceItem: DraftItemForm?,
    /** The fix adding [differenceItem]: `差額 150円 を明細に足す`, or `null` when it is not offered. */
    val addDifferenceText: String?,
    /** The fix recording the total alone: `明細を消して、合計 980円 だけで記録する`. */
    val totalOnlyText: String,
    /** The question's title: `合計額が合いませんがよろしいですか？`. */
    val questionTitle: String,
    /** The question's message: the three amounts, then what is recorded. */
    val questionMessage: String,
)

/**
 * How this form's items fail to add up to its total, or `null` when they
 * add up, when it has no items, or while its total or an item's amount is
 * not a valid amount.
 */
fun DraftForm.mismatch(): DraftMismatch? {
    val total = runCatching { AmountText.parse(totalText) }.getOrNull()
    val amounts = items.map { item -> runCatching { AmountText.parseSigned(item.amountText) }.getOrNull() }
    val sum = amounts.takeIf { it.isNotEmpty() && null !in it }?.sumOf { it ?: 0L }
    return if (total == null || sum == null || sum == total) null else mismatchOf(sum = sum, total = total)
}

private fun DraftForm.mismatchOf(
    sum: Long,
    total: Long,
): DraftMismatch {
    val isBelow = sum < total
    val difference = if (isBelow) total - sum else sum - total
    val sumText = Formats.yen(sum)
    val totalText = Formats.yen(total)
    val differenceText = Formats.yen(difference)
    val differenceItem =
        DraftItemForm(
            name = DIFFERENCE_NAME,
            amountText = AmountText.grouped(difference.toString()),
            categoryId = items.map { it.categoryId }.distinct().singleOrNull(),
            confidence = CERTAIN,
        ).takeIf { isBelow }
    val consequence =
        if (isBelow) {
            "差額 $differenceText を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。"
        } else {
            "明細の合計 $sumText で記録し、要確認の印を付けます。"
        }
    return DraftMismatch(
        itemsSum = sum,
        total = total,
        itemsSumText = sumText,
        warningText = "明細の合計 $sumText が合計 $totalText と $differenceText 合いません。",
        invitationText = "次のどちらかで直せます。",
        differenceItem = differenceItem,
        addDifferenceText = differenceItem?.let { "差額 $differenceText を明細に足す" },
        totalOnlyText = "明細を消して、合計 $totalText だけで記録する",
        questionTitle = "合計額が合いませんがよろしいですか？",
        questionMessage = "明細の合計 $sumText と合計 $totalText が $differenceText 違います。このまま記録すると、$consequence",
    )
}
