package io.github.mktkhr.moneging.state

import io.github.mktkhr.moneging.data.markReviewNeeded
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

private const val DELI_ITEM = 830L
private const val DIFFERENCE = 150L
private const val DRUG_ITEM = 2_000L
private const val DRUG_DIFFERENCE = 640L
private const val DELI_DATE = "2026-02-13"

/**
 * The needs-review records as the screens show them (PRODUCT.md §5,
 * Needs-review): the count, the list across months, the explanation, and
 * what the edit sheet's writes do to the mark.
 */
class ReviewPresentationTest {
    private val device = TestDevice()
    private val opened = mutableListOf<LedgerData>()

    /** Stops the app states the test launched. */
    @AfterTest
    fun tearDown() {
        opened.forEach { it.close() }
        device.close()
    }

    /** The count, the list newest first across months and the explanation naming the 差額. */
    @Test
    fun countsListsAndExplains(): TestResult =
        runTest {
            val world = seeded()
            val shown = world.data.uiState.first { it.reviewNeeded.size == 2 }

            assertEquals(
                expected = ReviewStatus(title = "要確認 2件", detail = "明細が合計と合わないまま記録したもの"),
                actual = shown.reviewStatus(),
            )
            assertEquals(
                expected = listOf("2026年2月13日（金）", "2026年1月20日（火）"),
                actual = shown.reviewSections().map { it.title },
            )
            assertTrue(shown.reviewSections().all { section -> section.rows.all { it.isMarkedForReview } })
            assertEquals(
                expected = "要確認：読み取った明細が合計と合わなかったため「差額 150円」を足してあります。写真を見て直してください。",
                actual = shown.reviewExplanation(world.deli.toString())?.text,
            )
        }

    /** Saving the edit sheet keeps the mark while 差額 stays; marking it reviewed clears it and the count. */
    @Test
    fun editKeepsMarkAndReviewClearsIt(): TestResult =
        runTest {
            val world = seeded()
            world.data.uiState.first { it.reviewNeeded.size == 2 }

            assertNull(world.editor.updateTransaction(world.deli.toString(), deliDraft(memo = "昼")))
            assertTrue(world.scope().findTransaction(world.deli)?.isReviewNeeded == true)

            assertNull(world.editor.markReviewed(world.deli.toString()))
            val shown = world.data.uiState.first { it.reviewNeeded.size == 1 }
            assertFalse(world.scope().findTransaction(world.deli)?.isReviewNeeded == true)
            assertEquals(expected = "要確認 1件", actual = shown.reviewStatus()?.title)
            assertNull(shown.reviewExplanation(world.deli.toString()))

            assertNull(world.editor.markReviewed(world.drugstore.toString()))
            assertNull(
                world.data.uiState
                    .first { it.reviewNeeded.isEmpty() }
                    .reviewStatus(),
            )
        }

    /** Removing 差額 clears the mark; a marked record without 差額 is explained without one. */
    @Test
    fun clearsWithoutDifference(): TestResult =
        runTest {
            val world = seeded()
            val scope = world.scope()
            val current = assertNotNull(scope.findTransaction(world.deli))
            scope.updateTransaction(
                transactionId = world.deli,
                transaction =
                    NewTransaction(
                        date = current.date,
                        direction = Direction.EXPENSE,
                        amount = DELI_ITEM,
                        categoryId = null,
                        items = listOf(NewLineItem(amount = DELI_ITEM, categoryId = current.items.first().categoryId)),
                        isReviewNeeded = true,
                    ),
            )
            assertFalse(scope.findTransaction(world.deli)?.isReviewNeeded == true)

            val food = current.items.first().categoryId
            val whole = scope.recordTransaction(split("2026-02-14", listOf(NewLineItem(DELI_ITEM, food, "弁当"))))
            device.store.markReviewNeeded(ledgerId = world.ledgerId, transactionId = whole.id)
            val shown = world.data.uiState.first { state -> state.reviewNeeded.any { it.id == whole.id } }
            assertEquals(
                expected = "要確認：読み取った明細が合計と合わなかったため写真を見て直してください。",
                actual = shown.reviewExplanation(whole.id.toString())?.text,
            )
        }

    private class World(
        val data: LedgerData,
        val editor: LedgerEditor,
        val ledgerId: Uuid,
        val deli: Uuid,
        val drugstore: Uuid,
        val device: TestDevice,
    ) {
        fun scope() = device.store.ledger(ledgerId)
    }

    private suspend fun seeded(): World {
        val ledger = device.store.createLedger("家計")
        val appState = device.launch()
        val data = LedgerData(store = device.store, appState = appState)
        opened += data
        val editor = LedgerEditor(store = device.store, appState = appState, ledgerData = data)
        val scope = device.store.ledger(ledger.id)
        val categories = scope.categories()
        val food = categories.first { it.name == "食費" }.id
        val daily = categories.first { it.name == "日用品" }.id
        val deli =
            scope.recordTransaction(
                split(DELI_DATE, listOf(NewLineItem(DELI_ITEM, food, "弁当"), NewLineItem(DIFFERENCE, food, "差額"))),
            )
        val drugstore =
            scope.recordTransaction(
                split(
                    "2026-01-20",
                    listOf(NewLineItem(DRUG_ITEM, daily, "洗剤"), NewLineItem(DRUG_DIFFERENCE, daily, "差額")),
                ),
            )
        listOf(deli, drugstore).forEach { device.store.markReviewNeeded(ledgerId = ledger.id, transactionId = it.id) }
        return World(
            data = data,
            editor = editor,
            ledgerId = ledger.id,
            deli = deli.id,
            drugstore = drugstore.id,
            device = device,
        )
    }

    private fun split(
        date: String,
        items: List<NewLineItem>,
    ): NewTransaction =
        NewTransaction(
            date = LocalDate.parse(date),
            direction = Direction.EXPENSE,
            amount = items.sumOf { it.amount },
            categoryId = null,
            storeName = "コーナーデリ",
            items = items,
        )

    private fun deliDraft(memo: String): TransactionDraft {
        val shown = opened.first().uiState.value
        val deli = shown.reviewNeeded.first { it.date == LocalDate.parse(DELI_DATE) }
        return TransactionDraft(
            date = DELI_DATE,
            isIncome = false,
            amountText = "",
            categoryId = null,
            storeName = "コーナーデリ",
            memo = memo,
            items =
                deli.items.map { item ->
                    LineItemDraft(
                        name = item.name.orEmpty(),
                        categoryId = item.categoryId.toString(),
                        amountText = item.amount.toString(),
                    )
                },
            photoId = null,
        )
    }
}
