package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LedgerScope
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.domain.Category
import kotlinx.datetime.YearMonth
import kotlin.uuid.Uuid

// Fixtures shared by the Recording money criteria (AC-B-201 to AC-B-210).

/** The month the fixtures' clock (2026-02-15) falls in. */
internal val FIXTURE_FEBRUARY: YearMonth = YearMonth.parse("2026-02")

/** A store on the fixtures' clock and device `D`, holding only the ledger `家計`, and that ledger's scope. */
internal suspend fun kakeiScope(clock: ManualClock = ManualClock(current = FIXTURE_NOON)): LedgerScope {
    val store = LocalStore.inMemory(clock = clock, deviceId = FIXTURE_DEVICE_ID)
    val ledger = store.createLedger(name = FIXTURE_LEDGER_NAME)
    return store.ledger(id = ledger.id)
}

/** The identifier of this ledger's category named [name]. */
internal suspend fun LedgerScope.categoryIdNamed(name: String): Uuid =
    categories().single { category: Category -> category.name == name }.id
