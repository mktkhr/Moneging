package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.CarryOverPolicy
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.uuid.Uuid

private const val TODAY = "2026-02-15"
private const val WHOLE_BUDGET = 50_000L
private const val FOOD_BUDGET = 30_000L
private const val FUN_BUDGET = 5_000L
private const val FOOD_SPENT = 18_500L
private const val FUN_SPENT = 6_500L
private const val TRANSPORT_SPENT = 3_000L
private const val WHOLE_CARRIED = 22_000L

private val JANUARY: YearMonth = YearMonth.parse("2026-01")
private val FEBRUARY: YearMonth = YearMonth.parse("2026-02")

/** How the budget view and its sheets show the budgets, and the rules they rest on. */
class BudgetPresentationTest {
    /** The whole month, each category's remaining or overspending, one without a budget, and savings. */
    @Test
    fun budgetViewReadsEachBudget(): TestResult =
        runTest {
            val scope = januaryScope()

            val view = assertNotNull(scope.stateOf(JANUARY).budgetView(todayIso = TODAY))

            assertEquals(
                expected = "1月の予算 残り 22,000円 予算 50,000円 使った 28,000円",
                actual = view.whole.accessibilityLabel,
            )
            assertEquals(
                expected =
                    listOf(
                        "食費 残り 11,500円 予算 30,000円 使った 18,500円",
                        "交通費 使った 3,000円",
                        "娯楽 1,500円オーバー 予算 5,000円 使った 6,500円",
                    ),
                actual = view.rows.map { it.accessibilityLabel },
            )
            assertEquals(
                expected = listOf("残り 11,500円", "3,000円", "1,500円オーバー"),
                actual = view.rows.map { it.headline },
            )
            assertEquals(expected = "予算なし", actual = view.rows[1].detail)
            assertEquals(expected = "貯金 0円", actual = view.savingsText)
            assertEquals(expected = "1月を締めましょう", actual = view.closeOffer?.title)
            assertEquals(expected = "残りは各予算に繰り越します", actual = view.closeOffer?.note)
        }

    /** The sheet that closes a month lists each leftover and says what each policy does. */
    @Test
    fun closeSheetListsLeftovers(): TestResult =
        runTest {
            val scope = januaryScope()

            val sheet = assertNotNull(scope.stateOf(FEBRUARY).closeSheet(todayIso = TODAY))

            assertEquals(expected = "1月を締める", actual = sheet.title)
            assertEquals(
                expected = listOf("22,000円", "11,500円", "−1,500円（動かしません）"),
                actual = sheet.lines.map { it.amountText },
            )
            assertEquals(expected = listOf("月全体 の残り", "食費 の残り", "娯楽 の残り"), actual = sheet.lines.map { it.title })
            assertEquals(
                expected = "繰り越す: 2月の予算に、それぞれの残りを足します（月全体 50,000円 → 72,000円）。",
                actual = sheet.carryNote,
            )
            assertEquals(expected = "貯金にする: 月全体の残り 22,000円 を貯金に入れます。", actual = sheet.saveNote)
        }

    /** Closing under `carry` carries the whole month's and each category's leftover; nothing negative moves. */
    @Test
    fun carryMovesPositiveLeftovers(): TestResult =
        runTest {
            val scope = januaryScope()

            val close = scope.closeMonth(JANUARY)

            assertEquals(expected = WHOLE_CARRIED, actual = close.carriedWhole)
            assertEquals(expected = listOf(FOOD_BUDGET - FOOD_SPENT), actual = close.carried.values.toList())
            val february = scope.budgetRemaining(FEBRUARY)
            assertEquals(expected = WHOLE_BUDGET + WHOLE_CARRIED, actual = february.whole.budget)
            assertEquals(expected = FUN_BUDGET, actual = february.categories.last().budget)
            assertNull(scope.monthToClose())
        }

