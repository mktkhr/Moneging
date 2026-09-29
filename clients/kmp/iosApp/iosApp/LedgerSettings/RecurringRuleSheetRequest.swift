/// What the rule sheet of 毎月の定期 is opened for.
internal enum RecurringRuleSheetRequest: Hashable, Identifiable {
    /// Adding a rule.
    case add
    /// Changing the rule with this `RecurringRule.id` (as text).
    case change(String)

    /// Identifies the sheet for `sheet(item:)`.
    internal var id: String {
        switch self {
        case .add:
            "add"

        case .change(let ruleId):
            "change-\(ruleId)"
        }
    }

    /// The rule changed, or `nil` when adding one.
    internal var ruleId: String? {
        switch self {
        case .add:
            nil

        case .change(let ruleId):
            ruleId
        }
    }
}
