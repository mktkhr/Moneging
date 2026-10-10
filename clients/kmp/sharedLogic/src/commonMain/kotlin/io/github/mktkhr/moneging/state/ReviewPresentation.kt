package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.domain.Transaction

// How the screens show the needs-review records (PRODUCT.md §5,
// Needs-review), the same on every client.

private const val DIFFERENCE_NAME = "差額"
private const val REVIEW_STATUS_DETAIL = "明細が合計と合わないまま記録したもの"
private const val EXPLANATION_PREFIX = "要確認："
private const val EXPLANATION_CLOSING = "写真を見て直してください。"
private const val EXPLANATION_REASON = "読み取った明細が合計と合わなかったため"

/** The count of the ledger's needs-review records home shows below its name. */
data class ReviewStatus(
    /** `要確認 2件`. */
    val title: String,
    /** `明細が合計と合わないまま記録したもの`. */
    val detail: String,
) {
    /** What a screen reader says: `要確認 2件、明細が合計と合わないまま記録したもの`. */
    val accessibilityLabel: String get() = "$title、$detail"
}

/** One day of the needs-review records, as their list shows it. */
data class ReviewSection(
    /** The day, ISO. */
    val date: String,
    /** The day with its year, as `2026年2月13日（金）`: the list spans months. */
    val title: String,
    /** The day's marked records, newest first. */
    val rows: List<TransactionRow>,
)

/** Why a record is marked, as its sheet explains it. */
data class ReviewExplanation(
    /** `要確認：`, shown in the warning colour. */
    val prefix: String,
    /** The rest: `読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。`. */
    val body: String,
) {
    /** The whole explanation. */
    val text: String get() = prefix + body
}

/** The count of needs-review records, or `null` while none is marked (never `要確認 0件`). */
fun LedgerUiState.reviewStatus(): ReviewStatus? =
    reviewNeeded.size.takeIf { it > 0 }?.let { count ->
        ReviewStatus(title = "要確認 ${count}件", detail = REVIEW_STATUS_DETAIL)
    }

/** The needs-review records grouped by day, newest first, whatever their month. */
fun LedgerUiState.reviewSections(): List<ReviewSection> =
    reviewNeeded.groupBy { it.date }.map { (date, transactions) ->
        ReviewSection(
            date = date.toString(),
            title = "${date.year}年${Formats.dateWithWeekday(date)}",
            rows = transactions.map { transactionRow(it) },
        )
    }

/** The needs-review record [id] (`Transaction.id` as text), or `null` when it is not marked. */
fun LedgerUiState.reviewNeededTransaction(id: String): Transaction? =
    reviewNeeded.firstOrNull { it.id.toString() == id }

/** Why the record [id] is marked, naming its `差額` item's amount; `null` when it is not marked. */
fun LedgerUiState.reviewExplanation(id: String): ReviewExplanation? {
    val transaction = reviewNeededTransaction(id) ?: return null
    val difference = transaction.items.firstOrNull { isDifferenceItem(it.name) }
    val added = difference?.let { "「$DIFFERENCE_NAME ${Formats.yen(it.amount)}」を足してあります。" }.orEmpty()
    return ReviewExplanation(prefix = EXPLANATION_PREFIX, body = EXPLANATION_REASON + added + EXPLANATION_CLOSING)
}

/** Whether an item named [name] is the `差額` a mismatch added, shown in the warning colour. */
fun isDifferenceItem(name: String?): Boolean = name == DIFFERENCE_NAME