    /** A budget removed from a month on is gone from then; one set in a closed month is refused. */
    @Test
    fun closedMonthsAreFinal(): TestResult =
        runTest {
            val scope = januaryScope()
            val leisure = scope.categories().first { it.name == "娯楽" }.id
            scope.removeBudget(categoryId = leisure, from = FEBRUARY)
            assertEquals(
                expected = listOf(null),
                actual =
                    scope
                        .budgetRemaining(FEBRUARY)
                        .categories
                        .drop(1)
                        .map { it.budget },
            )

            scope.setCarryOverPolicy(CarryOverPolicy.SAVE)
            scope.closeMonth(JANUARY)

            assertEquals(expected = WHOLE_CARRIED, actual = scope.savings().balance)
            assertFailsWith<IllegalStateException> { scope.setBudget(categoryId = null, amount = 1L, from = JANUARY) }
            assertEquals(
                expected = "",
                actual = scope.stateOf(FEBRUARY).budgetSheet(categoryId = leisure.toString()).amountText,
            )
        }

    /** A budget of 0 is a budget: its sheet shows 0 and offers removing it, unlike a category without one. */
    @Test
    fun zeroBudgetIsSet(): TestResult =
        runTest {
            val scope = januaryScope()
            val daily =
                scope
                    .categories()
                    .first { it.name == "日用品" }
                    .id
                    .toString()
            assertEquals(expected = false, actual = scope.stateOf(FEBRUARY).budgetSheet(categoryId = daily).hasBudget)

            scope.setBudget(categoryId = Uuid.parse(daily), amount = 0L, from = FEBRUARY)

            val sheet = scope.stateOf(FEBRUARY).budgetSheet(categoryId = daily)
            assertEquals(expected = "0", actual = sheet.amountText)
            assertEquals(expected = true, actual = sheet.hasBudget)
        }

    // A ledger (today 2026-02-15) with budgets from January: the whole month 50,000, 食費 30,000 and 娯楽 5,000;
    // January spent 18,500 食費, 6,500 娯楽 and 3,000 交通費, and February 1 娯楽 (so it is listed).
    private suspend fun januaryScope(): LedgerScope {
        val device = TestDevice()
        val ledger = device.store.createLedger("家計")
        val scope = device.store.ledger(ledger.id)
        val categories = scope.categories().associate { it.name to it.id }
        scope.setBudget(categoryId = null, amount = WHOLE_BUDGET, from = JANUARY)
        scope.setBudget(categoryId = categories.getValue("食費"), amount = FOOD_BUDGET, from = JANUARY)
        scope.setBudget(categoryId = categories.getValue("娯楽"), amount = FUN_BUDGET, from = JANUARY)
        listOf("食費" to FOOD_SPENT, "娯楽" to FUN_SPENT, "交通費" to TRANSPORT_SPENT).forEach { (name, amount) ->
            scope.recordExpense(date = "2026-01-10", amount = amount, categoryId = categories.getValue(name))
        }
        scope.recordExpense(date = "2026-02-01", amount = 1L, categoryId = categories.getValue("娯楽"))
        return scope
    }

    private suspend fun LedgerScope.recordExpense(
        date: String,
        amount: Long,
        categoryId: Uuid,
    ) {
        recordTransaction(
            NewTransaction(
                date = LocalDate.parse(date),
                direction = Direction.EXPENSE,
                amount = amount,
                categoryId = categoryId,
            ),
        )
    }

    // The ledger as its screens read it with [month] in view.
    private suspend fun LedgerScope.stateOf(month: YearMonth): LedgerUiState {
        val closing = monthToClose()
        return LedgerUiState.EMPTY.copy(
            ledgerId = ledgerId.toString(),
            month = month,
            isLoaded = true,
            categories = categories(),
            budgets = budgetRemaining(month),
            closing = closing?.let { budgetRemaining(it) },
            closingNext = closing?.let { budgetRemaining(FEBRUARY) },
            savings = savings(),
            carryOverPolicy = carryOverPolicy(),
        )
    }
}
