package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.state.AppState
import io.github.mktkhr.moneging.state.LedgerData
import io.github.mktkhr.moneging.state.LedgerEditor
import org.koin.core.context.startKoin
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * The dependency graph every client shares. [AppState] is a singleton:
 * every tab and every platform resolves the same instance, so the state it
 * publishes stays consistent across tabs; so are [LedgerData] and
 * [LedgerEditor]. The platform's module provides the on-device `LocalStore`,
 * the `Preferences` and the `Clock` they read.
 */
internal val sharedModule =
    module {
        single { AppState(store = get(), preferences = get(), clock = get()) }
        single { LedgerData(store = get(), appState = get()) }
        single { LedgerEditor(store = get(), appState = get(), ledgerData = get()) }
    }

/**
 * Starts the shared Koin container with [platformModule]. Safe to call more
 * than once (e.g. from a SwiftUI `App` re-entering `init`); only the first
 * call takes effect.
 */
internal fun startSharedKoin(platformModule: Module) {
    if (KoinPlatform.getKoinOrNull() != null) return
    startKoin {
        modules(platformModule, sharedModule)
    }
}

/**
 * Resolves the shared [AppState] singleton. The platform's `initKoin` must
 * have run first.
 */
fun sharedAppState(): AppState = KoinPlatform.getKoin().get()

/** Resolves the shared [LedgerData] singleton. The platform's `initKoin` must have run first. */
fun sharedLedgerData(): LedgerData = KoinPlatform.getKoin().get()

/** Resolves the shared [LedgerEditor] singleton. The platform's `initKoin` must have run first. */
fun sharedLedgerEditor(): LedgerEditor = KoinPlatform.getKoin().get()
