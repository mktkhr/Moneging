package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.domain.BusinessDayAdjustment
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

private const val LUNCH = 1_200L
private const val RENT = 80_000L
private const val TODAY = "2026-02-15"

/**
 * [LedgerEditor] writes what the forms hold into the ledger in view, and
 * [LedgerData] shows it: the month's transactions and totals, the
 * categories and the recurring rules, which are recorded once their date
 * has come (the test clock reads 2026-02-15).
 */
class LedgerEditorTest {
    private val device = TestDevice()
    private val opened = mutableListOf<LedgerData>()

    /** Stops the app states the test launched. */
    @AfterTest
    fun tearDown() {
        opened.forEach { it.close() }
        device.close()
    }

    /** A recorded expense is listed and totalled; a refused one is reported and writes nothing. */
    @Test
    fun recordsAndReportsRefusals(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val (data, editor) = open()
            val food =
                data.uiState
                    .first { it.categories.isNotEmpty() }
                    .categories
                    .first { it.name == "食費" }

            assertNull(editor.recordTransaction(draft(amount = "1200", categoryId = food.id.toString())))
            val shown = data.uiState.first { it.transactions.isNotEmpty() }
            assertEquals(expected = LUNCH, actual = shown.totals.expense)
            assertEquals(expected = LocalDate.parse(TODAY), actual = shown.transactions.single().date)

            assertNotNull(editor.recordTransaction(draft(amount = "1.5", categoryId = food.id.toString())))
            assertEquals(expected = 1, actual = data.uiState.value.transactions.size)
        }

    /** A rule saved on 2026-02-15 for the 10th records February's transaction at once. */
    @Test
    fun savedRuleRecordsItsDueMonth(): TestResult =
        runTest {
            device.store.createLedger("家計")
            val (data, editor) = open()
            val housing =
                data.uiState
                    .first { it.categories.isNotEmpty() }
                    .categories
                    .first { it.name == "住居" }

            val refusal = editor.recurringRules.createRecurringRule(rentDraft(categoryId = housing.id.toString()))

            assertNull(refusal)
            val shown = data.uiState.first { it.transactions.isNotEmpty() && it.recurringRules.isNotEmpty() }
            assertEquals(expected = RENT, actual = shown.transactions.single().amount)
            assertEquals(
                expected = shown.recurringRules.single().id,
                actual = shown.transactions.single().recurringRuleId,
            )
        }

    /** An ended rule is listed until its last recorded month; a deleted one is gone and its record stays. */
    @Test
    fun endsAndDeletesRule(): TestResult =
        runTest {
            val ledger = device.store.createLedger("家計")
            val (data, editor) = open()
            val loaded = data.uiState.first { it.categories.isNotEmpty() }
            val housing = loaded.categories.first { it.name == "住居" }
            assertNull(editor.recurringRules.createRecurringRule(rentDraft(categoryId = housing.id.toString())))
            // Read back from the store: what the screens show is covered above.
            val scope = device.store.ledger(ledger.id)
            val ruleId =
                scope
                    .recurringRules()
                    .single()
                    .id
                    .toString()

            assertNull(editor.recurringRules.endRecurringRule(ruleId))
            val ended = loaded.copy(recurringRules = scope.recurringRules())
            val row = ended.recurringRuleRows(todayIso = TODAY).single()
            assertEquals(expected = "2026年2月まで", actual = row.endedText)
            assertEquals(expected = "毎月10日 80,000円 住居、2026年2月まで", actual = row.accessibilityLabel)
            assertEquals(
                expected = true,
                actual = ended.recurringRuleEditing(id = ruleId, todayIso = TODAY)?.isEnded,
            )

            assertNull(editor.recurringRules.deleteRecurringRule(ruleId))
            assertEquals(expected = emptyList(), actual = scope.recurringRules())
            val recorded = scope.transactions(YearMonth.parse("2026-02")).single()
            assertEquals(expected = true, actual = ended.transactionRow(recorded).isRecurring)
        }

    private suspend fun open(): Pair<LedgerData, LedgerEditor> {
        val appState = device.launch()
        val data = LedgerData(store = device.store, appState = appState)
        opened += data
        return data to LedgerEditor(store = device.store, appState = appState, ledgerData = data)
    }

    // 80,000 yen on the 10th from 2026-02.
    private fun rentDraft(categoryId: String): RecurringRuleDraft =
        RecurringRuleDraft(
            isIncome = false,
            amountText = "80000",
            categoryId = categoryId,
            dayText = "10",
            adjustment = BusinessDayAdjustment.KEEP,
            startMonth = "2026-02",
            endMonth = null,
            memo = "",
        )

    private fun draft(
        amount: String,
        categoryId: String,
    ): TransactionDraft =
        TransactionDraft(
            date = TODAY,
            isIncome = false,
            amountText = amount,
            categoryId = categoryId,
            storeName = "",
            memo = "ランチ",
            items = emptyList(),
        )
}
