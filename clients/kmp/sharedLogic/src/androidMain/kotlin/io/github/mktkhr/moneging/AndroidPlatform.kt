package io.github.mktkhr.moneging

import android.os.Build

/**
 * Android implementation of [Platform], reporting the running OS version.
 */
class AndroidPlatform : Platform {
    override val name: String = "Android ${Build.VERSION.SDK_INT}"
}

/**
 * Returns the Android [Platform] implementation.
 */
actual fun getPlatform(): Platform = AndroidPlatform()
