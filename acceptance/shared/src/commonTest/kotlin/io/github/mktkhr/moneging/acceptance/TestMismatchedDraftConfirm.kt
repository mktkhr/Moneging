package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.DraftCorrection
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

private const val DELI_TOTAL = 980L
private const val DELI_BENTO = 680L
private const val DELI_TEA = 150L
private const val DELI_DIFFERENCE = 150L
private const val STORE_CONFIDENCE = 0.9
private const val DATE_CONFIDENCE = 0.9
private const val TOTAL_CONFIDENCE = 0.85
private const val BENTO_CONFIDENCE = 0.8
private const val TEA_CONFIDENCE = 0.9
private const val DIFFERENCE_NAME = "差額"
private const val DELI_STORE = "コーナーデリ"
private const val DELI_DATE = "2026-02-13"
private const val DELI_MONTH = "2026-02"

/**
 * AC-B-508 — A scan whose items do not add up keeps them, and is confirmed
 * only with the mismatch accepted.
 *
 * Given the fixture receipt `corner-deli.jpg`. When its scan succeeds, then
 * the draft reads store `コーナーデリ`, date 2026-02-13, total 980 and the
 * items 唐揚げ弁当 680 and 緑茶 150, both in 食費, with the fixture's
 * confidences (0.9, 0.9, 0.85; 0.8, 0.9) and no draft-level category. When it
 * is confirmed as it is, then the confirmation is refused as invalid and the
 * draft is unchanged. When it is confirmed with `acceptMismatch` true, then
 * one expense of 980 yen exists on 2026-02-13 with store `コーナーデリ`, linked
 * to the photo, split into 唐揚げ弁当 680, 緑茶 150 and `差額` 150, all in 食費,
 * with `needsReview` true, and the draft is gone: reading or confirming it
 * again finds nothing. Given a second draft of the same photo whose items are
 * all removed (`items` empty), when it is confirmed, then a second expense of
 * 980 yen exists in その他, with no line items, linked to the photo, with
 * `needsReview` false, and no draft waits.
 */
class TestMismatchedDraftConfirm {
    /** The draft keeps its items; confirming needs the mismatch accepted; the total alone is confirmed unsplit. */
    @Test
    fun mismatchedDraftIsConfirmedOnlyAccepted(): TestResult =
        runTest {
            val scope = scanningLedger().scope
            val food = scope.categoryIdNamed(name = "食費")
            val other = scope.categoryIdNamed(name = "その他")
            val photo = scope.addReceiptPhoto(name = CORNER_DELI)
            val draft = scope.draftOf(scope.scanUntilFinished(photo = photo).draftId)

            assertMismatchedDraftKept(draft = draft, food = food)
            assertConfirmRefusedUnchanged(scope = scope, draft = draft)
            val accepted = scope.confirmDraft(draftId = draft.id, acceptMismatch = true)
            assertAcceptedExpense(scope = scope, transaction = accepted, photoId = photo.id, food = food)
            assertDraftIsGone(scope = scope, draftId = draft.id)
            assertTotalAloneIsUnsplit(scope = scope, photo = photo, other = other)
        }
}

// The draft of corner-deli.jpg: the fixture's store, date, total, items and confidences, no draft-level category.
private fun assertMismatchedDraftKept(
    draft: Draft,
    food: Uuid,
) {
    assertEquals(expected = DELI_STORE, actual = draft.store.value, message = "店名が コーナーデリ でない")
    assertEquals(expected = STORE_CONFIDENCE, actual = draft.store.confidence, message = "店名の信頼度が 0.9 でない")
    assertEquals(expected = LocalDate.parse(DELI_DATE), actual = draft.date.value, message = "日付が 2026-02-13 でない")
    assertEquals(expected = DATE_CONFIDENCE, actual = draft.date.confidence, message = "日付の信頼度が 0.9 でない")
    assertEquals(expected = DELI_TOTAL, actual = draft.total.value, message = "合計が 980円 でない")
    assertEquals(expected = TOTAL_CONFIDENCE, actual = draft.total.confidence, message = "合計の信頼度が 0.85 でない")
    assertNull(actual = draft.categoryId, message = "下書きに全体の分類がある")
    assertEquals(
        expected =
            listOf(
                Triple("唐揚げ弁当", DELI_BENTO, food) to BENTO_CONFIDENCE,
                Triple("緑茶", DELI_TEA, food) to TEA_CONFIDENCE,
            ),
        actual = draft.items.map { item -> Triple(item.name, item.amount, item.categoryId) to item.confidence },
        message = "明細が 唐揚げ弁当 680円 食費 (0.8) と 緑茶 150円 食費 (0.9) でない（合わなくても残る）",
    )
}

