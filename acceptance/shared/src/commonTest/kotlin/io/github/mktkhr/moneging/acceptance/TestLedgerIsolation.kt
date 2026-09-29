package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.Ledger
import io.github.mktkhr.moneging.domain.NewTransaction
import io.github.mktkhr.moneging.domain.Photo
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull

private const val LEDGER_A_NAME = "A"
private const val LEDGER_B_NAME = "花子の家計"
private const val LEDGER_B_CATEGORY_NAME = "花子のおこづかい"
private const val PHOTO_CONTENT_TYPE = "image/jpeg"
private const val PHOTO_CONTENT = "receipt photo bytes"

/**
 * AC-B-107 — An operation in one ledger cannot read or write another.
 *
 * Given ledgers `A` and `B`, `B` named `花子の家計`, with a category and a
 * photo in `B`. When, acting within `A`, that category and that photo are read
 * by their identifiers, then neither is found, and nothing returned names
 * `花子の家計`. When `B` is read, then it is `花子の家計`, unchanged.
 */
class TestLedgerIsolation {
    /** Reads and writes within `A` never reach `B`'s category or photo, and `B` stays as it was. */
    @Test
    fun ledgerCannotReadOrWriteAnother(): TestResult =
        runTest {
            val store = LocalStore.inMemory(clock = ManualClock(current = FIXTURE_NOON), deviceId = FIXTURE_DEVICE_ID)
            val ledgerA = store.createLedger(name = LEDGER_A_NAME)
            val ledgerB = store.createLedger(name = LEDGER_B_NAME)
            val scopeB = store.ledger(id = ledgerB.id)
            val categoryB = scopeB.createCategory(name = LEDGER_B_CATEGORY_NAME)
            val photoB =
                scopeB.addPhoto(
                    bytes = PHOTO_CONTENT.encodeToByteArray(),
                    contentType = PHOTO_CONTENT_TYPE,
                    capturedAt = FIXTURE_NOON,
                )
            val ledgerBBefore = store.findLedger(id = ledgerB.id)
            val categoriesBBefore = scopeB.categories()

            assertReadsWithinADoNotReachB(store = store, ledgerA = ledgerA, categoryB = categoryB, photoB = photoB)
            assertWritesWithinADoNotReachB(store = store, ledgerA = ledgerA, categoryB = categoryB, photoB = photoB)

            // B, read afterwards, is 花子の家計, unchanged.
            val ledgerBAfter = store.findLedger(id = ledgerB.id)
            assertEquals(expected = LEDGER_B_NAME, actual = ledgerBAfter?.name)
            assertEquals(expected = ledgerBBefore, actual = ledgerBAfter)
            val categoriesBAfter = scopeB.categories()
            assertEquals(expected = categoriesBBefore, actual = categoriesBAfter)
            assertEquals(
                expected = DEFAULT_CATEGORY_NAMES + LEDGER_B_CATEGORY_NAME,
                actual = categoriesBAfter.map { category -> category.name },
            )
            assertEquals(expected = categoryB, actual = scopeB.findCategory(id = categoryB.id))
            val photoBAfter = scopeB.findPhoto(id = photoB.id)
            assertEquals(expected = photoB, actual = photoBAfter)
            assertEquals(expected = PHOTO_CONTENT_TYPE, actual = photoBAfter?.contentType)
            assertEquals(expected = PHOTO_CONTENT.encodeToByteArray().size.toLong(), actual = photoBAfter?.sizeBytes)
            assertEquals(expected = FIXTURE_NOON, actual = photoBAfter?.capturedAt)
        }
}

// Acting within ledgerA, categoryB and photoB are not found by their identifiers, and nothing names B.
internal suspend fun assertReadsWithinADoNotReachB(
    store: LocalStore,
    ledgerA: Ledger,
    categoryB: Category,
    photoB: Photo,
) {
    val scopeA = store.ledger(id = ledgerA.id)
    val categoryReadInA = scopeA.findCategory(id = categoryB.id)
    val photoReadInA = scopeA.findPhoto(id = photoB.id)
    val categoriesOfA = scopeA.categories()
    val ledgerReadInA = store.findLedger(id = ledgerA.id)

    assertNull(actual = categoryReadInA, message = "A から B の分類が読めた")
    assertNull(actual = photoReadInA, message = "A から B の写真が読めた")
    assertEquals(expected = DEFAULT_CATEGORY_NAMES, actual = categoriesOfA.map { category -> category.name })
    assertEquals(expected = LEDGER_A_NAME, actual = ledgerReadInA?.name)
    val returnedInA: List<Any> = listOfNotNull(categoryReadInA, photoReadInA, ledgerReadInA) + categoriesOfA
    assertFalse(
        actual = returnedInA.any { returned -> returned.toString().contains(other = LEDGER_B_NAME) },
        message = "A での読み取り結果に 花子の家計 が含まれる",
    )
}

// Acting within ledgerA, recording through categoryB or photoB is refused and writes nothing anywhere.
internal suspend fun assertWritesWithinADoNotReachB(
    store: LocalStore,
    ledgerA: Ledger,
    categoryB: Category,
    photoB: Photo,
) {
    val scopeA = store.ledger(id = ledgerA.id)
    val categoryOfA = scopeA.categories().first()
    val date = LocalDate.parse("2026-02-15")

    assertFailsWith<IllegalArgumentException>(message = "A に B の分類で記録できた") {
        scopeA.recordTransaction(
            transaction =
                NewTransaction(
                    date = date,
                    direction = Direction.EXPENSE,
                    amount = 1_200L,
                    categoryId = categoryB.id,
                ),
        )
    }
    assertFailsWith<IllegalArgumentException>(message = "A の記録に B の写真を紐づけられた") {
        scopeA.recordTransaction(
            transaction =
                NewTransaction(
                    date = date,
                    direction = Direction.EXPENSE,
                    amount = 1_200L,
                    categoryId = categoryOfA.id,
                    photoId = photoB.id,
                ),
        )
    }

    val month = YearMonth.parse("2026-02")
    val ledgerIds = listOf(ledgerA.id, categoryB.ledgerId)
    assertEquals(
        expected = listOf(0, 0),
        actual = ledgerIds.map { ledgerId -> store.ledger(id = ledgerId).transactions(month = month).size },
        message = "拒否された書き込みで取引が残った",
    )
}
