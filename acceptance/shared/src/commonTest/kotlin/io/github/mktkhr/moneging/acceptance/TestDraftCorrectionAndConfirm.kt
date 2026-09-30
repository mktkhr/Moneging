package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.domain.Direction
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
import kotlin.test.assertFails
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

private const val CORRECTED_STORE = "セブンイレブン 新宿店"
private const val CORRECTED_BENTO = 820L
private const val CORRECTED_TOTAL = 1_200L
private const val RICE_BALL = 380L

/**
 * AC-B-505 — A draft is corrected field by field and confirmed into a
 * transaction.
 *
 * Given the draft of AC-B-504. When its store alone is corrected to
 * `セブンイレブン 新宿店`, then everything else reads back unchanged. When the
 * second item's amount is corrected to 820 with the total 1,200
 * (380 + 820 = 1,200), then the draft reads back with those values. When it is
 * confirmed, then a transaction of 1,200 yen exists on 2026-02-14 with store
 * `セブンイレブン 新宿店` and two line items — おにぎり 380 in 食費 and 弁当 820 in
 * その他 — linked to the photo, and the draft is gone: reading or confirming it
 * again finds nothing. Given another draft of the same photo, when it is
 * discarded, then it is gone, no draft waits, and 2026-02 still holds only the
 * one transaction.
 */
class TestDraftCorrectionAndConfirm {
    /** Corrections change only the field named; confirming records the corrected draft and removes it. */
    @Test
    fun draftIsCorrectedAndConfirmed(): TestResult =
        runTest {
            val scope = scanningLedger().scope
            val food = scope.categoryIdNamed(name = "食費")
            val other = scope.categoryIdNamed(name = "その他")
            val photo = scope.addReceiptPhoto(name = SEVEN_ELEVEN)
            val original = scope.draftOf(scope.scanUntilFinished(photo = photo).draftId)

            val storeCorrected = scope.correctStoreAlone(original = original)
            scope.correctBentoAndTotal(storeCorrected = storeCorrected)

            val transaction = scope.confirmDraft(draftId = original.id)

            assertConfirmed(scope = scope, transaction = transaction, photoId = photo.id, food = food, other = other)
            assertNull(actual = scope.findDraft(id = original.id), message = "確認した下書きがまだ読める")
            assertFails(message = "確認した下書きをもう一度確認できてしまう") { scope.confirmDraft(draftId = original.id) }
            assertDiscardedDraftIsGone(scope = scope, photo = photo)
        }
}

internal suspend fun LedgerScope.draftOf(id: Uuid?): Draft {
    val draftId = assertNotNull(actual = id, message = "下書きの id がない")
    return assertNotNull(actual = findDraft(id = draftId), message = "下書きが読めない")
}

// The confirmed transaction: 1,200円 on 2026-02-14 at the corrected store, two items, linked to the photo.
internal suspend fun assertConfirmed(
    scope: LedgerScope,
    transaction: Transaction,
    photoId: Uuid,
    food: Uuid,
    other: Uuid,
) {
    val read = assertNotNull(actual = scope.findTransaction(id = transaction.id), message = "確認した取引が読めない")
    assertEquals(expected = CORRECTED_TOTAL, actual = read.amount, message = "取引が 1,200円 でない")
    assertEquals(expected = Direction.EXPENSE, actual = read.direction, message = "取引が支出でない")
    assertEquals(expected = LocalDate.parse("2026-02-14"), actual = read.date, message = "取引の日付が 2026-02-14 でない")
    assertEquals(expected = CORRECTED_STORE, actual = read.storeName, message = "取引の店名が セブンイレブン 新宿店 でない")
    assertEquals(expected = photoId, actual = read.photoId, message = "取引が写真に結び付いていない")
    assertEquals(
        expected = listOf(Triple("おにぎり", RICE_BALL, food), Triple("弁当", CORRECTED_BENTO, other)),
        actual = read.items.map { item -> Triple(item.name, item.amount, item.categoryId) },
        message = "明細が おにぎり 380円 食費 と 弁当 820円 その他 でない",
    )
}

// A second draft of the same photo, discarded: gone, nothing waits, February holds the one transaction.
internal suspend fun assertDiscardedDraftIsGone(
    scope: LedgerScope,
    photo: Photo,
) {
    val another = scope.draftOf(scope.scanUntilFinished(photo = photo).draftId)
    scope.discardDraft(draftId = another.id)
    assertNull(actual = scope.findDraft(id = another.id), message = "捨てた下書きがまだ読める")
    assertTrue(actual = scope.waitingDrafts().isEmpty(), message = "捨てても確認待ちが残っている")
    assertEquals(
        expected = 1,
        actual = scope.transactions(month = YearMonth.parse("2026-02")).size,
        message = "下書きを捨てたら 2月 の取引が 1 件でなくなった",
    )
}

// Correcting the store alone: it changes, and the date, total and items read back as they were.
internal suspend fun LedgerScope.correctStoreAlone(original: Draft): Draft {
    updateDraft(draftId = original.id, correction = DraftCorrection(store = CORRECTED_STORE))
    val storeCorrected = draftOf(original.id)
    assertEquals(expected = CORRECTED_STORE, actual = storeCorrected.store.value, message = "店名だけを直しても店名が変わらない")
    assertEquals(expected = original.date, actual = storeCorrected.date, message = "店名だけを直して日付が変わった")
    assertEquals(expected = original.total, actual = storeCorrected.total, message = "店名だけを直して合計が変わった")
    assertEquals(expected = original.items, actual = storeCorrected.items, message = "店名だけを直して明細が変わった")
    return storeCorrected
}

// Correcting the second item to 820 with the total 1,200: the draft reads back with them.
internal suspend fun LedgerScope.correctBentoAndTotal(storeCorrected: Draft) {
    val bento = storeCorrected.items[1].copy(amount = CORRECTED_BENTO)
    updateDraft(
        draftId = storeCorrected.id,
        correction = DraftCorrection(total = CORRECTED_TOTAL, items = listOf(storeCorrected.items[0], bento)),
    )
    val corrected = draftOf(storeCorrected.id)
    assertEquals(expected = CORRECTED_TOTAL, actual = corrected.total.value, message = "合計が 1,200円 に直らない")
    assertEquals(
        expected = listOf(RICE_BALL, CORRECTED_BENTO),
        actual = corrected.items.map { item -> item.amount },
        message = "明細の金額が 380円 と 820円 でない",
    )
    assertEquals(expected = CORRECTED_STORE, actual = corrected.store.value, message = "金額を直して店名が戻った")
}