// Confirmed as it is: refused as invalid, and the draft reads back as it was.
private suspend fun assertConfirmRefusedUnchanged(
    scope: LedgerScope,
    draft: Draft,
) {
    assertFailsWith<IllegalArgumentException>(message = "合わない下書きがそのまま確認できてしまう") {
        scope.confirmDraft(draftId = draft.id)
    }
    assertEquals(expected = draft, actual = scope.findDraft(id = draft.id), message = "断られた下書きが変わった")
    assertTrue(
        actual = scope.transactions(month = YearMonth.parse(DELI_MONTH)).isEmpty(),
        message = "断られたのに取引ができた",
    )
}

// The one expense: 980円 on 2026-02-13 at コーナーデリ, three items, linked to the photo, needs-review.
private suspend fun assertAcceptedExpense(
    scope: LedgerScope,
    transaction: Transaction,
    photoId: Uuid,
    food: Uuid,
) {
    val month = scope.transactions(month = YearMonth.parse(DELI_MONTH))
    assertEquals(expected = listOf(transaction.id), actual = month.map { it.id }, message = "2月の取引が 1 件でない")
    val read = assertNotNull(actual = scope.findTransaction(id = transaction.id), message = "確認した取引が読めない")
    assertEquals(expected = DELI_TOTAL, actual = read.amount, message = "取引が 980円 でない")
    assertEquals(expected = LocalDate.parse(DELI_DATE), actual = read.date, message = "取引の日付が 2026-02-13 でない")
    assertEquals(expected = DELI_STORE, actual = read.storeName, message = "取引の店名が コーナーデリ でない")
    assertEquals(expected = photoId, actual = read.photoId, message = "取引が写真に結び付いていない")
    assertEquals(
        expected =
            listOf(
                Triple("唐揚げ弁当", DELI_BENTO, food),
                Triple("緑茶", DELI_TEA, food),
                Triple(DIFFERENCE_NAME, DELI_DIFFERENCE, food),
            ),
        actual = read.items.map { item -> Triple(item.name, item.amount, item.categoryId) },
        message = "明細が 唐揚げ弁当 680円・緑茶 150円・差額 150円（すべて食費）でない",
    )
    assertTrue(actual = read.needsReview, message = "合わないまま記録したのに要確認の印がない")
}

// Confirmed, the draft is gone: it is not read, not confirmed again, and no draft waits.
private suspend fun assertDraftIsGone(
    scope: LedgerScope,
    draftId: Uuid,
) {
    assertNull(actual = scope.findDraft(id = draftId), message = "確認した下書きがまだ読める")
    assertFailsWith<IllegalArgumentException>(message = "確認した下書きをもう一度確認できてしまう") {
        scope.confirmDraft(draftId = draftId, acceptMismatch = true)
    }
    assertTrue(actual = scope.waitingDrafts().isEmpty(), message = "確認したのに確認待ちが残っている")
}

// A second draft of the photo with no items: one unsplit 980円 expense in その他, not marked, nothing waits.
private suspend fun assertTotalAloneIsUnsplit(
    scope: LedgerScope,
    photo: Photo,
    other: Uuid,
) {
    val second = scope.draftOf(scope.scanUntilFinished(photo = photo).draftId)
    scope.updateDraft(draftId = second.id, correction = DraftCorrection(items = emptyList()))
    val confirmed = scope.confirmDraft(draftId = second.id)
    val read = assertNotNull(actual = scope.findTransaction(id = confirmed.id), message = "合計だけの取引が読めない")
    assertEquals(expected = DELI_TOTAL, actual = read.amount, message = "合計だけの取引が 980円 でない")
    assertEquals(expected = other, actual = read.categoryId, message = "合計だけの取引が その他 でない")
    assertTrue(actual = read.items.isEmpty(), message = "合計だけの取引に明細がある")
    assertEquals(expected = photo.id, actual = read.photoId, message = "合計だけの取引が写真に結び付いていない")
    assertFalse(actual = read.needsReview, message = "合計だけの取引に要確認の印がある")
    assertEquals(
        expected = 2,
        actual = scope.transactions(month = YearMonth.parse(DELI_MONTH)).size,
        message = "2月の取引が 2 件でない",
    )
    assertTrue(actual = scope.waitingDrafts().isEmpty(), message = "確認したのに確認待ちが残っている")
}
