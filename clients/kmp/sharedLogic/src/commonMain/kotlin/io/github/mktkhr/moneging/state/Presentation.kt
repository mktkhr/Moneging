package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.RecurringSchedule
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.datetime.LocalDate

// How the screens show a ledger's records, the same on every client: the
// texts are composed here, the platforms only lay them out.

private const val LABEL_SEPARATOR = "、"
private const val INCOME_NAME = "収入"
private const val RECURRING_MARK = "定期"

/** One transaction as a list shows it. */
data class TransactionRow(
    /** The transaction's `Transaction.id`, as text. */
    val id: String,
    /** Its date, ISO (`2026-02-14`). */
    val date: String,
    /** Its amount: `1,200円`, an income's `+5,000円`. */
    val amountText: String,
    /** Its category's name, the categories of its items, or `収入`. */
    val title: String,
    /** Its store name and memo, joined, or `null`. */
    val detail: String?,
    /** Whether it is an income. */
    val isIncome: Boolean,
    /** Whether a recurring rule recorded it (`定期`). */
    val isRecurring: Boolean,
    /** The default category it shows the icon of ([Category.defaultIndex]), or `null`. */
    val iconIndex: Int?,
    /** Everything a screen reader says for it: amount, category or 収入, store, memo, 定期. */
    val accessibilityLabel: String,
)

/** One day of a month's transactions. */
data class DaySection(
    /** The day, ISO. */
    val date: String,
    /** The day as `2月14日（土）`. */
    val title: String,
    /** The day's expenses (`3,000円`), or `null` when it has none. */
    val totalText: String?,
    /** Its transactions, newest first. */
    val rows: List<TransactionRow>,
)

/** One recurring rule as 毎月の定期 lists it. */
data class RecurringRuleRow(
    /** The rule's `RecurringRule.id`, as text. */
    val id: String,
    /** Its amount and category: `80,000円 住居`, `250,000円 収入`. */
    val title: String,
    /** When it falls: `毎月25日・土日祝なら翌平日`. */
    val schedule: String,
    /** Its next date (`3月25日（水）`), or `null` when it has ended. */
    val nextDate: String?,
    /** Until when an ended one applied (`2026年2月まで`), or `null` while it has not ended. */
    val endedText: String?,
    /** Whether it is an income. */
    val isIncome: Boolean,
    /** The default category it shows the icon of, or `null`. */
    val iconIndex: Int?,
    /**
     * Everything a screen reader says: `毎月25日 80,000円 住居、土日祝なら翌平日、次回 3月25日（水）`,
     * or `…、2026年2月まで` for an ended one.
     */
    val accessibilityLabel: String,
) {
    /** Whether it has ended: it records nothing more. */
    val isEnded: Boolean get() = nextDate == null
}

/** A recurring rule as its sheet opens it to be changed, ended or deleted. */
data class RecurringRuleEditing(
    /** The rule's `RecurringRule.id`, as text. */
    val id: String,
    /** What the form starts with. */
    val draft: RecurringRuleDraft,
    /** The rule as `毎月25日 80,000円 住居`. */
    val summary: String,
    /** Its next date (`2月25日`), or `null` when it has ended. */
    val nextDate: String?,
) {
    /** Whether it has ended: it records nothing more. */
    val isEnded: Boolean get() = nextDate == null
}

/** The month's transactions as [TransactionRow]s grouped by day, newest day first. */
fun LedgerUiState.daySections(): List<DaySection> =
    transactions.groupBy { it.date }.map { (date, dayTransactions) ->
        val expense = dayTransactions.filter { it.direction == Direction.EXPENSE }.sumOf { it.amount }
        DaySection(
            date = date.toString(),
            title = Formats.dateWithWeekday(date),
            totalText = if (expense > 0L) Formats.yen(expense) else null,
            rows = dayTransactions.map { transactionRow(it) },
        )
    }

