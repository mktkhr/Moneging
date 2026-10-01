package io.github.mktkhr.moneging.domain

private const val FULL_WIDTH_ZERO = '０'
private const val FULL_WIDTH_NINE = '９'
private const val THOUSANDS_SEPARATORS = ",，"
private const val MAX_DIGITS = 15
private const val DIGIT_GROUP = 3
private const val MINUS_SIGNS = "-−－"
private const val MINUS = "-"

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

    /**
     * The whole number of yen of a line item's [text]: as [parse], with an
     * optional leading minus (`-250`, `−250`) for a discount item.
     */
    fun parseSigned(text: String): Long {
        val trimmed = text.trim()
        val isNegative = trimmed.firstOrNull()?.let { it in MINUS_SIGNS } == true
        val amount = parse(if (isNegative) trimmed.drop(n = 1) else trimmed)
        return if (isNegative) -amount else amount
    }

    /**
     * The digits of [text] grouped by thousands as a form shows them while
     * they are typed: `1200` as `1,200`, a leading minus kept (`-250`).
     */
    fun grouped(text: String): String {
        val sign = if (text.trim().firstOrNull()?.let { it in MINUS_SIGNS } == true) MINUS else ""
        return sign +
            text
                .filter { it in '0'..'9' }
                .reversed()
                .chunked(DIGIT_GROUP)
                .joinToString(separator = ",")
                .reversed()
    }
}
