import Foundation

struct UsageWindow: Equatable, Sendable {
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    var remainingPercent: Int {
        min(100, max(0, 100 - usedPercent))
    }

    var title: String {
        switch windowDurationMinutes {
        case 300: "5 hours"
        case 10_080: "7 days"
        case let minutes?: "\(minutes) minutes"
        case nil: "Usage"
        }
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
