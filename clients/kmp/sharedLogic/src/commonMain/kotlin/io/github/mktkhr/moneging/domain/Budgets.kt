package io.github.mktkhr.moneging.domain

import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

// Budgets, closing a month and savings (PRODUCT.md §3: Budget, Carry-over
// policy, Savings).

/** What happens to a month's leftover when the month closes. */
enum class CarryOverPolicy {
    /** Each budget's leftover moves into the same budget next month (繰り越す). */
    CARRY,

    /** The leftover moves to savings (貯金にする). */
    SAVE,
}

/** One budget of a month, or a category spent in it without one. */
data class BudgetLine(
    /** Its category; `null` for the whole-month budget. */
    val categoryId: Uuid?,
    /** The budget in yen, what was carried in included; `null` when there is none. */
    val budget: Long?,
    /** What was carried into it from the month before, in yen; 0 when nothing was. */
    val carriedIn: Long,
    /** What was spent against it in yen: the category's expenses (split items included), or every expense. */
    val spent: Long,
) {
    /** What is left in yen, negative when overspent; `null` without a budget. */
    val remaining: Long?
        get() = budget?.let { it - spent }
}

/** A month's budgets. */
data class MonthBudgets(
    /** The month they are of. */
    val month: YearMonth,
    /** The whole-month budget, shown even when none is set ([BudgetLine.budget] `null`). */
    val whole: BudgetLine,
    /** Every category with a budget or with spending in the month, in the ledger's category order. */
    val categories: List<BudgetLine>,
    /** Whether the month is closed: its budgets are final. */
    val isClosed: Boolean,
) {
    /** Whether the month has any budget: the whole month's or a category's. */
    val hasBudget: Boolean
        get() = whole.budget != null || categories.any { it.budget != null }
}

/** What closing a month did; closing it again reports the same. */
data class MonthClose(
    /** The month closed. */
    val month: YearMonth,
    /** The policy it was closed under. */
    val policy: CarryOverPolicy,
    /** What each category budget carried into the next month, in yen; only positive leftovers. */
    val carried: Map<Uuid, Long>,
    /** What the whole-month budget carried into the next month, in yen. */
    val carriedWhole: Long,
    /** What moved to savings, in yen. */
    val saved: Long,
)

/** One month's addition to savings. */
data class SavingsContribution(
    /** The month closed. */
    val month: YearMonth,
    /** The amount saved, in yen. */
    val amount: Long,
)

/** A ledger's savings: it only grows, by closing months under [CarryOverPolicy.SAVE]. */
data class Savings(
    /** The balance in yen. */
    val balance: Long,
    /** Every contribution, oldest month first. */
    val contributions: List<SavingsContribution>,
)
