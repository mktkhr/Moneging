import XCTest

/// A row seen while scrolling through a list: its identifier and its
/// accessibility label when it was first seen.
internal struct ScrolledRow: Equatable {
    /// The row's accessibility identifier.
    internal let identifier: String

    /// The row's accessibility label.
    internal let label: String
}

/// Scrolling that does not depend on a list fitting on screen (large
/// accessibility text sizes, small devices).
///
/// The tests scroll with short drags that end in a hold, so the content moves
/// less than a screen and never flings: no row can pass by unseen. A drag
/// towards earlier content is made only on full screens (home, 設定 and the
/// screens pushed from it), never in a sheet, where it could dismiss the
/// sheet; a sheet opens scrolled to its top, so its rows are reached by
/// dragging towards later content only.
extension XCUIApplication {
    /// The most drags made in one direction before giving up.
    private static let maxDrags: Int = 20

    /// Drags in a row that reveal nothing new before a walk concludes that
    /// it reached the end.
    private static let dragsAtEnd: Int = 2

    /// Seconds given to an element to appear before the first drag.
    private static let revealFirstWait: TimeInterval = 2

    /// Where a drag starts and ends, as fractions of the screen's height.
    private static let dragLowerY: CGFloat = 0.7
    private static let dragUpperY: CGFloat = 0.35
    private static let dragX: CGFloat = 0.5

    /// Seconds a drag presses before moving and holds after, so it does not
    /// fling.
    private static let dragPress: TimeInterval = 0.05
    private static let dragHold: TimeInterval = 0.2

    /// The elements of `query` that exist now, top to bottom.
    private static func onScreenOrder(_ query: XCUIElementQuery) -> [XCUIElement] {
        query.allElementsBoundByIndex
            .filter(\.exists)
            .sorted { upper, lower in upper.frame.minY < lower.frame.minY }
    }

    /// Whether `element` is on screen and hittable, dragging to it as
    /// needed.
    ///
    /// Drags first towards later content, then back towards earlier
    /// content. Full screens only (not in a sheet).
    internal func reveal(_ element: XCUIElement) -> Bool {
        self.reveal(element, laterFirst: true)
    }

    /// Whether `element`, near the top of the list, is on screen and
    /// hittable, dragging to it as needed.
    ///
    /// Drags first towards earlier content, then towards later content.
    /// Full screens only (not in a sheet).
    internal func revealNearTop(_ element: XCUIElement) -> Bool {
        self.reveal(element, laterFirst: false)
    }

    /// Whether `element` is on screen and hittable in the sheet shown,
    /// dragging towards later content only.
    internal func revealInSheet(_ element: XCUIElement) -> Bool {
        if element.waitForExistence(timeout: Self.revealFirstWait), element.isHittable {
            return true
        }
        return self.drag(towardLater: true, until: element)
    }

    /// Every element of `query` in the list on screen, in list order.
    ///
    /// Each comes with the label it had when first seen. Scrolls to the
    /// list's top first. Full screens only.
    internal func collectRows(_ query: XCUIElementQuery) -> [ScrolledRow] {
        self.scrollToTop(of: query)
        return self.walkDown(query)
    }

    /// Every element of `query` in the sheet shown, in order, walking down
    /// from where the sheet is (its top when it has just opened).
    internal func collectRowsInSheet(_ query: XCUIElementQuery) -> [ScrolledRow] {
        self.walkDown(query)
    }

    /// Drags towards later content, collecting the elements of `query` in
    /// on-screen order, until a few drags reveal nothing new.
    private func walkDown(_ query: XCUIElementQuery) -> [ScrolledRow] {
        var rows: [ScrolledRow] = []
        var idleDrags: Int = 0
        for _ in 0..<Self.maxDrags {
            let before: Int = rows.count
            let seen: Set<String> = Set(rows.map(\.identifier))
            for element in Self.onScreenOrder(query) where !seen.contains(element.identifier) {
                rows.append(ScrolledRow(identifier: element.identifier, label: element.label))
            }
            idleDrags = rows.count == before ? idleDrags + 1 : 0
            if idleDrags >= Self.dragsAtEnd {
                break
            }
            self.dragOnce(towardLater: true)
        }
        return rows
    }

    /// Drags towards earlier content until the first element of `query` on
    /// screen stops changing.
    private func scrollToTop(of query: XCUIElementQuery) {
        var first: String? = Self.onScreenOrder(query).first?.identifier
        for _ in 0..<Self.maxDrags {
            self.dragOnce(towardLater: false)
            let now: String? = Self.onScreenOrder(query).first?.identifier
            if now == first {
                break
            }
            first = now
        }
    }

    /// Whether `element` is on screen and hittable, dragging to it first in
    /// one direction, then in the other.
    private func reveal(_ element: XCUIElement, laterFirst: Bool) -> Bool {
        if element.waitForExistence(timeout: Self.revealFirstWait), element.isHittable {
            return true
        }
        return self.drag(towardLater: laterFirst, until: element)
            || self.drag(towardLater: !laterFirst, until: element)
    }

    /// Drags in one direction until `element` exists and is hittable.
    private func drag(towardLater: Bool, until element: XCUIElement) -> Bool {
        for _ in 0..<Self.maxDrags {
            self.dragOnce(towardLater: towardLater)
            if element.exists, element.isHittable {
                return true
            }
        }
        return false
    }

    /// One short drag without momentum: upwards brings later content into
    /// view, downwards earlier content.
    private func dragOnce(towardLater: Bool) {
        let lower: XCUICoordinate = self.coordinate(
            withNormalizedOffset: CGVector(dx: Self.dragX, dy: Self.dragLowerY)
        )
        let upper: XCUICoordinate = self.coordinate(
            withNormalizedOffset: CGVector(dx: Self.dragX, dy: Self.dragUpperY)
        )
        let start: XCUICoordinate = towardLater ? lower : upper
        let end: XCUICoordinate = towardLater ? upper : lower
        start.press(
            forDuration: Self.dragPress,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: Self.dragHold
        )
    }
}
