package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.state.AppViewModel
import org.koin.core.context.startKoin
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * The dependency graph every client shares. [AppViewModel] is a singleton:
 * every tab and every platform resolves the same instance, so the state it
 * publishes stays consistent across tabs.
 */
val sharedModule =
    module {
        single { AppViewModel() }
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
 * Resolves the shared [AppViewModel] singleton. [initKoin] must have run
 * first.
 */
fun sharedAppViewModel(): AppViewModel = KoinPlatform.getKoin().get()
