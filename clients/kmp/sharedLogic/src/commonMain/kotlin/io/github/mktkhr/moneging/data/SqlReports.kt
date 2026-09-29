package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.domain.CategoryTotal
import io.github.mktkhr.moneging.domain.DailyTotal
import io.github.mktkhr.moneging.domain.MonthlyReport
import io.github.mktkhr.moneging.domain.MonthlyTotal
import kotlinx.coroutines.withContext
import kotlinx.datetime.DateTimeUnit
import kotlinx.datetime.YearMonth
import kotlinx.datetime.minus
import kotlinx.datetime.plus

// The months a trend covers, the last one included.
private const val TREND_MONTHS = 12

/** [LedgerReports] over the database. */
internal class SqlReports(
    private val rows: LedgerRows,
) : LedgerReports {
    private val queries = rows.database.transactionsQueries

    override suspend fun monthlyReport(month: YearMonth): MonthlyReport =
        withContext(rows.context) {
            rows.database.transactionWithResult {
                val byCategory =
                    queries.expenseByCategoryBetween(
                        ledgerId = rows.ledgerKey,
                        fromDate = month.firstDay.toString(),
                        toDate = month.lastDay.toString(),
                    )
                val totals =
                    byCategory
                        .executeAsList()
                        .map { row -> CategoryTotal(categoryId = row.category_id.toUuid(), amount = row.total) }
                        .filter { it.amount > 0L }
                val order =
                    rows.database.categoriesQueries
                        .liveCategories(rows.ledgerKey)
                        .executeAsList()
                        .mapIndexed { index, category -> category.id.toUuid() to index }
                        .toMap()
                MonthlyReport(
                    month = month,
                    categories =
                        totals.sortedWith(
                            compareByDescending<CategoryTotal> { it.amount }
                                .thenBy { order[it.categoryId] ?: Int.MAX_VALUE },
                        ),
                    expenseTotal = totals.sumOf { it.amount },
                )
            }
        }

    override suspend fun dailyTotals(month: YearMonth): List<DailyTotal> =
        withContext(rows.context) {
            val query =
                queries.expenseByDateBetween(
                    ledgerId = rows.ledgerKey,
                    fromDate = month.firstDay.toString(),
                    toDate = month.lastDay.toString(),
                )
            val byDate =
                query
                    .executeAsList()
                    .associate { row -> row.date to row.total }
            month.days.map { date -> DailyTotal(date = date, amount = byDate[date.toString()] ?: 0L) }
        }

    override suspend fun monthlyTrend(to: YearMonth): List<MonthlyTotal> =
        withContext(rows.context) {
            val from = to.minus(TREND_MONTHS - 1, DateTimeUnit.MONTH)
            val query =
                queries.expenseByMonthBetween(
                    ledgerId = rows.ledgerKey,
                    fromDate = from.firstDay.toString(),
                    toDate = to.lastDay.toString(),
                )
            val byMonth =
                query
                    .executeAsList()
                    .associate { row -> row.month to row.total }
            (0 until TREND_MONTHS).map { offset ->
                val month = from.plus(offset, DateTimeUnit.MONTH)
                MonthlyTotal(month = month, amount = byMonth[month.toString()] ?: 0L)
            }
        }
}
