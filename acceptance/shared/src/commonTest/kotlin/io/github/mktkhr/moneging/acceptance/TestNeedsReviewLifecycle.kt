package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewLineItem
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Transaction
import io.github.mktkhr.moneging.scan.DraftCorrection
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.uuid.Uuid

private const val DELI_TOTAL = 980L
private const val ABOVE_TOTAL_SUM = 830L
private const val CORRECTED_TOTAL = 800L
private const val BENTO_AMOUNT = 680L
private const val TEA_AMOUNT = 150L
private const val DIFFERENCE_AMOUNT = 150L
private const val HAND_AMOUNT = 800L
private const val DIFFERENCE_NAME = "差額"
private const val FAMILY_LEDGER_NAME = "実家"
private const val JANUARY_DATE = "2026-01-20"
private const val FEBRUARY_TENTH = "2026-02-10"
private const val FEBRUARY_THIRTEENTH = "2026-02-13"
private const val FEBRUARY_FOURTEENTH = "2026-02-14"

private val THREE_ITEMS: List<Pair<String?, Long>> =
    listOf("唐揚げ弁当" to BENTO_AMOUNT, "緑茶" to TEA_AMOUNT, DIFFERENCE_NAME to DIFFERENCE_AMOUNT)

private data class ReviewWorld(
    val home: LedgerScope,
    val family: LedgerScope,
    val january: Transaction,
    val february: Transaction,
    val aboveTotal: Transaction,
    val byHand: Transaction,
    val familyRecord: Transaction,
)

/**
 * AC-B-509 — Needs-review records are listed across months, cleared by review
 * or by removing 差額, never marked by hand.
 *
 * Given ledgers `家計` and `実家`. In `家計`, three drafts of `corner-deli.jpg`
 * are confirmed with `acceptMismatch`: one dated 2026-01-20, one dated
 * 2026-02-10, and one whose total is corrected to 800, which records 830
 * (680 + 150, above the total) with the two items and no `差額`; and an
 * expense of 800 is recorded by hand on 2026-02-14. In `実家`, one draft of it
 * is confirmed with `acceptMismatch`. When `家計`'s needs-review transactions
 * are listed, then they are the 830 of 2026-02-13, the 980 of 2026-02-10 and
 * the 980 of 2026-01-20, in that order, each with `isReviewNeeded` true;
 * `実家`'s list holds only its own record. When the hand-recorded expense is
 * updated with `isReviewNeeded` true, then the update is refused as invalid
 * and it stays unmarked. When the 2026-02-10 record's memo alone is changed,
 * then it stays marked, since its `差額` remains. When the 2026-01-20 record is
 * updated with `isReviewNeeded` false, then it is unmarked and still 980 with
 * its three items. When the 2026-02-10 record's `差額` item is deleted with the
 * transaction's new amount 830, then it reads 830 with the two items,
 * unmarked. Afterwards `家計`'s list holds only the 830 of 2026-02-13, and
 * `実家`'s still its own record.
 *
 * Contract assumed (not yet in the product): `LedgerScope.reviewNeededTransactions()`
 * lists the ledger's marked transactions of every month, newest first, and
 * `NewTransaction` gains `isReviewNeeded: Boolean = false`.
 */
class TestNeedsReviewLifecycle {
    /** Listed across months newest first, per ledger; never marked by hand; cleared by review or by removing 差額. */
    @Test
    fun listedClearedAndNeverMarkedByHand(): TestResult =
        runTest {
            val world = reviewWorld()
            assertListedNewestFirst(world = world)
            assertHandMarkRefused(world = world)
            assertMemoKeepsMark(world = world)
            assertReviewedAsItIs(world = world)
            assertRemovingDifferenceUnmarks(world = world)
            assertOnlyAboveTotalLeft(world = world)
        }
}

