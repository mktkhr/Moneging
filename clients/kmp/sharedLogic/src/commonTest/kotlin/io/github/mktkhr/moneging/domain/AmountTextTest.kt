package io.github.mktkhr.moneging.domain

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private const val DISCOUNT = -250L
private const val LUNCH = 1_060L

/** A line item's amount may be a discount below zero; a form keeps its minus while it is typed. */
class AmountTextTest {
    /** A leading minus of any width reads a discount; without one the amount is as before. */
    @Test
    fun signedAmountsReadDiscounts() {
        listOf("-250", "−250", "－２５０", " -250 ").forEach { text ->
            assertEquals(expected = DISCOUNT, actual = AmountText.parseSigned(text), message = text)
        }
        assertEquals(expected = LUNCH, actual = AmountText.parseSigned("1,060"))
        assertFailsWith<IllegalArgumentException> { AmountText.parse("-250") }
        assertFailsWith<IllegalArgumentException> { AmountText.parseSigned("--250") }
    }

    /** Grouping keeps a leading minus. */
    @Test
    fun groupingKeepsTheMinus() {
        assertEquals(expected = "-1,250", actual = AmountText.grouped("-1250"))
        assertEquals(expected = "1,250", actual = AmountText.grouped("1250"))
    }
}
