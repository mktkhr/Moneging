package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.scan.ReadingMethods
import io.github.mktkhr.moneging.scan.ReadingModule
import io.github.mktkhr.moneging.scan.ReadingModuleInstaller
import io.github.mktkhr.moneging.state.AppState
import io.github.mktkhr.moneging.state.LedgerData
import io.github.mktkhr.moneging.state.LedgerEditor
import io.github.mktkhr.moneging.state.ScanData
import io.github.mktkhr.moneging.state.ScanEditor
import org.koin.core.context.startKoin
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * The dependency graph every client shares. [AppState] is a singleton:
 * every tab and every platform resolves the same instance, so the state it
 * publishes stays consistent across tabs; so are [LedgerData] and
 * [LedgerEditor], [ScanData] and [ScanEditor]. The platform's module provides
 * the on-device `LocalStore`, the `Preferences`, the `Clock` they read and
 * the [PhotoReadingSetup].
 */
internal val sharedModule =
    module {
        single {
            val photoReading = get<PhotoReadingSetup>()
            AppState(
                store = get(),
                preferences = get(),
                clock = get(),
                readingModules = photoReading.modules,
                moduleInstaller = photoReading.installer,
            )
        }
        single { LedgerData(store = get(), appState = get()) }
        single { LedgerEditor(store = get(), appState = get(), ledgerData = get()) }
        single { ScanData(store = get(), appState = get()) }
        single { ScanEditor(store = get(), appState = get(), clock = get()) }
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

/** Resolves the shared [ScanData] singleton. The platform's `initKoin` must have run first. */
fun sharedScanData(): ScanData = KoinPlatform.getKoin().get()

/** The device's reading method (the store's). The platform's `initKoin` must have run first. */
fun sharedReadingMethods(): ReadingMethods = KoinPlatform.getKoin().get<LocalStore>().readingMethods

/** Resolves the shared [ScanEditor] singleton. The platform's `initKoin` must have run first. */
fun sharedScanEditor(): ScanEditor = KoinPlatform.getKoin().get()

/** What a device downloads to read receipts from photos, and who downloads it. */
data class PhotoReadingSetup(
    /** The modules the device needs (none on iOS). */
    val modules: List<ReadingModule>,
    /** Who downloads them. */
    val installer: ReadingModuleInstaller,
)
