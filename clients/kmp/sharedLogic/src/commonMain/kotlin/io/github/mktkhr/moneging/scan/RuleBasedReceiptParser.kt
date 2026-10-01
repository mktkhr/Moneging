package io.github.mktkhr.moneging.scan

import kotlinx.datetime.LocalDate
import kotlin.math.abs

// The confidence the rule-based parser gives every field and item it read,
// and that of a field it did not read.
private const val RULE_CONFIDENCE = 0.7
private const val NOT_READ = 0.0

private val DATE = Regex("""(\d{4})(?:/(\d{2})/(\d{2})|年(\d{2})月(\d{2})日)""")
private const val TOTAL_PREFIX = "合計"
private val ITEMS_END_PREFIXES = listOf("小計", TOTAL_PREFIX, "(")
private val ADDED_TAX_MARKS = listOf("外税", "外8%", "外10%", "税抜")
private const val DELIVERY_FIRST_LINE = "Uber Eats"
private const val ADDED_TAX_NAME = "消費税"

/** Structures the text recognised from a receipt into a reading. */
fun interface ReceiptTextParser {
    /** The reading of [text], one receipt row per line. */
    fun parse(text: String): ReceiptReading
}

/**
 * The deterministic parser used on a device without an on-device LLM
 * (PRODUCT.md §3, Scanner and Draft), by the rules of
 * `acceptance/fixtures/README.md`: the store is the well-known chain
 * ([ReceiptChains]) the text names first, else the first line; the date the
 * first `yyyy/mm/dd` or `yyyy年mm月dd日`; the total the amount on the first
 * line starting with `合計`; the items the lines between the date and the
 * first `小計`, `合計`, `（` or `(`, reading quantity, discount and option
 * lines into the item they belong to, and an added `消費税` when the prices
 * exclude tax. It does not classify: every item has no category. Everything
 * it read has the confidence 0.7.
 */
class RuleBasedReceiptParser : ReceiptTextParser {
    override fun parse(text: String): ReceiptReading {
        val lines = receiptRows(text)
        // Rules are matched on the lines with their look-alikes read as one; names keep them.
        val readableLines = lines.map(::readable)
        val dateLine = readableLines.indexOfFirst { DATE.containsMatchIn(it) }
        val date = if (dateLine >= 0) DATE.find(readableLines[dateLine])?.let(::toDate) else null
        val total = lines.firstOrNull { it.startsWith(TOTAL_PREFIX) }?.let { ReceiptLine(it).amount }
        val itemsStart = minOf(a = if (dateLine >= 0) dateLine + 1 else 1, b = lines.size)
        val itemsEnd =
            (itemsStart until lines.size).firstOrNull { index ->
                ITEMS_END_PREFIXES.any { prefix -> readableLines[index].startsWith(prefix) }
            } ?: lines.size
        val items =
            ItemReader(isDelivery = readableLines.firstOrNull()?.startsWith(DELIVERY_FIRST_LINE) == true)
                .read(lines = lines.subList(fromIndex = itemsStart, toIndex = itemsEnd).map(::ReceiptLine))
        val hasAddedTax = readableLines.any { line -> ADDED_TAX_MARKS.any { mark -> line.contains(mark) } }
        val store = ReceiptChains.nameIn(readableLines) ?: lines.firstOrNull()
        return ReceiptReading(
            store = ScannedValue(value = store.orEmpty(), confidence = confidenceOf(store)),
            date = ScannedValue(value = date, confidence = confidenceOf(date)),
            total = ScannedValue(value = total, confidence = confidenceOf(total)),
            items = if (hasAddedTax) items + listOfNotNull(addedTax(total = total, items = items)) else items,
        )
    }
}

// Reads item lines, in order, into items (acceptance/fixtures/README.md, Items).
private class ItemReader(
    private val isDelivery: Boolean,
) {
    private val names = mutableListOf<String>()
    private val amounts = mutableListOf<Long>()

    fun read(lines: List<ReceiptLine>): List<ReceiptItem> {
        lines.forEachIndexed { index, line -> read(line = line, above = lines.getOrNull(index = index - 1)) }
        return names.zip(amounts) { name, amount -> itemOf(name = name, amount = amount) }
    }

    private fun read(
        line: ReceiptLine,
        above: ReceiptLine?,
    ) {
        val amount = line.amount
        when {
            line.isQuantity -> if (amount != null) readQuantity(amount = amount, above = above)
            line.isDiscount -> line.discount?.let(::addToLast)
            line.isOption -> amount?.let(::addToLast)
            amount != null -> add(text = line.text, amount = amount)
        }
    }

    // A quantity line gives the amount of the name right above it, or that
    // of the discount right above it; after any other line it is not read.
    private fun readQuantity(
        amount: Long,
        above: ReceiptLine?,
    ) {
        when {
            above == null || above.amount != null -> Unit
            above.isDiscount -> addToLast(amount = -abs(amount))
            else -> add(text = above.text, amount = amount)
        }
    }

    private fun add(
        text: String,
        amount: Long,
    ) {
        names += itemName(text = text, isDelivery = isDelivery)
        amounts += amount
    }

    private fun addToLast(amount: Long) {
        if (amounts.isNotEmpty()) amounts[amounts.lastIndex] += amount
    }
}

// The `消費税` item of prices that exclude tax: what the total adds to the
// items, when it adds something.
internal fun addedTax(
    total: Long?,
    items: List<ReceiptItem>,
): ReceiptItem? {
    val tax = total?.let { it - items.sumOf { item -> item.amount } }
    return if (tax != null && tax > 0L) itemOf(name = ADDED_TAX_NAME, amount = tax) else null
}

// The confidence of a field that is [value]: 0.7 when it was read, 0 when not.
internal fun confidenceOf(value: Any?): Double = if (value != null) RULE_CONFIDENCE else NOT_READ

internal fun itemOf(
    name: String,
    amount: Long,
): ReceiptItem = ReceiptItem(name = name, amount = amount, category = null, confidence = RULE_CONFIDENCE)

// The date of a `yyyy/mm/dd` or `yyyy年mm月dd日` match, or `null` when it is no date.
internal fun toDate(match: MatchResult): LocalDate? {
    // One of the two spellings matched: its year, month and day, in order.
    val parts = match.groupValues.drop(n = 1).filter { it.isNotEmpty() }
    return runCatching {
        val (year, month, day) = parts.map { it.toInt() }
        LocalDate(year = year, month = month, day = day)
    }.getOrNull()
}
