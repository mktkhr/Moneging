package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.UserDefaultsPreferences
import io.github.mktkhr.moneging.data.localDataDirectory
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.runBlocking
import org.koin.mp.KoinPlatform
import platform.Foundation.NSFileManager

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
 * Creates the ledgers [names], in order, with the first in view and the
 * tour finished, for UI tests that start past the onboarding. Must run
 * after [initKoin] and before the app state is first resolved.
 */
fun seedLedgersForUiTests(names: List<String>) {
    val koin = KoinPlatform.getKoin()
    val store = koin.get<LocalStore>()
    val preferences = UserDefaultsPreferences()
    val ledgers = runBlocking { names.map { store.createLedger(it) } }
    preferences.setString(key = PreferenceKeys.LEDGER_IN_VIEW, value = ledgers.firstOrNull()?.id?.toString())
    preferences.setString(key = PreferenceKeys.TOUR_NEXT_STEP, value = PreferenceKeys.TOUR_FINISHED)
}
