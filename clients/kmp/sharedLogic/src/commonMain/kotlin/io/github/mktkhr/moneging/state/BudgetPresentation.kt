package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.BudgetLine
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.Formats
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.number
import kotlinx.datetime.plus

// How the budget view and its sheets show the budgets (PRODUCT.md §5,
// Formats and Budgets), the same on every client: the texts are composed
// here, the platforms only draw them.

/** The whole-month budget's name. */
internal const val WHOLE_NAME = "月全体"

private const val NO_BUDGET = "予算なし"
private const val SEPARATOR = "・"
private const val UNSET = "未設定"

/** One budget, or a category spent without one, as the budget view shows it. */
data class BudgetRow(
    /** Its category (`Category.id` as text); `null` for the whole month. */
    val categoryId: String?,
    /** The category's name; for the whole month its title (`2月の予算`). */
    val name: String,
    /** The default category it shows the icon of (`Category.defaultIndex`), or `null`. */
    val iconIndex: Int?,
    /** Whether it has a budget. */
    val hasBudget: Boolean,
    /** Whether more was spent than budgeted. */
    val isOver: Boolean,
    /**
     * What it reads first: `残り 11,500円`, `1,500円オーバー`, or, without a
     * budget, what was spent (`3,000円`).
     */
    val headline: String,
    /** The budget (`予算 30,000円`), or `null` without one. */
    val budgetText: String?,
    /** What was spent (`使った 18,500円`). */
    val spentText: String,
    /** What was carried in (`繰り越し 11,500円 を含む`), or `null` when nothing was. */
    val carriedText: String?,
    /** The line under the headline: `予算 30,000円・使った 18,500円`, or `予算なし`. */
    val detail: String,
    /** How much of the budget is spent, 0 to 1; 0 without a budget. */
    val progress: Double,
    /** What a screen reader says: `食費 残り 11,500円 予算 30,000円 使った 18,500円`, or `交通費 使った 3,000円`. */
    val accessibilityLabel: String,
)

/** The whole-month budget as the top of the budget view shows it. */
data class WholeBudget(
    /** Its title (`2月の予算`). */
    val title: String,
    /** Whether a whole-month budget is set. */
    val hasBudget: Boolean,
    /** Whether more was spent than budgeted. */
    val isOver: Boolean,
    /** The word before [amountText] (`残り`), or `null` when it is overspent or unset. */
    val caption: String?,
    /** What is left (`28,500円`), the overspending (`1,500円オーバー`), or `未設定`. */
    val amountText: String,
    /** The budget (`予算 50,000円`), or `null` when unset. */
    val budgetText: String?,
    /** What the month spent (`使った 21,500円`). */
    val spentText: String,
    /** What was carried in (`繰り越し 6,000円 を含む`), or `null`. */
    val carriedText: String?,
    /** What choosing it does: `変更`, or `設定` when unset. */
    val actionText: String,
    /** How much of the budget is spent, 0 to 1. */
    val progress: Double,
    /** What a screen reader says: `2月の予算 残り 28,500円 予算 50,000円 使った 21,500円`. */
    val accessibilityLabel: String,
)

/** The offer to close a month, at the top of the budget view. */
data class CloseOffer(
    /** The month offered, ISO (`2026-02`). */
    val month: String,
    /** `2月を締めましょう`. */
    val title: String,
    /** What the carry-over policy will do (`残りは各予算に繰り越します`). */
    val note: String,
    /** What a screen reader says: the title and the note. */
    val accessibilityLabel: String,
)

/** The budget view of the month in view. */
data class BudgetView(
    /** The offer to close a month, or `null` when there is nothing to close. */
    val closeOffer: CloseOffer?,
    /** The whole-month budget, shown even when unset. */
    val whole: WholeBudget,
    /** Every category with a budget or with spending, in category order. */
    val rows: List<BudgetRow>,
    /** The ledger's savings (`貯金 11,500円`, at 0 too). */
    val savingsText: String,
    /** The savings' amount alone (`11,500円`). */
    val savingsAmountText: String,
)

/** The sheet of one budget. */
data class BudgetSheet(
    /** `食費の予算`, `月全体の予算`. */
    val title: String,
    /** The category's name, or `null` for the whole month. */
    val categoryName: String?,
    /** The default category it shows the icon of, or `null`. */
    val iconIndex: Int?,
    /** The amount set for the month in view, without what was carried in, as digits; empty when unset. */
    val amountText: String,
    /** Whether a budget is set for the month in view. */
    val hasBudget: Boolean,
)