private suspend fun reviewWorld(): ReviewWorld {
    val store =
        LocalStore.inMemory(
            clock = ManualClock(current = FIXTURE_NOON),
            deviceId = FIXTURE_DEVICE_ID,
            scanner = fixtureScanner(),
        )
    val home = store.ledger(id = store.createLedger(name = FIXTURE_LEDGER_NAME).id)
    val family = store.ledger(id = store.createLedger(name = FAMILY_LEDGER_NAME).id)
    val january = home.confirmMismatched(date = LocalDate.parse(JANUARY_DATE), total = null)
    val february = home.confirmMismatched(date = LocalDate.parse(FEBRUARY_TENTH), total = null)
    val aboveTotal = home.confirmMismatched(date = null, total = CORRECTED_TOTAL)
    val byHand =
        home.recordTransaction(
            transaction =
                NewTransaction(
                    date = LocalDate.parse(FEBRUARY_FOURTEENTH),
                    direction = Direction.EXPENSE,
                    amount = HAND_AMOUNT,
                    categoryId = home.categoryIdNamed(name = "食費"),
                ),
        )
    val familyRecord = family.confirmMismatched(date = null, total = null)
    return ReviewWorld(home, family, january, february, aboveTotal, byHand, familyRecord)
}

// Scans corner-deli.jpg, corrects the draft's [date] and [total] when given, and confirms it accepting the mismatch.
private suspend fun LedgerScope.confirmMismatched(
    date: LocalDate?,
    total: Long?,
): Transaction {
    val photo = addReceiptPhoto(name = CORNER_DELI)
    val draft = draftOf(scanUntilFinished(photo = photo).draftId)
    updateDraft(draftId = draft.id, correction = DraftCorrection(date = date, total = total))
    return confirmDraft(draftId = draft.id, acceptMismatch = true)
}

private fun Transaction.itemsRead(): List<Pair<String?, Long>> = items.map { item -> item.name to item.amount }

private fun Transaction.toNew(
    items: List<NewLineItem>,
    amount: Long,
    isReviewNeeded: Boolean,
): NewTransaction =
    NewTransaction(
        date = date,
        direction = direction,
        amount = amount,
        categoryId = null,
        memo = memo,
        storeName = storeName,
        photoId = photoId,
        items = items,
        isReviewNeeded = isReviewNeeded,
    )

private fun Transaction.newItems(): List<NewLineItem> =
    items.map { item -> NewLineItem(amount = item.amount, categoryId = item.categoryId, name = item.name) }

private suspend fun assertListedNewestFirst(world: ReviewWorld) {
    val listed = world.home.reviewNeededTransactions()
    assertEquals(
        expected = listOf(world.aboveTotal.id, world.february.id, world.january.id),
        actual = listed.map { it.id },
        message = "家計の要確認が 2026-02-13 の 830円、2026-02-10 の 980円、2026-01-20 の 980円 の順でない",
    )
    assertEquals(
        expected = listOf(ABOVE_TOTAL_SUM, DELI_TOTAL, DELI_TOTAL),
        actual = listed.map { it.amount },
        message = "要確認の金額が 830円・980円・980円 でない",
    )
    assertEquals(
        expected =
            listOf(
                LocalDate.parse(FEBRUARY_THIRTEENTH),
                LocalDate.parse(FEBRUARY_TENTH),
                LocalDate.parse(JANUARY_DATE),
            ),
        actual = listed.map { it.date },
        message = "要確認の日付が 2026-02-13・2026-02-10・2026-01-20 でない",
    )
    assertTrue(actual = listed.all { it.isReviewNeeded }, message = "一覧に印のない記録がある")
    assertEquals(
        expected = listOf(world.familyRecord.id),
        actual = world.family.reviewNeededTransactions().map { it.id },
        message = "実家の要確認が実家自身の記録だけでない",
    )
    assertEquals(
        expected = listOf("唐揚げ弁当" to BENTO_AMOUNT, "緑茶" to TEA_AMOUNT),
        actual = world.aboveTotal.itemsRead(),
        message = "合計を 800円 にした記録が 830円 の 2 つの明細（差額なし）でない",
    )
}

