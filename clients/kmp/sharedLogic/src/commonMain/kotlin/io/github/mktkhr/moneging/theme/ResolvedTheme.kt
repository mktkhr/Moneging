package io.github.mktkhr.moneging.theme

/**
 * One style/colour/scheme combination's semantic tokens, resolved from
 * [themeStyles] and the derivation rules in `ThemeTokens.kt` - the roles a
 * client actually paints with (background, surface, text, muted text,
 * line, accent, its tint, and the "glass" surface), rather than the raw
 * per-style/per-scheme data. Every value is a colour string ("#RRGGBB" or
 * "#RRGGBBAA"; `glassBorder`/`glassShadow` stay raw CSS `rgba()` strings,
 * unused by this shell yet - see their own fields' doc comments), so
 * either platform maps it to its own colour type.
 *
 * Not ported: takamai's `success`/`warning`/`error`/typography/shape/chart
 * tokens (`createAppTheme.ts`'s `buildPalette`/`buildTypography`) - out of
 * scope for this shell, which only needs the palette this struct exposes.
 */
data class ResolvedTheme(
    /** Screen background. */
    val background: String,
    /** A card/row's own surface, distinct from [background]. */
    val surface: String,
    /** Primary text. */
    val text: String,
    /** Secondary/muted text. */
    val mutedText: String,
    /** Hairline dividers and card borders. */
    val line: String,
    /** Primary accent color: buttons, the selected tab, checkmarks. */
    val accent: String,
    /** The colour scheme's own fixed text/icon colour drawn on top of [accent]. */
    val onAccent: String,
    /** The colour of a positive (income) amount. */
    val income: String,
    /** A soft tinted background derived from [accent] (e.g. a selected pill). */
    val accentTint: String,
    /** A translucent "glass" surface, over a blur, for floating chrome. */
    val glassSurface: String,
    /** [glassSurface]'s own border colour - a raw CSS `rgba()` string, unused by this shell yet. */
    val glassBorder: String,
    /** [glassSurface]'s own drop shadow - a raw CSS `box-shadow` string, unused by this shell yet. */
    val glassShadow: String,
    /**
     * A floating element's own drop shadow colour (the style's `shadow`
     * token, [StyleSchemeTokens.shadow]), as "#RRGGBBAA" - transparent
     * black when the style has no shadow ([CardStyle.Border] styles, whose
     * `shadow` token is `"none"`).
     */
    val shadowColor: String,
    /** [shadowColor]'s own vertical offset, in points (0 when there is no shadow). */
    val shadowOffsetY: Double,
    /** [shadowColor]'s own blur radius, in points (0 when there is no shadow). */
    val shadowBlurRadius: Double,
)

// ResolvedTheme.shadowColor for a style with no shadow token ("none").
private const val NO_SHADOW_COLOR = "#00000000"

/**
 * Resolves [style]'s tokens for [color] and [scheme] into the semantic
 * roles a client paints with. Mirrors takamai's `createAppTheme.ts`
 * `buildScheme`/`buildPalette` (read 2026-09-28): same derivation, same
 * source values, restricted to the colour roles this module ports (see
 * [ResolvedTheme]'s doc comment for what is intentionally left out).
 */
fun resolveTheme(
    style: ThemeStyle,
    color: ThemeColor,
    scheme: ThemeScheme,
): ResolvedTheme {
    val tokens = themeStyles.getValue(style)
    val schemeTokens = if (scheme == ThemeScheme.Light) tokens.light else tokens.dark
    val colorHex = color.hex

    val accent = mixTowardWhite(colorHex, accentMixTowardWhite.getValue(scheme))
    val tint = mixTowardWhite(colorHex, tintMixTowardWhite.getValue(scheme))
    val accentTint = if (scheme == ThemeScheme.Light) tint else withAlpha(hex = tint, alphaHex = TINT_DARK_ALPHA)
    val shadow = parseCssBoxShadow(schemeTokens.shadow)

    return ResolvedTheme(
        background = schemeTokens.bg,
        surface = schemeTokens.surface,
        text = schemeTokens.text,
        mutedText = schemeTokens.muted,
        line = schemeTokens.line,
        accent = accent,
        onAccent = onAccent.getValue(scheme),
        income = schemeTokens.income,
        accentTint = accentTint,
        glassSurface = withAlpha(hex = schemeTokens.surface, alphaHex = glassSurfaceAlpha.getValue(scheme)),
        glassBorder = glassBorder.getValue(scheme),
        glassShadow = glassShadow.getValue(scheme),
        shadowColor = shadow?.colorHex ?: NO_SHADOW_COLOR,
        shadowOffsetY = shadow?.offsetY ?: 0.0,
        shadowBlurRadius = shadow?.blurRadius ?: 0.0,
    )
}
