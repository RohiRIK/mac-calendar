import Foundation
import Testing
@testable import MacCalendarCore

private func calendar(firstWeekday: Int) -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    cal.firstWeekday = firstWeekday
    return cal
}

private func date(_ y: Int, _ m: Int, _ d: Int, _ cal: Calendar) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d))!
}

@Test func alwaysSixWeeks() {
    let cal = calendar(firstWeekday: 1)
    for month in 1...12 {
        #expect(MonthGrid.days(month: date(2026, month, 1, cal), today: .distantPast, calendar: cal).count == 42)
    }
}

@Test func sundayStartSeptember2026() {
    // 1 Sep 2026 is a Tuesday: two leading August days (30, 31).
    let cal = calendar(firstWeekday: 1)
    let days = MonthGrid.days(month: date(2026, 9, 15, cal), today: .distantPast, calendar: cal)
    #expect(days.prefix(3).map(\.day) == [30, 31, 1])
    #expect(days.prefix(2).allSatisfy { !$0.inMonth })
    #expect(days[2].inMonth)
    #expect(days.filter(\.inMonth).count == 30)
    #expect(days.last?.day == 10) // trailing October days fill to 42
}

@Test func mondayStartSeptember2026() {
    let cal = calendar(firstWeekday: 2)
    let days = MonthGrid.days(month: date(2026, 9, 1, cal), today: .distantPast, calendar: cal)
    #expect(days.prefix(2).map(\.day) == [31, 1])
}

@Test func monthStartingOnFirstWeekdayHasNoLeadingDays() {
    // 1 Feb 2026 is a Sunday.
    let cal = calendar(firstWeekday: 1)
    let days = MonthGrid.days(month: date(2026, 2, 10, cal), today: .distantPast, calendar: cal)
    #expect(days[0].day == 1 && days[0].inMonth)
    #expect(days.filter(\.inMonth).count == 28)
}

@Test func leapFebruary() {
    let cal = calendar(firstWeekday: 1)
    let days = MonthGrid.days(month: date(2028, 2, 1, cal), today: .distantPast, calendar: cal)
    #expect(days.filter(\.inMonth).count == 29)
}

@Test func marksTodayOnly() {
    let cal = calendar(firstWeekday: 1)
    let today = date(2026, 9, 29, cal).addingTimeInterval(15 * 3600) // afternoon, same day
    let days = MonthGrid.days(month: today, today: today, calendar: cal)
    #expect(days.filter(\.isToday).map(\.day) == [29])
}

@Test func weekdaySymbolsFollowFirstWeekday() {
    var cal = calendar(firstWeekday: 2)
    cal.locale = Locale(identifier: "en_US")
    #expect(MonthGrid.weekdaySymbols(calendar: cal).first == "M")
    #expect(MonthGrid.weekdaySymbols(calendar: cal).count == 7)
}

@Test func isoWeekNumbersPerRow() {
    // ISO 8601: Monday start. September 2026 grid starts Mon 31 Aug = week 36.
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let days = MonthGrid.days(month: date(2026, 9, 1, cal), today: .distantPast, calendar: cal)
    #expect(MonthGrid.weekNumbers(days: days, calendar: cal) == [36, 37, 38, 39, 40, 41])
}

@Test func weekNumbersWrapAtYearEnd() {
    // January 2027 (ISO): grid starts Mon 28 Dec 2026 = week 53 of 2026, then week 1.
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let days = MonthGrid.days(month: date(2027, 1, 1, cal), today: .distantPast, calendar: cal)
    #expect(MonthGrid.weekNumbers(days: days, calendar: cal).prefix(2) == [53, 1])
}

@Test func weekContainingDate() {
    // Wed 30 Sep 2026, Sunday start: 27 Sep … 3 Oct.
    let cal = calendar(firstWeekday: 1)
    let days = MonthGrid.week(containing: date(2026, 9, 30, cal), today: date(2026, 9, 30, cal), calendar: cal)
    #expect(days.map(\.day) == [27, 28, 29, 30, 1, 2, 3])
    #expect(days.allSatisfy { $0.inMonth })
    #expect(days.filter(\.isToday).map(\.day) == [30])
}

@Test func trimsEmptyTrailingWeeks() {
    // September 2026, Sunday start, fills five weeks; February 2026 fills exactly four.
    let cal = calendar(firstWeekday: 1)
    #expect(MonthGrid.trimmingEmptyWeeks(MonthGrid.days(month: date(2026, 9, 1, cal), today: .distantPast, calendar: cal)).count == 35)
    #expect(MonthGrid.trimmingEmptyWeeks(MonthGrid.days(month: date(2026, 2, 1, cal), today: .distantPast, calendar: cal)).count == 28)
    #expect(MonthGrid.trimmingEmptyWeeks(MonthGrid.days(month: date(2026, 8, 1, cal), today: .distantPast, calendar: cal)).count == 42)
}
