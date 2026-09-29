package io.github.mktkhr.moneging.domain

/**
 * The rule for a ledger's name (PRODUCT.md §3): surrounding whitespace is
 * removed, and what remains is 1 to [MAX_LENGTH] characters, counted as the
 * user sees them (an emoji is one character).
 */
object LedgerName {
    /** The longest name, in user-perceived characters. */
    const val MAX_LENGTH: Int = 20

    /** The name a ledger typed as [input] is stored under, or `null` when the rule refuses it. */
    fun normalized(input: String): String? {
        val trimmed = input.trim()
        return trimmed.takeIf { it.isNotEmpty() && userPerceivedLength(it) <= MAX_LENGTH }
    }

    /** Whether [input] names a ledger under the rule. */
    fun isValid(input: String): Boolean = normalized(input) != null
}

/**
 * The number of characters in [text] as the user sees them: extended
 * grapheme clusters, not UTF-16 units. Common Kotlin has no grapheme API,
 * so each platform counts with its own text segmentation.
 */
internal expect fun userPerceivedLength(text: String): Int
