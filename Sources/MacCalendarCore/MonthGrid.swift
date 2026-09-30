import Foundation

/// One cell of the month grid.
public struct CalendarDay: Hashable, Sendable, Identifiable {
    public let date: Date
    public let day: Int
    public let inMonth: Bool
    public let isToday: Bool
    public var id: Date { date }
}

public enum MonthGrid {
    /// Six full weeks (42 days) covering the month that contains `month`, starting on the
    /// calendar's first weekday. A fixed size keeps the panel height constant between months.
    public static func days(month: Date, today: Date = .now, calendar: Calendar = .current) -> [CalendarDay] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -lead, to: first) else { return [] }
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return CalendarDay(
                date: date,
                day: calendar.component(.day, from: date),
                // Not `interval.contains`: DateInterval is closed, so it would include next month's 1st.
                inMonth: date >= interval.start && date < interval.end,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    /// The seven days of the week that contains `date`, starting on the calendar's first weekday.
    public static func week(containing date: Date, today: Date = .now, calendar: Calendar = .current) -> [CalendarDay] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return CalendarDay(date: day, day: calendar.component(.day, from: day), inMonth: true,
                               isToday: calendar.isDate(day, inSameDayAs: today))
        }
    }

    /// `days` without trailing weeks that hold no in-month day.
    public static func trimmingEmptyWeeks(_ days: [CalendarDay]) -> [CalendarDay] {
        var result = days
        while result.count >= 7, !result.suffix(7).contains(where: \.inMonth) { result.removeLast(7) }
        return result
    }

    /// Week of year for each row of `days` (one per 7 cells), using the calendar's own week rules.
    public static func weekNumbers(days: [CalendarDay], calendar: Calendar = .current) -> [Int] {
        stride(from: 0, to: days.count, by: 7).map { calendar.component(.weekOfYear, from: days[$0].date) }
    }

    /// Single-letter weekday names in grid order ("S M T W T F S" or "M T W T F S S").
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
