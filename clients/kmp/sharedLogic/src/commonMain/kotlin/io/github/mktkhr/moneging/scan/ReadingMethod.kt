package io.github.mktkhr.moneging.scan

import io.github.mktkhr.moneging.data.InMemoryPreferences
import io.github.mktkhr.moneging.data.PreferenceKeys
import io.github.mktkhr.moneging.data.Preferences

/** How recognised text is structured into a draft (PRODUCT.md §3, Reading method). */
enum class ReadingMethod {
    /** The device's own AI: Apple Intelligence on iOS, Gemini Nano on Android. */
    DEVICE_AI,

    /** The rule-based parser, which uses no AI (`AI を使わない`). */
    NO_AI,
}

// The name of the method that uses no AI.
private const val NO_AI_NAME = "AI を使わない"

// What the device's AI is called when its platform gives no name.
private const val GENERIC_AI_NAME = "端末の AI"

/**
 * The reading method of the device (PRODUCT.md §3, Reading method): the one
 * the user chose, kept in [preferences], or, for a user who never chose, the
 * device's AI ([llm], named [aiName]) when it can be used, else `AI を使わない`.
 * A method is never switched on its own.
 */
class ReadingMethods(
    private val llm: OnDeviceLlm?,
    private val preferences: Preferences = InMemoryPreferences(),
    /** What the device's AI is called (`Apple Intelligence`, `Gemini Nano`). */
    val aiName: String = GENERIC_AI_NAME,
) {
    /** Whether the device's AI can be used now. */
    val isDeviceAiUsable: Boolean
        get() = llm?.isAvailable == true

    /** Why the device's AI cannot be used, or `null` when it can. */
    val deviceAiUnavailableReason: String?
        get() = if (isDeviceAiUsable) null else llm?.unavailableReason ?: "この端末では $aiName を使えません"

    /** The method scans are read by. */
    val chosen: ReadingMethod
        get() =
            preferences.string(PreferenceKeys.READING_METHOD)?.let { stored ->
                ReadingMethod.entries.firstOrNull { it.name == stored }
            } ?: if (isDeviceAiUsable) ReadingMethod.DEVICE_AI else ReadingMethod.NO_AI

    /** Whether [chosen] cannot be used now: the device's AI chosen while it is unusable. */
    val isChosenUnusable: Boolean
        get() = chosen == ReadingMethod.DEVICE_AI && !isDeviceAiUsable

    /** The title of the notice shown before a scan when [chosen] cannot be used. */
    val unusableTitle: String
        get() = "$aiName が使えません"

    /** Keeps [method] as the device's choice. */
    fun choose(method: ReadingMethod) {
        preferences.setString(key = PreferenceKeys.READING_METHOD, value = method.name)
    }

    /** The name of [method] (`Apple Intelligence`, `AI を使わない`). */
    fun nameOf(method: ReadingMethod): String =
        when (method) {
            ReadingMethod.DEVICE_AI -> aiName
            ReadingMethod.NO_AI -> NO_AI_NAME
        }

    /** What a draft read by [method] says (`Apple Intelligence で読み取りました`). */
    fun readText(method: ReadingMethod): String =
        when (method) {
            ReadingMethod.DEVICE_AI -> "$aiName で読み取りました"
            ReadingMethod.NO_AI -> "AI を使わずに読み取りました"
        }
}
