package io.github.mktkhr.moneging.scan

import kotlinx.datetime.LocalDate

// The confidence the rule-based parser gives every field and item it read,
// and that of a field it did not read.
private const val RULE_CONFIDENCE = 0.7
private const val NOT_READ = 0.0

private val DATE = Regex("""(\d{4})/(\d{2})/(\d{2})""")
private val AMOUNT = Regex("""[¥￥]\s*(\d[\d,]*)""")
private val AMOUNT_AT_END = Regex("""^(.*?)\s*[¥￥]\s*(\d[\d,]*)$""")
private const val TOTAL_PREFIX = "合計"
private const val SUBTOTAL_PREFIX = "小計"
private const val ADD_ON_PREFIX = "+"

/** Structures the text recognised from a receipt into a reading. */
fun interface ReceiptTextParser {
    /** The reading of [text], one receipt row per line. */
    fun parse(text: String): ReceiptReading
}

/**
 * The deterministic parser used on a device without an on-device LLM
 * (PRODUCT.md §3, Scanner), by the rules of `acceptance/fixtures/README.md`:
 * the store is the first line, the date the first `yyyy/mm/dd`, the total
 * the amount on the line starting with `合計`, and the items the lines
 * between the date and the first `小計` or `合計` that end with an amount
 * (`¥` and digits), except add-ons starting with `+`. It does not classify:
 * every item has no category. Everything it read has the confidence 0.7.
 */
class RuleBasedReceiptParser : ReceiptTextParser {
    override fun parse(text: String): ReceiptReading {
        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        val dateLine = lines.indexOfFirst { DATE.containsMatchIn(it) }
        val date = if (dateLine >= 0) DATE.find(lines[dateLine])?.let(::toDate) else null
        val totalLine = lines.firstOrNull { it.startsWith(TOTAL_PREFIX) }
        val total = totalLine?.let { AMOUNT.find(it) }?.let { yen(it.groupValues[1]) }
        val subtotalLine = lines.indexOfFirst { it.startsWith(SUBTOTAL_PREFIX) || it.startsWith(TOTAL_PREFIX) }
        val itemsEnd = if (subtotalLine >= 0) subtotalLine else lines.size
        val itemsStart = if (dateLine >= 0) dateLine + 1 else 1
        val items =
            lines
                .subList(fromIndex = minOf(a = itemsStart, b = itemsEnd), toIndex = itemsEnd)
                .asSequence()
                .filterNot { it.startsWith(ADD_ON_PREFIX) }
                .mapNotNull { line -> AMOUNT_AT_END.find(line) }
                .map(::itemOf)
                .toList()
        return ReceiptReading(
            store = ScannedValue(value = lines.firstOrNull().orEmpty(), confidence = confidenceOf(lines.firstOrNull())),
            date = ScannedValue(value = date, confidence = confidenceOf(date)),
            total = ScannedValue(value = total, confidence = confidenceOf(total)),
            items = items,
        )
    }
}

// The confidence of a field that is [value]: 0.7 when it was read, 0 when not.
internal fun confidenceOf(value: Any?): Double = if (value != null) RULE_CONFIDENCE else NOT_READ

// The item of a line ending with an amount: its name is the text before it.
internal fun itemOf(match: MatchResult): ReceiptItem =
    ReceiptItem(
        name = match.groupValues[1],
        amount = yen(match.groupValues[2]),
        category = null,
        confidence = RULE_CONFIDENCE,
    )

internal fun toDate(match: MatchResult): LocalDate? {
    val (year, month, day) = match.destructured
    return runCatching { LocalDate(year = year.toInt(), month = month.toInt(), day = day.toInt()) }.getOrNull()
}

internal fun yen(digits: String): Long = digits.filter { it.isDigit() }.toLong()
