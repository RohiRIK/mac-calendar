import Foundation
import Testing
@testable import MacCalendarCore

private let utc: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d))!
}

/// Holiday names on each day of a Gregorian year, keyed by (month, day).
private func holidays(_ year: Int) -> [String: String] {
    let list = HebrewDates.holidays(from: date(year, 1, 1), to: date(year + 1, 1, 1), calendar: utc)
    return Dictionary(list.map { (utc.dateComponents([.month, .day], from: $0.date), $0.name) }
        .map { ("\($0.0.month!)-\($0.0.day!)", $0.1) }, uniquingKeysWith: { a, _ in a })
}

@Test func dayLabelInHebrewLetters() {
    #expect(HebrewDates.dayLabel(date(2026, 9, 30), calendar: utc) == "י״ט")
    #expect(HebrewDates.dayLabel(date(2026, 9, 12), calendar: utc) == "א׳")
}

@Test func fullLabel() {
    #expect(HebrewDates.fullLabel(date(2026, 9, 30), calendar: utc) == "י״ט תשרי ה׳תשפ״ז")
}

@Test func fixedHolidays2025() {
    let h = holidays(2025)
    #expect(h["3-14"] == "Purim")
    #expect(h["4-13"] == "Pesach")
    #expect(h["6-2"] == "Shavuot")
    #expect(h["9-23"] == "Rosh Hashana")
    #expect(h["10-2"] == "Yom Kippur")
    #expect(h["12-15"] == "Hanukkah")
    #expect(h["12-22"] == "Hanukkah")  // eighth day
    #expect(h["12-23"] == nil)
}

@Test func purimInLeapYearIsAdarII() {
    #expect(holidays(2024)["3-24"] == "Purim")
    #expect(holidays(2024)["2-23"] == nil)  // 14 Adar I
}

@Test func yomHaShoahMovesOffFriday() {
    // 27 Nisan 5785 was Friday 25 Apr 2025: observed Thursday.
    let h = holidays(2025)
    #expect(h["4-24"] == "Yom HaShoah")
    #expect(h["4-25"] == nil)
}

@Test func independenceDayMovesOffSaturday() {
    // 5 Iyar 5785 was Saturday 3 May 2025: Zikaron Wed 30 Apr, Atzmaut Thu 1 May.
    let h = holidays(2025)
    #expect(h["4-30"] == "Yom HaZikaron")
    #expect(h["5-1"] == "Yom HaAtzmaut")
    #expect(h["5-3"] == nil)
}

@Test func independenceDayMovesOffMonday() {
    // 5 Iyar 5784 was Monday 13 May 2024: Zikaron Mon 13, Atzmaut Tue 14.
    let h = holidays(2024)
    #expect(h["5-13"] == "Yom HaZikaron")
    #expect(h["5-14"] == "Yom HaAtzmaut")
}

@Test func tishaBAvMovesOffSaturday() {
    // 9 Av 5785 was Saturday 2 Aug 2025: observed Sunday.
    let h = holidays(2025)
    #expect(h["8-3"] == "Tisha B'Av")
    #expect(h["8-2"] == nil)
}

@Test func sukkotAndSimchatTorah2026() {
    let h = holidays(2026)
    #expect(h["9-26"] == "Sukkot")
    #expect(h["9-30"] == "Sukkot (Chol HaMoed)")
    #expect(h["10-3"] == "Simchat Torah")
}
