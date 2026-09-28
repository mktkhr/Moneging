import CoreFoundation

extension Theme {
    /// The shell's one spacing scale, named by step rather than by value.
    ///
    /// takamai's own `tokens.ts` has no generic spacing scale (only the
    /// shape tokens above); every padding/spacing/inset in this shell picks
    /// one of these steps, so there is exactly one place that decides "how
    /// much space" anywhere in the shell, and the design's in-between
    /// values (e.g. 10/14pt) snap to the nearest step rather than growing
    /// the scale.
    internal enum Spacing {
        /// Tightest step: between lines of one text block (a title and its subtitle).
        internal static let extraExtraSmall: CGFloat = 2
        /// Between an element and its own inline accessory (a label and its chevron).
        internal static let extraSmall: CGFloat = 4
        /// Between sibling items of one list/group.
        internal static let small: CGFloat = 8
        /// Between a heading and its group, and inside a row/card.
        internal static let medium: CGFloat = 12
        /// A screen's own edge margins, and a floating control's gap from its surroundings.
        internal static let large: CGFloat = 16
        /// A sheet's own content margin.
        internal static let extraLarge: CGFloat = 20
    }
}
