import SharedLogic
import SwiftUI

/// The form of 下書きを確認 (`Draft5.dc.html`) inside `DraftSheet`.
///
/// The receipt's photo, small; 店名, 日付 and 合計 (`DraftFieldsCard`); the
/// items, each removable (`DraftItemRow`), with items addable, or, without
/// items, one カテゴリ for the whole expense; and discarding the draft.
internal struct DraftContent: View {
    private static let card: RoundedRectangle = RoundedRectangle(
        cornerRadius: Theme.Scanning.cardRadius,
    )

    internal let form: Binding<DraftFormState>
    internal let photoId: String?
    internal let categories: [SharedLogic.Category]
    internal let onDiscard: () -> Void

    internal var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if let photoId = self.photoId {
                ReceiptPhotoLink(
                    photoId: photoId,
                    width: Theme.Scanning.draftThumbnailWidth,
                    height: Theme.Scanning.draftThumbnailHeight,
                    note: String(localized: "要確認 の欄は、読み取りに自信がない所です。"),
                )
                .padding(.top, Theme.Spacing.medium)
            }
            DraftFieldsCard(form: self.form)
            if self.form.wrappedValue.items.isEmpty {
                self.wholeCategory
            } else {
                self.items
            }
            self.addItemButton
            self.discardButton
        }
    }

    private var itemsHeader: String {
        let count: Int = self.form.wrappedValue.items.count
        let total: String = Formats.shared.yen(amount: self.form.wrappedValue.itemsTotal)
        return String(localized: "明細 \(count)件（合計 \(total)）")
    }

    private var items: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text(self.itemsHeader)
                .font(.footnote)
                .foregroundStyle(Theme.mutedText)
            VStack(spacing: 0) {
                ForEach(Array(self.form.items.enumerated()), id: \.element.id) { index, item in
                    DraftItemRow(item: item, index: index, categories: self.categories) {
                        self.form.wrappedValue.items.removeAll { $0.id == item.wrappedValue.id }
                    }
                    if index < self.form.wrappedValue.items.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Theme.surface, in: Self.card)
        }
    }

    // The category of a draft without items: its whole expense's.
    private var wholeCategory: some View {
        DraftCategoryMenu(
            selection: self.form.categoryId,
            categories: self.categories,
            identifier: "draft-category",
        )
        .padding(.horizontal, Theme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: Self.card)
    }

    private var addItemButton: some View {
        Button {
            self.form.wrappedValue.items.append(DraftItemState.added())
        } label: {
            Label("明細を足す", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .strokeBorder(
                            Theme.line,
                            style: StrokeStyle(
                                lineWidth: Theme.dashedBorderLineWidth,
                                dash: [Theme.dashedBorderDashLength, Theme.dashedBorderGapLength],
                            ),
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draft-item-add")
    }

    private var discardButton: some View {
        Button(role: .destructive, action: self.onDiscard) {
            Text("この下書きを捨てる")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.Scanning.review)
                .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("draft-discard")
    }
}
