package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.DraftItem
import io.github.mktkhr.moneging.scan.ScannedValue
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.time.Instant
import kotlin.uuid.Uuid

private val FOOD = Uuid.random()
private val OTHER = Uuid.random()
private val EPOCH = Instant.fromEpochSeconds(epochSeconds = 0L)

// A draft of total 980 with the items 680 and 150, both in 食費.
internal fun deliDraft(): Draft =
    Draft(
        id = Uuid.random(),
        ledgerId = Uuid.random(),
        photoId = Uuid.random(),
        store = ScannedValue(value = "コーナーデリ", confidence = 1.0),
        date = ScannedValue(value = LocalDate(year = 2026, month = 2, day = 13), confidence = 1.0),
        total = ScannedValue(value = 980L, confidence = 1.0),
        categoryId = null,
        items =
            listOf(
                DraftItem(name = "唐揚げ弁当", amount = 680L, categoryId = FOOD, confidence = 1.0),
                DraftItem(name = "緑茶", amount = 150L, categoryId = FOOD, confidence = 1.0),
            ),
        createdAt = EPOCH,
        updatedAt = EPOCH,
    )

/** The `差額` item a confirmed draft gains takes the items' one category only while it is active. */
class DraftConfirmTest {
    /** Every item in the active 食費: the difference is in 食費. */
    @Test
    fun differenceInActiveCategory() {
        val confirmed = deliDraft().toNewTransaction(other = OTHER, acceptMismatch = true, isActive = { true })

        assertEquals(expected = FOOD, actual = confirmed.items.last().categoryId)
    }

    /** Every item in an archived category: the difference is in その他. */
    @Test
    fun differenceOfArchivedIsOther() {
        val confirmed = deliDraft().toNewTransaction(other = OTHER, acceptMismatch = true, isActive = { false })

        assertEquals(expected = OTHER, actual = confirmed.items.last().categoryId)
    }
}
