package io.github.mktkhr.moneging.theme

import kotlin.math.floor

// Pure colour arithmetic the theme builder needs; no platform colour type.
// Ported from takamai's `frontend/src/shared/theme/color.ts` (read
// 2026-09-28): same formulas, same rounding.

private const val HEX_RADIX = 16
private const val COLOR_CHANNEL_MASK = 255
private const val GREEN_CHANNEL_BIT_SHIFT = 8
private const val RED_CHANNEL_BIT_SHIFT = 16

// `kotlin.math.round` ties-to-even (banker's rounding); JavaScript's
// `Math.round`, which takamai's own arithmetic runs on, always rounds a
// `.5` up. `floor(x + halfUpOffset)` matches `Math.round` exactly instead.
private const val HALF_UP_OFFSET = 0.5

private fun roundHalfUpLikeJsMathRound(value: Double): Int = floor(value + HALF_UP_OFFSET).toInt()

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

    fun mix(channel: Int): Int = roundHalfUpLikeJsMathRound(channel + (COLOR_CHANNEL_MASK - channel) * amount)
    return formatHexColorChannels(Triple(first = mix(r), second = mix(g), third = mix(b)))
}

/** Appends an alpha channel (a two-digit hex suffix) to a "#RRGGBB" colour. */
fun withAlpha(
    hex: String,
    alphaHex: String,
): String = "$hex$alphaHex"

private val CSS_BOX_SHADOW_REGEX =
    Regex("""^(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?\s+rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$""")

// `MatchResult.groupValues` indices into `CSS_BOX_SHADOW_REGEX`; index 0 is
// the whole match, so the first capture group is 1.
private const val OFFSET_X_GROUP = 1
private const val OFFSET_Y_GROUP = 2
private const val BLUR_RADIUS_GROUP = 3
private const val RED_GROUP = 4
private const val GREEN_GROUP = 5
private const val BLUE_GROUP = 6
private const val ALPHA_GROUP = 7

/** One parsed CSS `box-shadow` layer: geometry plus its colour, as `parseCssBoxShadow` reads it. */
data class ParsedBoxShadow(
    /** Horizontal offset, in points. */
    val offsetX: Double,
    /** Vertical offset, in points. */
    val offsetY: Double,
    /** Blur radius, in points. */
    val blurRadius: Double,
    /** The shadow's colour, as "#RRGGBBAA". */
    val colorHex: String,
)

/**
 * Parses a takamai `StyleSchemeTokens.shadow` CSS `box-shadow` value (e.g.
 * `"0 8px 22px rgba(120,80,40,0.09)"`) into its geometry and colour.
 *
 * Returns `null` for `"none"` (a style with a flat/bordered card,
 * [CardStyle.Border]) or any other value this single-layer shorthand does
 * not match.
 */
fun parseCssBoxShadow(css: String): ParsedBoxShadow? {
    val match = CSS_BOX_SHADOW_REGEX.find(css) ?: return null
    val groups = match.groupValues

    fun component(channel: String): String = channel.toInt().toString(HEX_RADIX).padStart(2, '0')
    val alphaHex =
        roundHalfUpLikeJsMathRound(groups[ALPHA_GROUP].toDouble() * COLOR_CHANNEL_MASK)
            .toString(HEX_RADIX)
            .padStart(2, '0')
    val colorHex =
        "#${component(groups[RED_GROUP])}${component(groups[GREEN_GROUP])}${component(groups[BLUE_GROUP])}$alphaHex"
            .uppercase()

    return ParsedBoxShadow(
        offsetX = groups[OFFSET_X_GROUP].toDouble(),
        offsetY = groups[OFFSET_Y_GROUP].toDouble(),
        blurRadius = groups[BLUR_RADIUS_GROUP].toDouble(),
        colorHex = colorHex,
    )
}
