package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.BudgetLine
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.MonthBudgets
import io.github.mktkhr.moneging.domain.MonthClose
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.YearMonth
import kotlinx.datetime.minus
import kotlinx.datetime.plus
import kotlin.uuid.Uuid

/**
 * A ledger's budgets as the rules of PRODUCT.md §3 read them, from its
 * live budget rows ([budgets], in the order they were set), its closes and
 * its category order.
 *
 * For a month, the budget of a category (or of the whole month, key
 * `null`) is the row set last among those from that month or earlier: a
 * removal means none. What a close carried is added to the same budget of
 * the next month.
 */
internal class BudgetBook(
    private val budgets: List<Budget>,
    /** The ledger's closes, by month. */
    val closes: Map<YearMonth, MonthClose>,
    private val categoryOrder: List<Uuid>,
) {
    /** The latest closed month, or `null` when none is. */
    val lastClosedMonth: YearMonth?
        get() = closes.keys.maxOrNull()

    /**
     * The budgets of [month] given its [spending] by category: the whole
     * month's, then the categories with a budget or spending in category
     * order.
     */
    fun monthBudgets(
        month: YearMonth,
        spending: Map<Uuid, Long>,
    ): MonthBudgets {
        val categories =
            categoryOrder
                .map { categoryId -> line(key = categoryId, month = month, spent = spending[categoryId] ?: 0L) }
                .filter { it.budget != null || it.spent > 0L }
        return MonthBudgets(
            month = month,
            whole = line(key = null, month = month, spent = spending.values.sum()),
            categories = categories,
            isClosed = month in closes,
        )
    }

    /** The earliest open month before [before] that has a budget, or `null`. */
    fun firstOpenMonthWithBudget(before: YearMonth): YearMonth? {
        val first = budgets.minOfOrNull { it.fromMonth } ?: return null
        return generateSequence(first) { it.plus(1, DateTimeUnit.MONTH) }
            .takeWhile { it < before }
            .firstOrNull { month -> month !in closes && hasBudget(month) }
    }

    // Whether [month] has any budget, planned or carried in.
    private fun hasBudget(month: YearMonth): Boolean {
        val carried = carriesInto(month)
        val keys = budgets.map { it.categoryId }.toSet() + carried.keys
        return keys.any { key -> planned(key, month) != null || carried[key] ?: 0L > 0L }
    }

    private fun line(
        key: Uuid?,
        month: YearMonth,
        spent: Long,
    ): BudgetLine {
        val planned = planned(key, month)
        val carriedIn = carriesInto(month)[key] ?: 0L
        return BudgetLine(
            categoryId = key,
            budget = if (planned == null && carriedIn == 0L) null else (planned ?: 0L) + carriedIn,
            carriedIn = carriedIn,
            planned = planned,
            spent = spent,
        )
    }

    // The amount planned for [key] in [month]: the last row set from then or earlier, `null` when it is a removal.
    private fun planned(
        key: Uuid?,
        month: YearMonth,
    ): Long? =
        budgets
            .lastOrNull { it.categoryId == key && it.fromMonth <= month }
            ?.takeIf { !it.isRemoved }
            ?.amount

    // What the close of the month before [month] carried into it, by budget.
    private fun carriesInto(month: YearMonth): Map<Uuid?, Long> {
        val close = closes[month.minus(1, DateTimeUnit.MONTH)] ?: return emptyMap()
        val whole: Map<Uuid?, Long> = if (close.carriedWhole > 0L) mapOf(null to close.carriedWhole) else emptyMap()
        return whole + close.carried
    }
}

/**
 * Closes these budgets under [policy]: [CarryOverPolicy.CARRY] carries each
 * budget's positive leftover into the same budget; [CarryOverPolicy.SAVE]
 * saves the whole month's leftover when it has a budget, else the category
 * budgets' positive leftovers added up. A negative leftover moves nothing.
 */
internal fun MonthBudgets.close(policy: CarryOverPolicy): MonthClose {
    val leftovers = categories.associate { it.categoryId to (it.remaining ?: 0L) }.filterValues { it > 0L }
    val wholeLeftover = (whole.remaining ?: 0L).coerceAtLeast(0L)
    val carried = leftovers.mapNotNull { (key, amount) -> key?.let { it to amount } }.toMap()
    return when (policy) {
        CarryOverPolicy.CARRY -> {
            MonthClose(month = month, policy = policy, carried = carried, carriedWhole = wholeLeftover, saved = 0L)
        }

        CarryOverPolicy.SAVE -> {
            val saved = if (whole.budget != null) wholeLeftover else carried.values.sum()
            MonthClose(month = month, policy = policy, carried = emptyMap(), carriedWhole = 0L, saved = saved)
        }
    }
}
