package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.AmountText
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

/**
 * The writes of the budgets and the month closes of the ledger in view
 * ([LedgerEditor.budgets]); each returns `null` when it is done, or the
 * reason it was refused.
 */
class BudgetEditor internal constructor(
    private val write: suspend (suspend LedgerScope.() -> Any) -> String?,
) {
    /**
     * Sets the budget of [categoryId] (`Category.id` as text; `null` for
     * the whole month) to [amountText] from the ISO month [fromMonth] on.
     */
    @Throws(Exception::class)
    suspend fun setBudget(
        categoryId: String?,
        amountText: String,
        fromMonth: String,
    ): String? =
        write {
            setBudget(
                categoryId = categoryId?.let { Uuid.parse(it) },
                amount = AmountText.parse(amountText),
                from = YearMonth.parse(fromMonth),
            )
        }

    /** Removes the budget of [categoryId] (`null` for the whole month) from the ISO month [fromMonth] on. */
    @Throws(Exception::class)
    suspend fun removeBudget(
        categoryId: String?,
        fromMonth: String,
    ): String? =
        write { removeBudget(categoryId = categoryId?.let { Uuid.parse(it) }, from = YearMonth.parse(fromMonth)) }

    /** Changes the ledger's carry-over policy. */
    @Throws(Exception::class)
    suspend fun setCarryOverPolicy(policy: CarryOverPolicy): String? = write { setCarryOverPolicy(policy = policy) }

    /** Keeps [policy] as the ledger's carry-over policy, then closes the ISO month [month] under it. */
    @Throws(Exception::class)
    suspend fun closeMonth(
        month: String,
        policy: CarryOverPolicy,
    ): String? =
        write {
            setCarryOverPolicy(policy = policy)
            closeMonth(month = YearMonth.parse(month))
        }
}
