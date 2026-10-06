package io.github.mktkhr.moneging.state

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

private const val FOOD = "food"
private const val DRINK = "drink"
private const val BENTO = "唐揚げ弁当"
private const val TEA = "緑茶"

internal fun mismatchItem(
    name: String,
    amount: String,
    categoryId: String? = FOOD,
): DraftItemForm = DraftItemForm(name = name, amountText = amount, categoryId = categoryId, confidence = 1.0)

internal fun mismatchForm(
    total: String,
    items: List<DraftItemForm>,
): DraftForm =
    DraftForm(
        store = "コーナーデリ",
        storeConfidence = 1.0,
        date = "2026-02-13",
        dateConfidence = 1.0,
        totalText = total,
        totalConfidence = 1.0,
        categoryId = null,
        items = items,
    )

/** `DraftForm.mismatch` words the warning, the fixes and the question of a draft whose items do not add up. */
class DraftMismatchTest {
    /** Below the total: the difference can be added, in the items' one category. */
    @Test
    fun belowOffersTheDifference() {
        val mismatch =
            assertNotNull(
                mismatchForm(
                    total = "980",
                    items =
                        listOf(
                            mismatchItem(name = BENTO, amount = "680"),
                            mismatchItem(name = TEA, amount = "150"),
                        ),
                ).mismatch(),
            )

        assertEquals(expected = "明細の合計 830円 が合計 980円 と 150円 合いません。", actual = mismatch.warningText)
        assertEquals(expected = "830円", actual = mismatch.itemsSumText)
        assertEquals(expected = "差額 150円 を明細に足す", actual = mismatch.addDifferenceText)
        assertEquals(expected = "明細を消して、合計 980円 だけで記録する", actual = mismatch.totalOnlyText)
        assertEquals(
            expected = DraftItemForm(name = "差額", amountText = "150", categoryId = FOOD, confidence = 1.0),
            actual = mismatch.differenceItem,
        )
        assertEquals(
            expected =
                "明細の合計 830円 と合計 980円 が 150円 違います。このまま記録すると、" +
                    "差額 150円 を「差額」の明細として足し、要確認の印を付けます。あとで写真を見ながら直せます。",
            actual = mismatch.questionMessage,
        )
    }

    /** Items of different categories: the difference has none (その他). */
    @Test
    fun mixedLeaveNoCategory() {
        val mismatch =
            assertNotNull(
                mismatchForm(
                    total = "980",
                    items =
                        listOf(
                            mismatchItem(name = BENTO, amount = "680"),
                            mismatchItem(name = TEA, amount = "150", categoryId = DRINK),
                        ),
                ).mismatch(),
            )

        assertNull(assertNotNull(mismatch.differenceItem).categoryId)
    }

    /** Above the total: only the total alone is offered, and the question says the sum is recorded. */
    @Test
    fun aboveOffersTotalOnly() {
        val mismatch =
            assertNotNull(
                mismatchForm(
                    total = "800",
                    items =
                        listOf(
                            mismatchItem(name = BENTO, amount = "680"),
                            mismatchItem(name = TEA, amount = "150"),
                        ),
                ).mismatch(),
            )

        assertEquals(expected = "明細の合計 830円 が合計 800円 と 30円 合いません。", actual = mismatch.warningText)
        assertNull(mismatch.addDifferenceText)
        assertNull(mismatch.differenceItem)
        assertEquals(
            expected = "明細の合計 830円 と合計 800円 が 30円 違います。このまま記録すると、明細の合計 830円 で記録し、要確認の印を付けます。",
            actual = mismatch.questionMessage,
        )
    }

    /** Items that add up (a discount included), no items, or an amount not yet valid: no warning. */
    @Test
    fun noWarningOtherwise() {
        assertNull(
            mismatchForm(
                total = "830",
                items =
                    listOf(
                        mismatchItem(name = BENTO, amount = "1,080"),
                        mismatchItem(name = "割引", amount = "-250"),
                    ),
            ).mismatch(),
        )
        assertNull(mismatchForm(total = "980", items = emptyList()).mismatch())
        assertNull(mismatchForm(total = "980", items = listOf(mismatchItem(name = BENTO, amount = ""))).mismatch())
        assertNull(mismatchForm(total = "", items = listOf(mismatchItem(name = BENTO, amount = "680"))).mismatch())
    }
}
