package io.github.mktkhr.moneging.domain

private const val FULL_WIDTH_ZERO = '０'
private const val FULL_WIDTH_NINE = '９'
private const val THOUSANDS_SEPARATORS = ",，"
private const val MAX_DIGITS = 15
private const val DIGIT_GROUP = 3

/**
 * The amount text of a form, read as whole yen: every client reads what the
 * user typed the same way.
 */
object AmountText {
    /**
     * The whole number of yen [text] holds: digits (full-width digits are
     * read as digits), optionally grouped with commas, with surrounding
     * whitespace ignored. Anything else, a fraction or a unit included, is
     * refused with [IllegalArgumentException].
     */
    fun parse(text: String): Long {
        val digits =
            text
                .trim()
                .filterNot { it in THOUSANDS_SEPARATORS }
                .map { if (it in FULL_WIDTH_ZERO..FULL_WIDTH_NINE) '0' + (it - FULL_WIDTH_ZERO) else it }
                .joinToString(separator = "")
        require(digits.isNotEmpty() && digits.length <= MAX_DIGITS && digits.all { it in '0'..'9' }) {
            "金額は円単位の整数で入力してください"
        }
        return digits.toLong()
    }

    /** The digits of [text] grouped by thousands as a form shows them while they are typed: `1200` as `1,200`. */
    fun grouped(text: String): String =
        text
            .filter { it in '0'..'9' }
            .reversed()
            .chunked(DIGIT_GROUP)
            .joinToString(separator = ",")
            .reversed()
}