/** The budget view of the month read, on [todayIso]; `null` before the budgets are read. */
fun LedgerUiState.budgetView(todayIso: String): BudgetView? {
    val budgets = budgets ?: return null
    val today = LocalDate.parse(todayIso)
    return BudgetView(
        closeOffer = closing?.let { closeOffer(month = it.month, today = today) },
        whole = wholeBudget(line = budgets.whole, title = "${monthName(budgets.month, today)}の予算"),
        rows = budgets.categories.map { budgetRow(it) },
        savingsText = "貯金 ${Formats.yen(savings.balance)}",
        savingsAmountText = Formats.yen(savings.balance),
    )
}

/** The sheet of the budget of [categoryId] (`null`: the whole month) in the month read. */
fun LedgerUiState.budgetSheet(categoryId: String?): BudgetSheet {
    val category = category(categoryId)
    val line =
        budgets?.let { month ->
            if (categoryId == null) month.whole else month.categories.firstOrNull { it.categoryId == category?.id }
        }
    val planned = line?.run { budget?.takeIf { it != carriedIn }?.minus(carriedIn) }
    return BudgetSheet(
        title = "${category?.name ?: WHOLE_NAME}の予算",
        categoryName = category?.name,
        iconIndex = category?.defaultIndex,
        amountText = planned?.toString().orEmpty(),
        hasBudget = planned != null,
    )
}

// A month as the budget view names it: `2月`, with its year when it is not today's (`2025年12月`).
internal fun monthName(
    month: YearMonth,
    today: LocalDate,
): String = if (month.year == today.year) "${month.month.number}月" else Formats.month(month)

private fun LedgerUiState.closeOffer(
    month: YearMonth,
    today: LocalDate,
): CloseOffer {
    val title = "${monthName(month, today)}を締めましょう"
    val note =
        when (carryOverPolicy) {
            CarryOverPolicy.CARRY -> "残りは各予算に繰り越します"
            CarryOverPolicy.SAVE -> "残りは貯金にします"
        }
    return CloseOffer(month = month.toString(), title = title, note = note, accessibilityLabel = "$title $note")
}

private fun wholeBudget(
    line: BudgetLine,
    title: String,
): WholeBudget {
    val remaining = line.remaining
    val spentText = "使った ${Formats.yen(line.spent)}"
    val budgetText = line.budget?.let { "予算 ${Formats.yen(it)}" }
    val isOver = remaining != null && remaining < 0L
    val caption = if (remaining != null && !isOver) "残り" else null
    val amountText =
        when {
            remaining == null -> UNSET
            isOver -> overText(remaining)
            else -> Formats.yen(remaining)
        }
    return WholeBudget(
        title = title,
        hasBudget = line.budget != null,
        isOver = isOver,
        caption = caption,
        amountText = amountText,
        budgetText = budgetText,
        spentText = spentText,
        carriedText = carriedText(line),
        actionText = if (line.budget == null) "設定" else "変更",
        progress = progress(line),
        accessibilityLabel = listOfNotNull(title, caption, amountText, budgetText, spentText).joinToString(" "),
    )
}

private fun LedgerUiState.budgetRow(line: BudgetLine): BudgetRow {
    val category = categories.firstOrNull { it.id == line.categoryId }
    val name = category?.name.orEmpty()
    val remaining = line.remaining
    val budgetText = line.budget?.let { "予算 ${Formats.yen(it)}" }
    val spentText = "使った ${Formats.yen(line.spent)}"
    val headline =
        when {
            remaining == null -> Formats.yen(line.spent)
            remaining < 0L -> overText(remaining)
            else -> "残り ${Formats.yen(remaining)}"
        }
    val label =
        if (budgetText == null) {
            "$name $spentText"
        } else {
            "$name $headline $budgetText $spentText"
        }
    return BudgetRow(
        categoryId = line.categoryId?.toString(),
        name = name,
        iconIndex = category?.defaultIndex,
        hasBudget = budgetText != null,
        isOver = remaining != null && remaining < 0L,
        headline = headline,
        budgetText = budgetText,
        spentText = spentText,
        carriedText = carriedText(line),
        detail = budgetText?.let { "$it$SEPARATOR$spentText" } ?: NO_BUDGET,
        progress = progress(line),
        accessibilityLabel = label,
    )
}

// `1,500円オーバー` for a remaining of −1,500.
private fun overText(remaining: Long): String = "${Formats.yen(-remaining)}オーバー"

private fun carriedText(line: BudgetLine): String? =
    line.carriedIn.takeIf { it > 0L }?.let { "繰り越し ${Formats.yen(it)} を含む" }

private fun progress(line: BudgetLine): Double {
    val budget = line.budget ?: return 0.0
    return when {
        budget > 0L -> (line.spent.toDouble() / budget.toDouble()).coerceIn(minimumValue = 0.0, maximumValue = 1.0)
        line.spent > 0L -> 1.0
        else -> 0.0
    }
}
