package io.github.mktkhr.moneging.data

import kotlin.uuid.Uuid

/**
 * Small values kept on the device outside the database: the ledger in
 * view, the tour's progress, the device identifier.
 */
interface Preferences {
    /** The value stored under [key], or `null`. */
    fun string(key: String): String?

    /** Stores [value] under [key]; `null` removes it. */
    fun setString(
        key: String,
        value: String?,
    )
}

/** [Preferences] held in memory, for tests. */
class InMemoryPreferences : Preferences {
    private val values = mutableMapOf<String, String>()

    override fun string(key: String): String? = values[key]

    override fun setString(
        key: String,
        value: String?,
    ) {
        if (value == null) values.remove(key) else values[key] = value
    }
}

/** The keys under which the app keeps its [Preferences]. */
internal object PreferenceKeys {
    /** The identifier of the ledger last in view. */
    const val LEDGER_IN_VIEW = "ledgerInView"

    /** The first tour step not yet done, or [TOUR_FINISHED]. */
    const val TOUR_NEXT_STEP = "tourNextStep"

    /** The value of [TOUR_NEXT_STEP] once the tour is finished or skipped. */
    const val TOUR_FINISHED = "finished"

    /** This install's device identifier. */
    const val DEVICE_ID = "deviceId"

    /** Whether reading receipts from photos is enabled: [PHOTO_READING_ON] when it is. */
    const val PHOTO_READING = "photoReading"

    /** The value of [PHOTO_READING] while reading from photos is enabled. */
    const val PHOTO_READING_ON = "on"

    /** The reading method the user chose (`ReadingMethod` name); absent until they choose. */
    const val READING_METHOD = "readingMethod"
}

/**
 * This install's device identifier: generated once and kept in
 * [preferences], so every transaction recorded on the device names the
 * same one.
 */
internal fun deviceId(preferences: Preferences): String =
    preferences.string(PreferenceKeys.DEVICE_ID)
        ?: Uuid.random().toString().also { preferences.setString(key = PreferenceKeys.DEVICE_ID, value = it) }
