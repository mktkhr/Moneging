package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.state.AppState
import org.koin.core.context.startKoin
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * The dependency graph every client shares. [AppState] is a singleton:
 * every tab and every platform resolves the same instance, so the state it
 * publishes stays consistent across tabs.
 */
val sharedModule =
    module {
        single { AppState() }
    }

/**
 * Starts the shared Koin container. Safe to call more than once (e.g. from
 * a SwiftUI `App` re-entering `init`); only the first call takes effect.
 */
fun initKoin() {
    if (KoinPlatform.getKoinOrNull() != null) return
    startKoin {
        modules(sharedModule)
    }
}

/**
 * Resolves the shared [AppState] singleton. [initKoin] must have run
 * first.
 */
fun sharedAppState(): AppState = KoinPlatform.getKoin().get()
