package io.github.mktkhr.moneging.domain

import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

// What the reports read (PRODUCT.md §2, Reports): spending only, split items
// counted in their own category; income never counts.

/** One category's spending in a month. */
data class CategoryTotal(
    /** The category. */
    val categoryId: Uuid,
    /** Its spending in yen. */
    val amount: Long,
)

/** A month's spending by category. */
data class MonthlyReport(
    /** The month it is of. */
    val month: YearMonth,
    /** Each category with spending, largest first; equal ones in the ledger's order. */
    val categories: List<CategoryTotal>,
    /** The month's whole spending in yen. */
    val expenseTotal: Long,
)

/** One day's spending. */
data class DailyTotal(
    /** The day. */
    val date: LocalDate,
    /** Its spending in yen; 0 for a day without any. */
    val amount: Long,
)

/** One month's spending. */
data class MonthlyTotal(
    /** The month. */
    val month: YearMonth,
    /** Its spending in yen; 0 for a month without any. */
    val amount: Long,
)

/** Shares as whole percentages. */
object Shares {
    private const val WHOLE = 100L

    /**
     * Each of [amounts] as a whole percentage of their sum, the percentages
     * adding up to 100 (PRODUCT.md §5): each is rounded down, and the points
     * left over go one each to the largest remainders, the earlier first on
     * a tie. All 0 when the sum is 0.
     */
    fun percentages(amounts: List<Long>): List<Int> {
        val total = amounts.sum()
        if (total <= 0L) return amounts.map { 0 }
        val floors = amounts.map { it * WHOLE / total }
        val remainders = amounts.map { it * WHOLE % total }
        val leftOver = (WHOLE - floors.sum()).toInt()
        val bumped =
            remainders.indices
                .sortedWith(compareByDescending<Int> { remainders[it] }.thenBy { it })
                .take(leftOver)
                .toSet()
        return floors.mapIndexed { index, floor -> (floor + if (index in bumped) 1L else 0L).toInt() }
    }
}
