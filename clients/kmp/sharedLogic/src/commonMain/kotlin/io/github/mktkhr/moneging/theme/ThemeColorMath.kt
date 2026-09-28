package io.github.mktkhr.moneging.theme

import kotlin.math.round

// Pure colour arithmetic the theme builder needs; no platform colour type.
// Ported from takamai's `frontend/src/shared/theme/color.ts` (read
// 2026-09-28): same formulas, same rounding.

private const val HEX_RADIX = 16
private const val COLOR_CHANNEL_MASK = 255
private const val GREEN_CHANNEL_BIT_SHIFT = 8
private const val RED_CHANNEL_BIT_SHIFT = 16

private fun parseHexColorChannels(hex: String): Triple<Int, Int, Int> {
    val value = hex.substring(1).toInt(HEX_RADIX)
    return Triple(
        first = value shr RED_CHANNEL_BIT_SHIFT and COLOR_CHANNEL_MASK,
        second = value shr GREEN_CHANNEL_BIT_SHIFT and COLOR_CHANNEL_MASK,
        third = value and COLOR_CHANNEL_MASK,
    )
}

private fun formatHexColorChannels(channels: Triple<Int, Int, Int>): String {
    fun component(channel: Int): String = channel.toString(HEX_RADIX).padStart(2, '0')
    return "#${component(channels.first)}${component(channels.second)}${component(channels.third)}".uppercase()
}

/**
 * Mixes a colour toward white by [amount] (0 = unchanged, 1 = white), the
 * same formula the design's own mockups use for a dark-mode accent or a
 * light/dark tint.
 *
 * @param hex the base colour, as "#RRGGBB".
 * @param amount how far toward white, 0 to 1.
 */
fun mixTowardWhite(
    hex: String,
    amount: Double,
): String {
    val (r, g, b) = parseHexColorChannels(hex)

    fun mix(channel: Int): Int = round(channel + (COLOR_CHANNEL_MASK - channel) * amount).toInt()
    return formatHexColorChannels(Triple(first = mix(r), second = mix(g), third = mix(b)))
}

/** Appends an alpha channel (a two-digit hex suffix) to a "#RRGGBB" colour. */
fun withAlpha(
    hex: String,
    alphaHex: String,
): String = "$hex$alphaHex"
