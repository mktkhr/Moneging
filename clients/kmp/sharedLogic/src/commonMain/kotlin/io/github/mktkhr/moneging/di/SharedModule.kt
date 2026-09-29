package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.state.AppState
import org.koin.core.context.startKoin
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * The dependency graph every client shares. [AppState] is a singleton:
 * every tab and every platform resolves the same instance, so the state it
 * publishes stays consistent across tabs. The platform's module provides
 * the on-device `LocalStore` and `Preferences` it reads.
 */
internal val sharedModule =
    module {
        single { AppState(store = get(), preferences = get()) }
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
