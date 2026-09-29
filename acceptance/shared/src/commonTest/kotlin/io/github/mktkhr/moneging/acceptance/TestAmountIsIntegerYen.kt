package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.domain.AmountText
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.NewTransaction
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

private const val NEGATIVE_AMOUNT = -100L

/**
 * AC-B-202 — An amount is an integer number of yen and at least one yen.
 *
 * Given the category 食費. When a transaction is created with amount `0` or
 * `-100`, then each is refused as invalid. When the form's amount text `1.5`
 * or `1200円` is read as an amount, then it is refused as invalid. When it is
 * created with `1`, then it is accepted and reads back as `1`.
 *
 * The form's text is read by the shared [AmountText.parse], so every client
 * reads it the same way.
 */
class TestAmountIsIntegerYen {
    /** Amounts below 1 yen and amount texts that are not a whole number of yen are refused; 1 yen is accepted. */
    @Test
    fun amountIsIntegerYenOfAtLeastOne(): TestResult =
        runTest {
            val scope = kakeiScope()
            val food = scope.categoryIdNamed(name = "食費")
            val date = LocalDate.parse("2026-02-15")

            for (refused in listOf(0L, NEGATIVE_AMOUNT)) {
                assertFailsWith<IllegalArgumentException>(message = "金額 $refused の取引が作成できてしまう") {
                    scope.recordTransaction(
                        transaction =
                            NewTransaction(
                                date = date,
                                direction = Direction.EXPENSE,
                                amount = refused,
                                categoryId = food,
                            ),
                    )
                }
            }
            assertEquals(
                expected = emptyList(),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.amount },
                message = "拒否された金額の取引が残った",
            )

            for (refusedText in listOf("1.5", "1200円")) {
                assertFailsWith<IllegalArgumentException>(message = "金額の入力 \"$refusedText\" が金額として読めてしまう") {
                    AmountText.parse(text = refusedText)
                }
            }

            val oneYen = AmountText.parse(text = "1")
            assertEquals(expected = 1L, actual = oneYen, message = "金額の入力 \"1\" が 1円 と読めない")
            val created =
                scope.recordTransaction(
                    transaction =
                        NewTransaction(
                            date = date,
                            direction = Direction.EXPENSE,
                            amount = oneYen,
                            categoryId = food,
                        ),
                )
            assertEquals(expected = 1L, actual = created.amount)
            assertEquals(
                expected = 1L,
                actual = scope.findTransaction(id = created.id)?.amount,
                message = "1円 の取引が 1 と読み戻せない",
            )
            assertEquals(
                expected = listOf(created.id),
                actual = scope.transactions(month = FIXTURE_FEBRUARY).map { listed -> listed.id },
            )
        }
}
