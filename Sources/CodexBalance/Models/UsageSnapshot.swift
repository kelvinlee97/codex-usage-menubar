import Foundation

struct UsageWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    /// Rounded for display, but never rounds *to* an endpoint: "0% left" means the window is
    /// genuinely exhausted and "100%" means it is untouched.
    var remainingPercent: Int {
        let remaining = 100 - usedPercent
        if remaining <= 0 { return 0 }
        if remaining >= 100 { return 100 }
        return min(99, max(1, Int(remaining.rounded())))
    }

    var title: String {
        switch windowDurationMinutes {
        case 300: "5 hours"
        case 10_080: "7 days"
        case let minutes?: "\(minutes) minutes"
        case nil: "Usage"
        }
    }

    /// True once a snapshot's reset time has passed; the data is awaiting a refresh.
    func hasReset(asOf now: Date = Date()) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt <= now
    }
}

struct UsageSnapshot: Equatable, Sendable {
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let creditBalance: String?
    let updatedAt: Date

    var formattedCreditBalance: String? {
        guard
            let creditBalance,
            let value = Decimal(string: creditBalance, locale: Locale(identifier: "en_US_POSIX"))
        else { return creditBalance }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
