package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.datetime.LocalDate
import kotlin.uuid.Uuid

// Fixtures shared by the Reporting criteria (AC-B-301 to AC-B-303).

/** Records an expense of [amount] yen in [categoryId] on the ISO date [date]. */
internal suspend fun LedgerScope.recordExpenseOn(
    date: String,
    amount: Long,
    categoryId: Uuid,
) {
    recordTransaction(
        transaction =
            NewTransaction(
                date = LocalDate.parse(date),
                direction = Direction.EXPENSE,
                amount = amount,
                categoryId = categoryId,
            ),
    )
}

/** Records an income of [amount] yen on the ISO date [date]. */
internal suspend fun LedgerScope.recordIncomeOn(
    date: String,
    amount: Long,
) {
    recordTransaction(
        transaction =
            NewTransaction(
                date = LocalDate.parse(date),
                direction = Direction.INCOME,
                amount = amount,
                categoryId = null,
            ),
    )
}
