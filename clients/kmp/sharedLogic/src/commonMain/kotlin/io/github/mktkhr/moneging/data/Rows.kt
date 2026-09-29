package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.data.db.Budgets
import io.github.mktkhr.moneging.data.db.Categories
import io.github.mktkhr.moneging.data.db.Ledgers
import io.github.mktkhr.moneging.data.db.Line_items
import io.github.mktkhr.moneging.data.db.Photos
import io.github.mktkhr.moneging.data.db.Recurring_rules
import io.github.mktkhr.moneging.data.db.Transactions
import io.github.mktkhr.moneging.domain.Budget
import io.github.mktkhr.moneging.domain.BusinessDayAdjustment
import io.github.mktkhr.moneging.domain.Category
import io.github.mktkhr.moneging.domain.Direction
import io.github.mktkhr.moneging.domain.Ledger
import io.github.mktkhr.moneging.domain.LineItem
import io.github.mktkhr.moneging.domain.Photo
import io.github.mktkhr.moneging.domain.RecurringRule
import io.github.mktkhr.moneging.domain.Transaction
import kotlinx.datetime.LocalDate
import kotlinx.datetime.YearMonth

// The database's rows (SQLDelight's generated types, primitive columns) as
// domain records; the column conversions are in Columns.kt.

internal fun Ledgers.toDomain(): Ledger =
    Ledger(
        id = id.toUuid(),
        name = name,
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )

internal fun Categories.toDomain(): Category =
    Category(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        name = name,
        isArchived = archived.toBoolean(),
        defaultIndex = position.toInt().takeIf { it < DEFAULT_CATEGORY_NAMES.size },
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )

internal fun Photos.toDomain(): Photo =
    Photo(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        contentType = content_type,
        sizeBytes = size_bytes,
        capturedAt = captured_at.toInstant(),
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )

internal fun Line_items.toDomain(): LineItem =
    LineItem(
        id = id.toUuid(),
        amount = amount,
        categoryId = category_id.toUuid(),
        name = name,
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )

internal fun Transactions.toDomain(items: List<LineItem>): Transaction =
    Transaction(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        date = LocalDate.parse(date),
        direction = Direction.valueOf(direction),
        amount = amount,
        categoryId = category_id?.toUuid(),
        memo = memo,
        storeName = store_name,
        photoId = photo_id?.toUuid(),
        items = items,
        deviceId = device_id,
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
        recurringRuleId = recurring_rule_id?.toUuid(),
        recurringMonth = recurring_month?.let { YearMonth.parse(it) },
    )

internal fun Budgets.toDomain(): Budget =
    Budget(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        categoryId = category_id?.toUuid(),
        amount = amount,
        fromMonth = YearMonth.parse(from_month),
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )

internal fun Recurring_rules.toDomain(): RecurringRule =
    RecurringRule(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        direction = Direction.valueOf(direction),
        amount = amount,
        categoryId = category_id?.toUuid(),
        dayOfMonth = day_of_month?.toInt(),
        startMonth = YearMonth.parse(start_month),
        endMonth = end_month?.let { YearMonth.parse(it) },
        memo = memo,
        adjustment = BusinessDayAdjustment.valueOf(adjustment),
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
    )
