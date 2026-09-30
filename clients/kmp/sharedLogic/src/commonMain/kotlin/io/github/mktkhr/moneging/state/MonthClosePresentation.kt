package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.Formats
import io.github.mktkhr.moneging.domain.MonthBudgets
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlinx.datetime.plus
import kotlin.uuid.Uuid

// How the sheet that closes a month and the budget sheet word things
// (PRODUCT.md §5, Budgets), the same on every client.

/** One budget's leftover as the sheet that closes a month lists it. */
data class CloseLine(
    /** Its category (`Category.id` as text), or `null` for the whole month. */
    val categoryId: String?,
    /** `食費 の残り`, `月全体 の残り`. */
    val title: String,
    /** The leftover (`11,500円`), a negative one `−1,500円（動かしません）`. */
    val amountText: String,
    /** Whether the leftover moves: it is positive. */
    val isMoving: Boolean,
)

/** The sheet that asks before closing a month. */
data class CloseSheet(
    /** The month closed, ISO. */
    val month: String,
    /** `2月を締める`: its title, and its button's. */
    val title: String,
    /** `2月の残りを締めます。`. */
    val intro: String,
    /** Each budget's leftover, the whole month first. */
    val lines: List<CloseLine>,
    /** What `繰り越す` does. */
    val carryNote: String,
    /** What `貯金にする` does. */
    val saveNote: String,
)

/** The sheet asking before closing the month offered, on [todayIso]; `null` when none is. */
fun LedgerUiState.closeSheet(todayIso: String): CloseSheet? {
    val closing = closing ?: return null
    val name = monthName(closing.month, LocalDate.parse(todayIso))
    val nextName = monthName(closing.month.plus(1, DateTimeUnit.MONTH), LocalDate.parse(todayIso))
    val lines = closeLines(closing)
    return CloseSheet(
        month = closing.month.toString(),
        title = "${name}を締める",
        intro = "${name}の残りを締めます。",
        lines = lines,
        carryNote = "繰り越す: ${nextName}の予算に、それぞれの残りを足します${carryExample(closing)}。",
        saveNote = "貯金にする: ${saveDescription(closing)}",
    )
}

/** Texts of the budgets that need no records. */
object BudgetTexts {
    /** The removal of a budget from the ISO month [fromMonthIso] on, as `2月から予算をなくす`, on [todayIso]. */
    fun removeTitle(
        fromMonthIso: String,
        todayIso: String,
    ): String = "${monthName(YearMonth.parse(fromMonthIso), LocalDate.parse(todayIso))}から予算をなくす"

    /** The month a budget starts, as `2026年2月から`. */
    fun fromMonth(fromMonthIso: String): String = "${Formats.month(YearMonth.parse(fromMonthIso))}から"
}

private fun LedgerUiState.lineName(categoryId: Uuid?): String =
    if (categoryId == null) WHOLE_NAME else categories.firstOrNull { it.id == categoryId }?.name.orEmpty()

private fun LedgerUiState.closeLines(closing: MonthBudgets): List<CloseLine> =
    (listOf(closing.whole) + closing.categories)
        .filter { it.budget != null }
        .map { line ->
            val remaining = line.remaining ?: 0L
            CloseLine(
                categoryId = line.categoryId?.toString(),
                title = "${lineName(line.categoryId)} の残り",
                amountText = if (remaining < 0L) "${Formats.yen(remaining)}（動かしません）" else Formats.yen(remaining),
                isMoving = remaining > 0L,
            )
        }

// `（食費 30,000円 → 41,500円）` for the first leftover that moves into a budget next month, or empty.
private fun LedgerUiState.carryExample(closing: MonthBudgets): String {
    val next = closingNext ?: return ""
    val nextLines = listOf(next.whole) + next.categories
    val example =
        (listOf(closing.whole) + closing.categories)
            .asSequence()
            .filter { it.remaining ?: 0L > 0L }
            .firstNotNullOfOrNull { line ->
                nextLines.firstOrNull { it.categoryId == line.categoryId }?.budget?.let { budget ->
                    val after = budget + (line.remaining ?: 0L)
                    "（${lineName(line.categoryId)} ${Formats.yen(budget)} → ${Formats.yen(after)}）"
                }
            }
    return example.orEmpty()
}

// What saving moves: the whole month's leftover when it has a budget, else the category budgets' added up.
private fun saveDescription(closing: MonthBudgets): String {
    val saved =
        if (closing.whole.budget != null) {
            (closing.whole.remaining ?: 0L).coerceAtLeast(0L)
        } else {
            closing.categories.sumOf { (it.remaining ?: 0L).coerceAtLeast(0L) }
        }
    val what = if (closing.whole.budget != null) "月全体の残り" else "分類の残り"
    return if (saved > 0L) "$what ${Formats.yen(saved)} を貯金に入れます。" else "貯金に入れる残りはありません。"
}
