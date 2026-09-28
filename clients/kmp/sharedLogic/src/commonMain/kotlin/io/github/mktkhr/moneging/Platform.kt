package io.github.mktkhr.moneging

/**
 * Describes the platform the app is currently running on.
 */
interface Platform {
    /** A human-readable platform name, e.g. "Android 34" or "iOS 18.0". */
    val name: String
}

/**
 * Returns the [Platform] implementation for the current target.
 */
expect fun getPlatform(): Platform
