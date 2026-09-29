package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LocalStore
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * AC-B-104 — A ledger is created and listed.
 *
 * Given a device with no ledger. When the ledger `家計` is created, then the
 * ledgers listed are exactly `家計`, with the twelve default categories.
 */
class TestCreateLedger {
    /** Creating `家計` on an empty device lists exactly `家計`, holding the twelve default categories. */
    @Test
    fun createsLedgerWithDefaults(): TestResult =
        runTest {
            val store = LocalStore.inMemory(clock = ManualClock(current = FIXTURE_NOON), deviceId = FIXTURE_DEVICE_ID)
            assertEquals(expected = emptyList(), actual = store.ledgers(), message = "端末に家計簿がない状態から始まらない")

            val created = store.createLedger(name = FIXTURE_LEDGER_NAME)

            assertEquals(expected = FIXTURE_LEDGER_NAME, actual = created.name)
            val listed = store.ledgers()
            assertEquals(expected = listOf(FIXTURE_LEDGER_NAME), actual = listed.map { ledger -> ledger.name })
            assertEquals(expected = listOf(created.id), actual = listed.map { ledger -> ledger.id })

            val categories = store.ledger(id = created.id).categories()
            assertEquals(expected = DEFAULT_CATEGORY_NAMES, actual = categories.map { category -> category.name })
            assertEquals(
                expected = List(size = DEFAULT_CATEGORY_NAMES.size) { created.id },
                actual = categories.map { category -> category.ledgerId },
                message = "既定の分類がその家計簿に属していない",
            )
            assertEquals(
                expected = List(size = DEFAULT_CATEGORY_NAMES.size) { false },
                actual = categories.map { category -> category.isArchived },
                message = "既定の分類がアーカイブされている",
            )
            assertEquals(
                expected = DEFAULT_CATEGORY_NAMES.size,
                actual = categories.map { category -> category.id }.toSet().size,
                message = "既定の分類の識別子が重複している",
            )
        }
}
