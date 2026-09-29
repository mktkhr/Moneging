package io.github.mktkhr.moneging.di

import android.content.Context
import io.github.mktkhr.moneging.data.LocalStore
import io.github.mktkhr.moneging.data.Preferences
import io.github.mktkhr.moneging.data.SharedPreferencesStore
import io.github.mktkhr.moneging.data.onDiskStore
import org.koin.dsl.module

/**
 * Starts the shared Koin container for the Android app: the store and the
 * preferences in [context]'s private storage. Safe to call more than once;
 * only the first call takes effect.
 */
fun initKoin(context: Context) {
    val application = context.applicationContext
    startSharedKoin(
        module {
            single<Preferences> { SharedPreferencesStore(application) }
            single<LocalStore> { onDiskStore(context = application, preferences = get()) }
        },
    )
}
