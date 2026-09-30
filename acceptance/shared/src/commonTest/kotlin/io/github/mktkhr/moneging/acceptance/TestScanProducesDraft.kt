package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.ScanState
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

private const val STORE_CONFIDENCE = 0.95
private const val DATE_CONFIDENCE = 0.9
private const val TOTAL_CONFIDENCE = 0.4
private const val RICE_BALL_CONFIDENCE = 0.9
private const val BENTO_CONFIDENCE = 0.5
private const val RICE_BALL_AMOUNT = 380L
private const val BENTO_AMOUNT = 800L
private const val RECEIPT_TOTAL = 1_180L

/**
 * AC-B-504 — A succeeded scan yields a draft with store, date, total and
 * items.
 *
 * Given the fixture receipt `seven-eleven.jpg`. When its scan succeeds, then
 * the draft reads store `セブン-イレブン`, date 2026-02-14, total 1,180, and two
 * items — おにぎり 380 in 食費 and 弁当 800 without a category — each field and
 * item with the fixture's confidence (0.95, 0.9, 0.4; 0.9, 0.5), and the
 * ledger's waiting drafts list it with that store, date and total.
 */
class TestScanProducesDraft {
    /** The scan of the fixture receipt succeeds into a draft with the fixture's values and confidences. */
    @Test
    fun succeededScanYieldsDraft(): TestResult =
        runTest {
            val scope = scanningLedger().scope
            val food = scope.categoryIdNamed(name = "食費")
            val photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN)

            val job = scope.scanUntilFinished(photo = photo)

            assertEquals(
                expected = ScanState.SUCCEEDED,
                actual = job.state,
                message = "スキャンが succeeded にならない: ${job.failureReason}",
            )
            val draft = assertNotNull(actual = scope.findDraft(id = assertNotNull(job.draftId)), message = "下書きが読めない")
            assertEquals(expected = photo.id, actual = draft.photoId, message = "下書きが送った写真のものでない")
            assertEquals(expected = "セブン-イレブン", actual = draft.store.value, message = "店名が セブン-イレブン でない")
            assertEquals(expected = STORE_CONFIDENCE, actual = draft.store.confidence, message = "店名の信頼度が 0.95 でない")
            assertEquals(
                expected = LocalDate.parse("2026-02-14"),
                actual = draft.date.value,
                message = "日付が 2026-02-14 でない",
            )
            assertEquals(expected = DATE_CONFIDENCE, actual = draft.date.confidence, message = "日付の信頼度が 0.9 でない")
            assertEquals(expected = RECEIPT_TOTAL, actual = draft.total.value, message = "合計が 1,180円 でない")
            assertEquals(expected = TOTAL_CONFIDENCE, actual = draft.total.confidence, message = "合計の信頼度が 0.4 でない")
            assertNull(actual = draft.categoryId, message = "下書きに全体の分類がある")
            assertEquals(
                expected =
                    listOf(
                        Triple("おにぎり", RICE_BALL_AMOUNT, food) to RICE_BALL_CONFIDENCE,
                        Triple("弁当", BENTO_AMOUNT, null) to BENTO_CONFIDENCE,
                    ),
                actual = draft.items.map { item -> Triple(item.name, item.amount, item.categoryId) to item.confidence },
                message = "明細が おにぎり 380円 食費 (0.9) と 弁当 800円 分類なし (0.5) でない",
            )
            assertWaiting(scope = scope, draft = draft)
        }
}

// The ledger's waiting drafts are this one alone, with its store, date and total.
private suspend fun assertWaiting(
    scope: LedgerScope,
    draft: Draft,
) {
    val waiting = scope.waitingDrafts()
    assertEquals(expected = listOf(draft.id), actual = waiting.map { it.id }, message = "確認待ちの下書きが 1 件でない")
    val listed = waiting.single()
    assertEquals(expected = "セブン-イレブン", actual = listed.store.value, message = "確認待ちの店名が セブン-イレブン でない")
    assertEquals(
        expected = LocalDate.parse("2026-02-14"),
        actual = listed.date.value,
        message = "確認待ちの日付が 2026-02-14 でない",
    )
    assertEquals(expected = RECEIPT_TOTAL, actual = listed.total.value, message = "確認待ちの合計が 1,180円 でない")
}
