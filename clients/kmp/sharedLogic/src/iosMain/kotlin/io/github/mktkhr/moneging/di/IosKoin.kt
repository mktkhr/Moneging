package io.github.mktkhr.moneging.di

import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.Preferences
import io.github.mktkhr.moneging.data.UserDefaultsPreferences
import io.github.mktkhr.moneging.data.localDataDirectory
import io.github.mktkhr.moneging.data.onDiskStore
import org.koin.dsl.module

/**
 * Starts the shared Koin container for the iOS app: the store in
 * [localDataDirectory] and the preferences in the user defaults. Safe to
 * call more than once; only the first call takes effect.
 */
fun initKoin() {
    startSharedKoin(
        module {
            single<Preferences> { UserDefaultsPreferences() }
            single<LocalStore> { onDiskStore(directory = localDataDirectory(), preferences = get()) }
        },
    )
}
