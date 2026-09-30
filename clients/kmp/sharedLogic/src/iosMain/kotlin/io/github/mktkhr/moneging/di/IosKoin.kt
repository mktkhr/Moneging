package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.Preferences
import io.github.mktkhr.moneging.data.UserDefaultsPreferences
import io.github.mktkhr.moneging.data.localDataDirectory
import io.github.mktkhr.moneging.data.onDiskStore
import io.github.mktkhr.moneging.scan.IosReceiptReader
import io.github.mktkhr.moneging.scan.NoModuleInstaller
import io.github.mktkhr.moneging.scan.ReadingModuleInstaller
import io.github.mktkhr.moneging.scan.ReceiptScanner
import io.github.mktkhr.moneging.scan.ScanPacer
import io.github.mktkhr.moneging.scan.iosReceiptScanner
import org.koin.dsl.module
import kotlin.time.Clock

/**
 * Starts the shared Koin container for the iOS app: the store in
 * [localDataDirectory], reading receipts with [reader], and the preferences
 * in the user defaults. iOS downloads nothing to read from photos. Safe to
 * call more than once; only the first call takes effect.
 */
fun initKoin(reader: IosReceiptReader) {
    startIosKoin(
        clock = Clock.System,
        scanner = iosReceiptScanner(reader),
        scanPacer = ScanPacer.Immediate,
        installer = NoModuleInstaller,
    )
}

/** Starts the shared Koin container with the store on [clock], reading with [scanner] as [scanPacer] lets it. */
internal fun startIosKoin(
    clock: Clock,
    scanner: ReceiptScanner,
    scanPacer: ScanPacer,
    installer: ReadingModuleInstaller,
) {
    startSharedKoin(
        module {
            single<Clock> { clock }
            single<Preferences> { UserDefaultsPreferences() }
            single<LocalStore> {
                onDiskStore(
                    directory = localDataDirectory(),
                    preferences = get(),
                    clock = get(),
                    scanner = scanner,
                    scanPacer = scanPacer,
                )
            }
            // Its scanner, text recognition and Foundation Models are part of the OS.
            single { PhotoReadingSetup(modules = emptyList(), installer = installer) }
        },
    )
}
