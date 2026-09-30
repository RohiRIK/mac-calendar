import Foundation

public struct Holiday: Hashable, Sendable {
    public let date: Date
    public let name: String
}

/// Hebrew dates in Hebrew letters and Israeli holidays, computed from Foundation's Hebrew calendar
/// (offline, no permission). Months are numbered 1 (Tishri) … 13 (Elul) every year; 7 is always
/// the Adar that holds Purim (Adar II in a leap year).
public enum HebrewDates {
    /// Day of the Hebrew month in gematria, e.g. "י״ט".
    public static func dayLabel(_ date: Date, calendar: Calendar = .current) -> String {
        format(date, "d", calendar)
    }

    /// Full Hebrew date, e.g. "י״ט תשרי ה׳תשפ״ז".
    public static func fullLabel(_ date: Date, calendar: Calendar = .current) -> String {
        format(date, "d MMMM yyyy", calendar)
    }

    /// Israeli holidays (and observed days of the moved memorial days) in `start ..< end`, at
    /// midnight in `calendar`'s time zone.
    public static func holidays(from start: Date, to end: Date, calendar: Calendar = .current) -> [Holiday] {
        let hebrew = hebrewCalendar(calendar)
        let years = hebrew.component(.year, from: start)...hebrew.component(.year, from: end)
        return years.flatMap { holidays(year: $0, hebrew: hebrew, calendar: calendar) }
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
    }

    private static func holidays(year: Int, hebrew: Calendar, calendar: Calendar) -> [Holiday] {
        func day(_ month: Int, _ day: Int) -> Date? {
            hebrew.date(from: DateComponents(year: year, month: month, day: day))
        }
        func shift(_ date: Date?, _ days: Int) -> Date? {
            date.flatMap { calendar.date(byAdding: .day, value: days, to: $0) }
        }
        /// Days to move a date by, keyed by its weekday (1 = Sunday … 7 = Saturday).
        func moved(_ date: Date?, _ rules: [Int: Int]) -> Date? {
            date.flatMap { shift($0, rules[calendar.component(.weekday, from: $0)] ?? 0) }
        }

        let independence = moved(day(9, 5), [6: -1, 7: -2, 2: 1])  // Fri/Sat → Thu, Mon → Tue
        var list: [(Date?, String)] = [
            (day(1, 1), "Rosh Hashana"), (day(1, 2), "Rosh Hashana"), (day(1, 10), "Yom Kippur"),
            (day(1, 15), "Sukkot"), (day(1, 21), "Hoshana Raba"), (day(1, 22), "Simchat Torah"),
            (day(5, 15), "Tu BiShvat"), (day(7, 14), "Purim"),
            (day(8, 15), "Pesach"), (day(8, 21), "Pesach VII"),
            (moved(day(8, 27), [6: -1, 1: 1]), "Yom HaShoah"),  // Fri → Thu, Sun → Mon
            (shift(independence, -1), "Yom HaZikaron"), (independence, "Yom HaAtzmaut"),
            (day(9, 18), "Lag BaOmer"), (day(9, 28), "Yom Yerushalayim"), (day(10, 6), "Shavuot"),
            (moved(day(12, 9), [7: 1]), "Tisha B'Av"),  // Sat → Sun
        ]
        list += (16...20).map { (day(1, $0), "Sukkot (Chol HaMoed)") }
        list += (16...20).map { (day(8, $0), "Pesach (Chol HaMoed)") }
        list += (0..<8).map { (shift(day(3, 25), $0), "Hanukkah") }  // 25 Kislev, eight days
        return list.compactMap { date, name in date.map { Holiday(date: $0, name: name) } }
    }

    private static func hebrewCalendar(_ calendar: Calendar) -> Calendar {
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = calendar.timeZone
        return hebrew
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = hebrewCalendar(calendar)
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "he@numbers=hebr")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
