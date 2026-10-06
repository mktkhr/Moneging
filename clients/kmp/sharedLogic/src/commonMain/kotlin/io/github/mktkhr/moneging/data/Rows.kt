package io.github.mktkhr.moneging.data

import io.github.mktkhr.moneging.data.db.Budgets
import io.github.mktkhr.moneging.data.db.Categories
import io.github.mktkhr.moneging.data.db.Draft_items
import io.github.mktkhr.moneging.data.db.Drafts
import io.github.mktkhr.moneging.data.db.Ledgers
import io.github.mktkhr.moneging.data.db.Line_items
import io.github.mktkhr.moneging.data.db.Photos
import io.github.mktkhr.moneging.data.db.Recurring_rules
import io.github.mktkhr.moneging.data.db.Scan_jobs
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
import io.github.mktkhr.moneging.scan.Draft
import io.github.mktkhr.moneging.scan.DraftItem
import io.github.mktkhr.moneging.scan.ReadingMethod
import io.github.mktkhr.moneging.scan.ScanJob
import io.github.mktkhr.moneging.scan.ScanState
import io.github.mktkhr.moneging.scan.ScannedValue
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
        isReviewNeeded = needs_review.toBoolean(),
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
        isRemoved = is_removed.toBoolean(),
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

internal fun Scan_jobs.toDomain(): ScanJob =
    ScanJob(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        photoId = photo_id.toUuid(),
        state = ScanState.valueOf(state),
        draftId = draft_id?.toUuid(),
        failureReason = failure_reason,
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
        method = readingMethodOf(method),
    )

internal fun Drafts.toDomain(items: List<DraftItem>): Draft =
    Draft(
        id = id.toUuid(),
        ledgerId = ledger_id.toUuid(),
        photoId = photo_id.toUuid(),
        store = ScannedValue(value = store, confidence = store_confidence),
        date = ScannedValue(value = LocalDate.parse(date), confidence = date_confidence),
        total = ScannedValue(value = total, confidence = total_confidence),
        categoryId = category_id?.toUuid(),
        items = items,
        createdAt = created_at.toInstant(),
        updatedAt = updated_at.toInstant(),
        method = readingMethodOf(method),
    )

// The reading method stored as [name], or `null` for none (or one unknown).
private fun readingMethodOf(name: String?): ReadingMethod? = ReadingMethod.entries.firstOrNull { it.name == name }

internal fun Draft_items.toDomain(): DraftItem =
    DraftItem(name = name, amount = amount, categoryId = category_id?.toUuid(), confidence = confidence)
