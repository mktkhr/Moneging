package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.MonthBudgets
import io.github.mktkhr.moneging.domain.MonthClose
import io.github.mktkhr.moneging.domain.Savings
import io.github.mktkhr.moneging.domain.SavingsContribution
import kotlinx.coroutines.withContext
import kotlinx.datetime.YearMonth
import kotlinx.datetime.yearMonth
import kotlin.uuid.Uuid

private const val CLOSED_MONTH = "締めた月の予算は変えられません"
private const val NOT_ENDED = "まだ終わっていない月は締められません"
private const val EARLIER_OPEN = "前の月を先に締めてください"

/** [LedgerPlans] over the database. */
internal class SqlPlans(
    private val rows: LedgerRows,
) : LedgerPlans {
    override suspend fun setBudget(
        categoryId: Uuid?,
        amount: Long,
        from: YearMonth,
    ): Budget {
        require(amount >= 0L) { "予算は0円以上にしてください" }
        return withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                categoryId?.let { rows.requireActiveCategory(it) }
                insertBudget(categoryId = categoryId, amount = amount, from = from, isRemoved = false)
            }
        }
    }

    override suspend fun removeBudget(
        categoryId: Uuid?,
        from: YearMonth,
    ): Budget =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                categoryId?.let { rows.requireCategory(it) }
                insertBudget(categoryId = categoryId, amount = 0L, from = from, isRemoved = true)
            }
        }

    override suspend fun budgetRemaining(month: YearMonth): MonthBudgets =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                budgetBook(
                    rows,
                ).monthBudgets(month = month, spending = spendingOf(rows, month))
            }
        }

    // Inserts a budget row, refused when a month from [from] on is closed.
    private fun insertBudget(
        categoryId: Uuid?,
        amount: Long,
        from: YearMonth,
        isRemoved: Boolean,
    ): Budget {
        val lastClosed = budgetBook(rows).lastClosedMonth
        check(lastClosed == null || lastClosed < from) { CLOSED_MONTH }
        val now = rows.now()
        val budget =
            Budget(
                id = Uuid.random(),
                ledgerId = rows.ledgerId,
                categoryId = categoryId,
                amount = amount,
                fromMonth = from,
                createdAt = now,
                updatedAt = now,
                isRemoved = isRemoved,
            )
        rows.database.budgetsQueries.insertBudget(
            id = budget.id.toString(),
            ledger_id = rows.ledgerKey,
            category_id = categoryId?.toString(),
            amount = amount,
            from_month = from.toString(),
            created_at = now.toColumn(),
            updated_at = now.toColumn(),
            is_removed = isRemoved.toColumn(),
        )
        return budget
    }
}

/** [LedgerMonthCloses] over the database. */
internal class SqlMonthCloses(
    private val rows: LedgerRows,
) : LedgerMonthCloses {
    private val closes = rows.database.monthClosesQueries

    override suspend fun carryOverPolicy(): CarryOverPolicy =
        withContext(rows.context) {
            rows.database.transactionWithResult { policyOf(rows) }
        }

    override suspend fun setCarryOverPolicy(policy: CarryOverPolicy) {
        withContext(rows.context) {
            rows.database.transaction {
                rows.requireLedger()
                rows.database.ledgersQueries.setCarryOverPolicy(
                    carry_over_policy = policy.name,
                    updated_at = rows.now().toColumn(),
                    id = rows.ledgerKey,
                )
            }
        }
    }

    override suspend fun closeMonth(month: YearMonth): MonthClose =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                rows.requireLedger()
                val book = budgetBook(rows)
                book.closes[month] ?: run {
                    check(month < rows.today().yearMonth) { NOT_ENDED }
                    check(book.firstOpenMonthWithBudget(before = month) == null) { EARLIER_OPEN }
                    val close =
                        book
                            .monthBudgets(month = month, spending = spendingOf(rows, month))
                            .close(policy = policyOf(rows))
                    insertClose(close)
                    close
                }
            }
        }

    override suspend fun isMonthClosed(month: YearMonth): Boolean =
        withContext(rows.context) {
            closes.liveMonthClose(ledger_id = rows.ledgerKey, month = month.toString()).executeAsOneOrNull() != null
        }

    override suspend fun monthToClose(): YearMonth? =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                budgetBook(rows).firstOpenMonthWithBudget(before = rows.today().yearMonth)
            }
        }

    override suspend fun savings(): Savings =
        withContext(rows.context) {
            val contributions =
                closes
                    .liveMonthCloses(rows.ledgerKey)
                    .executeAsList()
                    .filter { it.saved > 0L }
                    .map { SavingsContribution(month = YearMonth.parse(it.month), amount = it.saved) }
            Savings(balance = contributions.sumOf { it.amount }, contributions = contributions)
        }

    private fun insertClose(close: MonthClose) {
        val now = rows.now().toColumn()
        val closeId = Uuid.random().toString()
        closes.insertMonthClose(
            id = closeId,
            ledger_id = rows.ledgerKey,
            month = close.month.toString(),
            policy = close.policy.name,
            saved = close.saved,
            created_at = now,
            updated_at = now,
        )
        val carries = close.carried.map { (categoryId, amount) -> categoryId.toString() to amount }
        val whole = listOf(null to close.carriedWhole).filter { (_, amount) -> amount > 0L }
        (whole + carries).forEach { (categoryId, amount) ->
            closes.insertCarry(
                id = Uuid.random().toString(),
                close_id = closeId,
                category_id = categoryId,
                amount = amount,
                created_at = now,
                updated_at = now,
            )
        }
    }
}

// The ledger's carry-over policy.
internal fun policyOf(rows: LedgerRows): CarryOverPolicy {
    val policy =
        rows.database.ledgersQueries
            .carryOverPolicy(rows.ledgerKey)
            .executeAsOneOrNull()
    return CarryOverPolicy.valueOf(requireNotNull(policy) { "家計簿が見つかりません" })
}

// The ledger's live budget rows and closes, read within the caller's transaction.
internal fun budgetBook(rows: LedgerRows): BudgetBook {
    val closes = rows.database.monthClosesQueries
    return BudgetBook(
        budgets =
            rows.database.budgetsQueries
                .liveBudgets(rows.ledgerKey)
                .executeAsList()
                .map { it.toDomain() },
        closes =
            closes.liveMonthCloses(rows.ledgerKey).executeAsList().associate { row ->
                val carries = closes.carriesOf(row.id).executeAsList()
                val month = YearMonth.parse(row.month)
                month to
                    MonthClose(
                        month = month,
                        policy = CarryOverPolicy.valueOf(row.policy),
                        carried =
                            carries
                                .mapNotNull { carry -> carry.category_id?.let { it.toUuid() to carry.amount } }
                                .toMap(),
                        carriedWhole = carries.filter { it.category_id == null }.sumOf { it.amount },
                        saved = row.saved,
                    )
            },
        categoryOrder =
            rows.database.categoriesQueries
                .liveCategories(rows.ledgerKey)
                .executeAsList()
                .map { it.id.toUuid() },
    )
}

// The spending of [month] by category, read within the caller's transaction.
internal fun spendingOf(
    rows: LedgerRows,
    month: YearMonth,
): Map<Uuid, Long> {
    val query =
        rows.database.transactionsQueries.expenseByCategoryBetween(
            ledgerId = rows.ledgerKey,
            fromDate = month.firstDay.toString(),
            toDate = month.lastDay.toString(),
        )
    return query.executeAsList().associate { row -> row.category_id.toUuid() to row.total }
}