private suspend fun assertHandMarkRefused(world: ReviewWorld) {
    assertFailsWith<IllegalArgumentException>(message = "手で要確認の印を付けられてしまう") {
        world.home.updateTransaction(
            transactionId = world.byHand.id,
            transaction =
                NewTransaction(
                    date = world.byHand.date,
                    direction = Direction.EXPENSE,
                    amount = HAND_AMOUNT,
                    categoryId = world.byHand.categoryId,
                    isReviewNeeded = true,
                ),
        )
    }
    val read = assertNotNull(actual = world.home.findTransaction(id = world.byHand.id), message = "手で記録した取引が読めない")
    assertFalse(actual = read.isReviewNeeded, message = "手で印が付いた")
    assertEquals(expected = HAND_AMOUNT, actual = read.amount, message = "断られた変更で金額が変わった")
}

private suspend fun assertMemoKeepsMark(world: ReviewWorld) {
    world.home.updateMemo(transactionId = world.february.id, memo = "メモだけ変える")
    val read = assertNotNull(actual = world.home.findTransaction(id = world.february.id), message = "取引が読めない")
    assertEquals(expected = "メモだけ変える", actual = read.memo, message = "メモが変わらない")
    assertTrue(actual = read.isReviewNeeded, message = "差額が残るのにメモの変更で印が外れた")
    assertEquals(
        expected = THREE_ITEMS,
        actual = read.itemsRead(),
        message = "メモの変更で明細が変わった",
    )
}

private suspend fun assertReviewedAsItIs(world: ReviewWorld) {
    val january = world.january
    world.home.updateTransaction(
        transactionId = january.id,
        transaction = january.toNew(items = january.newItems(), amount = january.amount, isReviewNeeded = false),
    )
    val read = assertNotNull(actual = world.home.findTransaction(id = january.id), message = "取引が読めない")
    assertFalse(actual = read.isReviewNeeded, message = "isReviewNeeded false の変更で印が外れない")
    assertEquals(expected = DELI_TOTAL, actual = read.amount, message = "確認済みにして金額が 980円 でなくなった")
    assertEquals(
        expected = THREE_ITEMS,
        actual = read.itemsRead(),
        message = "確認済みにして明細が 3 つのままでない",
    )
}

private suspend fun assertRemovingDifferenceUnmarks(world: ReviewWorld) {
    val february = world.february
    val kept = february.newItems().filterNot { item -> item.name == DIFFERENCE_NAME }
    world.home.updateTransaction(
        transactionId = february.id,
        transaction = february.toNew(items = kept, amount = ABOVE_TOTAL_SUM, isReviewNeeded = false),
    )
    val read = assertNotNull(actual = world.home.findTransaction(id = february.id), message = "取引が読めない")
    assertEquals(expected = ABOVE_TOTAL_SUM, actual = read.amount, message = "差額を消して金額が 830円 でない")
    assertEquals(
        expected = listOf("唐揚げ弁当" to BENTO_AMOUNT, "緑茶" to TEA_AMOUNT),
        actual = read.itemsRead(),
        message = "差額を消して明細が 2 つでない",
    )
    assertFalse(actual = read.isReviewNeeded, message = "差額を消したのに印が外れない")
}

private suspend fun assertOnlyAboveTotalLeft(world: ReviewWorld) {
    val left: List<Uuid> = world.home.reviewNeededTransactions().map { it.id }
    assertEquals(
        expected = listOf(world.aboveTotal.id),
        actual = left,
        message = "家計の要確認が 2026-02-13 の 830円 だけでない",
    )
    assertEquals(
        expected = listOf(world.familyRecord.id),
        actual = world.family.reviewNeededTransactions().map { it.id },
        message = "実家の要確認が自分の記録のままでない",
    )
}
