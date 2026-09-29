package io.github.mktkhr.moneging

import android.app.Application
import io.github.mktkhr.moneging.di.initKoin

/**
 * The Android entry point. Starts the shared Koin container exactly once,
 * before any activity resolves a dependency from it.
 */
class MonegingApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initKoin(this)
    }
}
