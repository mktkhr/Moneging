import Foundation

/// Converts between a `Date` a date picker holds and the ISO calendar date
/// (`2026-02-15`) the shared logic reads, in the product's time zone
/// (Asia/Tokyo), whatever the device's.
internal enum IsoDate {
    /// The product's time zone.
    internal static let timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    /// The product's locale: Japanese, whatever the device's language.
    internal static let locale: Locale = Locale(identifier: "ja_JP")

    /// The product's calendar: Gregorian, in Asia/Tokyo.
    internal static let calendar: Calendar = {
        var built: Calendar = Calendar(identifier: .gregorian)
        built.timeZone = Self.timeZone
        built.locale = Self.locale
        return built
    }()

    // `yyyy-MM-dd` in Asia/Tokyo.
    private static let style: Date.ISO8601FormatStyle = Date.ISO8601FormatStyle(
        timeZone: Self.timeZone
    )
    .year()
    .month()
    .day()
    .dateSeparator(.dash)

    /// The day of `date` in Asia/Tokyo with its year, in Japanese
    /// (`2026年2月14日`), whatever the device's language.
    internal static func longText(from date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .long,
                time: .omitted,
                locale: Self.locale,
                calendar: Self.calendar,
                timeZone: Self.timeZone,
            ),
        )
    }

    /// The start of the day `iso` (`2026-02-15`) in Asia/Tokyo; now when
    /// `iso` is not a date.
    internal static func date(fromIso iso: String) -> Date {
        (try? Date(iso, strategy: Self.style)) ?? Date()
    }

    /// The day of `date` in Asia/Tokyo, ISO (`2026-02-15`).
    internal static func iso(from date: Date) -> String {
        date.formatted(Self.style)
    }
}
