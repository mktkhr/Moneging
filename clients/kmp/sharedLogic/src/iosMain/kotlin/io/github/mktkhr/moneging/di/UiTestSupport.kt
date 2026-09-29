package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.UserDefaultsPreferences
import io.github.mktkhr.moneging.data.localDataDirectory
import io.github.mktkhr.moneging.data.todayInTokyo
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.runBlocking
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atTime
import kotlinx.datetime.toInstant
import org.koin.mp.KoinPlatform
import platform.Foundation.NSFileManager
import kotlin.time.Clock
import kotlin.time.Instant
import kotlin.time.TimeSource

private const val NOON = 12
private const val SEEDED_TRANSACTION_COUNT = 24
private const val SEEDED_AMOUNT_STEP = 100L

// Called only from the iOS app's debug builds (`#if DEBUG`), on a UI test's
// launch argument: the release app never calls them.

/**
 * Deletes everything the app keeps on the device (the database, the photos,
 * the ledger in view, the tour's progress, the device identifier), so the
 * app starts as freshly installed. Must run before [initKoin].
 */
@OptIn(ExperimentalForeignApi::class)
fun resetLocalDataForUiTests() {
    check(KoinPlatform.getKoinOrNull() == null) { "initKoin より前に呼んでください" }
    NSFileManager.defaultManager.removeItemAtPath(localDataDirectory(), error = null)
    UserDefaultsPreferences().clear()
}

/**
 * Starts the shared Koin container, like [initKoin], on a clock that reads
 * [isoDate] (`2026-02-15`) at 12:00 in Asia/Tokyo when the app launches and
 * advances with the time elapsed since: a UI test's today.
 */
fun initKoinForUiTests(isoDate: String) {
    val launchedAt = LocalDate.parse(isoDate).atTime(hour = NOON, minute = 0).toInstant(TimeZone.of("Asia/Tokyo"))
    val sinceLaunch = TimeSource.Monotonic.markNow()
    startIosKoin(
        clock =
            object : Clock {
                override fun now(): Instant = launchedAt + sinceLaunch.elapsedNow()
            },
    )
}

/**
 * Creates the ledgers [names], in order, with the first in view and the
 * tour finished, for UI tests that start past the onboarding; [withTransactions]
 * also records, in the first, [SEEDED_TRANSACTION_COUNT] expenses of 食費 dated
 * today, memos `記録01` onwards. Must run after [initKoin] and before the app
 * state is first resolved.
 */
fun seedLedgersForUiTests(
    names: List<String>,
    withTransactions: Boolean,
) {
    val koin = KoinPlatform.getKoin()
    val store = koin.get<LocalStore>()
    val today = koin.get<Clock>().todayInTokyo()
    val preferences = UserDefaultsPreferences()
    val ledgers = runBlocking { names.map { store.createLedger(it) } }
    val first = ledgers.firstOrNull()
    if (withTransactions && first != null) {
        runBlocking {
            val scope = store.ledger(first.id)
            val food = scope.categories().first().id
            for (number in 1..SEEDED_TRANSACTION_COUNT) {
                scope.recordTransaction(
                    NewTransaction(
                        date = today,
                        direction = Direction.EXPENSE,
                        amount = number * SEEDED_AMOUNT_STEP,
                        categoryId = food,
                        memo = "記録" + number.toString().padStart(length = 2, padChar = '0'),
                    ),
                )
            }
        }
    }
    preferences.setString(key = PreferenceKeys.LEDGER_IN_VIEW, value = ledgers.firstOrNull()?.id?.toString())
    preferences.setString(key = PreferenceKeys.TOUR_NEXT_STEP, value = PreferenceKeys.TOUR_FINISHED)
}
