package io.github.mktkhr.moneging.acceptance

import io.github.mktkhr.moneging.data.LocalStore
import kotlinx.coroutines.test.TestResult
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/**
 * AC-B-109 — A ledger's name is trimmed and 1 to 20 characters, when created
 * and when renamed.
 *
 * Given the ledger `家計`, created at 12:00. When a ledger is created with the
 * name `  我が家  `, then it is named `我が家`. When a ledger is created with an
 * empty name, or one of spaces only, or of 21 characters, then it is refused
 * and the ledgers listed are still `家計` and `我が家`. A name of 20
 * characters, one of them the emoji `🏠`, is accepted as it is. When the clock
 * moves to 12:05 and `家計` is renamed ` 家計2026 `, then it is named
 * `家計2026`, its updated instant is 12:05 and its created instant still
 * 12:00; renaming it to a name of spaces only is refused and leaves `家計2026`.
 *
 * Characters are counted as the user sees them (PRODUCT.md §3, Ledger): `🏠`
 * is one character although it is two UTF-16 code units.
 */
class TestLedgerNames {
    /** Names are trimmed and held to 1 to 20 user-perceived characters, on creation and on renaming. */
    @Test
    fun trimsAndBoundsLedgerNames(): TestResult =
        runTest {
            val clock = ManualClock(current = FIXTURE_NOON)
            val store = LocalStore.inMemory(clock = clock, deviceId = FIXTURE_DEVICE_ID)
            val kakei = store.createLedger(name = FIXTURE_LEDGER_NAME)

            val wagaya = store.createLedger(name = "  我が家  ")
            assertEquals(expected = "我が家", actual = wagaya.name, message = "前後の空白が取り除かれない")

            for (refused in listOf("", "   ", TWENTY_ONE_CHARACTERS)) {
                assertFailsWith<IllegalArgumentException>(message = "名前 \"$refused\" の家計簿が作成できてしまう") {
                    store.createLedger(name = refused)
                }
                assertEquals(
                    expected = listOf(FIXTURE_LEDGER_NAME, "我が家"),
                    actual = store.ledgers().map { ledger -> ledger.name },
                    message = "拒否された作成 \"$refused\" で家計簿の一覧が変わった",
                )
            }

            assertEquals(
                expected = 21,
                actual = TWENTY_CHARACTERS_WITH_EMOJI.length,
                message = "前提: 🏠 は UTF-16 で 2 単位",
            )
            val withEmoji = store.createLedger(name = TWENTY_CHARACTERS_WITH_EMOJI)
            assertEquals(
                expected = TWENTY_CHARACTERS_WITH_EMOJI,
                actual = withEmoji.name,
                message = "🏠 を含む 20 文字の名前がそのまま受け入れられない",
            )
            assertEquals(
                expected = listOf(FIXTURE_LEDGER_NAME, "我が家", TWENTY_CHARACTERS_WITH_EMOJI),
                actual = store.ledgers().map { ledger -> ledger.name },
            )

            clock.current = FIXTURE_NOON_PLUS_FIVE
            val renamed = store.renameLedger(id = kakei.id, name = " 家計2026 ")
            assertEquals(expected = "家計2026", actual = renamed.name, message = "名前の変更で前後の空白が取り除かれない")
            assertEquals(expected = kakei.id, actual = renamed.id)
            assertEquals(
                expected = FIXTURE_NOON_PLUS_FIVE,
                actual = renamed.updatedAt,
                message = "名前の変更で更新時刻が 12:05 にならない",
            )
            assertEquals(expected = FIXTURE_NOON, actual = renamed.createdAt, message = "名前の変更で作成時刻が変わった")
            assertEquals(expected = renamed, actual = store.findLedger(id = kakei.id), message = "変更後の名前が保存されていない")

            for (refused in listOf("   ", TWENTY_ONE_CHARACTERS)) {
                assertFailsWith<IllegalArgumentException>(message = "名前 \"$refused\" への変更ができてしまう") {
                    store.renameLedger(id = kakei.id, name = refused)
                }
                assertEquals(
                    expected = renamed,
                    actual = store.findLedger(id = kakei.id),
                    message = "拒否された変更 \"$refused\" で 家計2026 が変わった",
                )
            }
            assertEquals(
                expected = listOf("家計2026", "我が家", TWENTY_CHARACTERS_WITH_EMOJI),
                actual = store.ledgers().map { ledger -> ledger.name },
            )
        }

    private companion object {
        /** 20 user-perceived characters: `🏠` (a surrogate pair) and 19 kana. */
        const val TWENTY_CHARACTERS_WITH_EMOJI = "🏠わがやのかけいぼにっきちょうぶんのいち"

        /** 21 characters, one over the limit. */
        const val TWENTY_ONE_CHARACTERS = "あいうえおかきくけこさしすせそたちつてとな"
    }
}