/** [transaction] as a list shows it. */
fun LedgerUiState.transactionRow(transaction: Transaction): TransactionRow {
    val isIncome = transaction.direction == Direction.INCOME
    val amountText = (if (isIncome) "+" else "") + Formats.yen(transaction.amount)
    val categoryIds = listOfNotNull(transaction.categoryId) + transaction.items.map { it.categoryId }
    val categories = categoryIds.distinct().mapNotNull { id -> categories.firstOrNull { it.id == id } }
    val title = if (isIncome) INCOME_NAME else categories.joinToString(separator = "・") { it.name }
    val detail = listOfNotNull(transaction.storeName, transaction.memo).joinToString(separator = " ・ ").ifEmpty { null }
    val isRecurring = transaction.recurringRuleId != null
    return TransactionRow(
        id = transaction.id.toString(),
        date = transaction.date.toString(),
        amountText = amountText,
        title = title,
        detail = detail,
        isIncome = isIncome,
        isRecurring = isRecurring,
        iconIndex = categories.singleOrNull()?.defaultIndex,
        accessibilityLabel =
            listOfNotNull(
                amountText,
                title,
                transaction.storeName,
                transaction.memo,
                RECURRING_MARK.takeIf { isRecurring },
            ).joinToString(separator = LABEL_SEPARATOR),
    )
}

/** The ledger's recurring rule [id] as its sheet opens it, with its next date after [todayIso]; `null` when gone. */
fun LedgerUiState.recurringRuleEditing(
    id: String,
    todayIso: String,
): RecurringRuleEditing? {
    val rule = recurringRules.firstOrNull { it.id.toString() == id } ?: return null
    val category = rule.categoryId?.let { categoryId -> categories.firstOrNull { it.id == categoryId } }
    return RecurringRuleEditing(
        id = id,
        draft = rule.toDraft(),
        summary = Formats.recurringRule(rule = rule, categoryName = category?.name),
        nextDate = RecurringSchedule.nextDate(rule = rule, today = LocalDate.parse(todayIso))?.let { Formats.date(it) },
    )
}

/** The ledger's recurring rules as 毎月の定期 lists them, with their next date after [today]. */
fun LedgerUiState.recurringRuleRows(today: LocalDate): List<RecurringRuleRow> =
    recurringRules.map { rule -> recurringRuleRow(rule = rule, today = today) }

/** The rows of [recurringRuleRows] for today given as ISO text. */
fun LedgerUiState.recurringRuleRows(todayIso: String): List<RecurringRuleRow> =
    recurringRuleRows(LocalDate.parse(todayIso))

private fun LedgerUiState.recurringRuleRow(
    rule: RecurringRule,
    today: LocalDate,
): RecurringRuleRow {
    val category = rule.categoryId?.let { id -> categories.firstOrNull { it.id == id } }
    val isIncome = rule.direction == Direction.INCOME
    val adjustment = Formats.adjustment(rule.adjustment)
    val nextDate = RecurringSchedule.nextDate(rule = rule, today = today)?.let { Formats.dateWithWeekday(it) }
    val endedText = rule.endMonth?.takeIf { nextDate == null }?.let { "${Formats.month(it)}まで" }
    return RecurringRuleRow(
        id = rule.id.toString(),
        title = "${Formats.yen(rule.amount)} ${if (isIncome) INCOME_NAME else category?.name.orEmpty()}".trimEnd(),
        schedule = listOfNotNull(Formats.recurringDay(rule.dayOfMonth), adjustment).joinToString(separator = "・"),
        nextDate = nextDate,
        endedText = endedText,
        isIncome = isIncome,
        iconIndex = category?.defaultIndex,
        accessibilityLabel =
            listOfNotNull(
                Formats.recurringRule(rule = rule, categoryName = category?.name),
                adjustment,
                nextDate?.let { "次回 $it" },
                endedText,
            ).joinToString(separator = LABEL_SEPARATOR),
    )
}

/** The name of the category [id] (`Category.id` as text), or `null`. */
fun LedgerUiState.categoryName(id: String?): String? = category(id)?.name
