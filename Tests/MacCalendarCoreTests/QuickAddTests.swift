import Foundation
import Testing
@testable import MacCalendarCore

private let cal = Calendar.current

@Test func titleAndTimeFromText() throws {
    let now = Date.now
    let draft = try #require(QuickAdd.parse("Lunch with Dan on Fri at 1pm", day: now))
    #expect(draft.title == "Lunch with Dan")
    #expect(!draft.isAllDay)
    #expect(cal.component(.weekday, from: draft.start) == 6)
    #expect(cal.component(.hour, from: draft.start) == 13)
    #expect(draft.end.timeIntervalSince(draft.start) == 3600)
}

@Test func dateWithoutTimeIsAllDay() throws {
    let now = Date.now
    let draft = try #require(QuickAdd.parse("Dentist tomorrow", day: now))
    #expect(draft.title == "Dentist")
    #expect(draft.isAllDay)
    #expect(cal.isDate(draft.start, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now)!))
}

@Test func noDateUsesSelectedDayAllDay() throws {
    let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let draft = try #require(QuickAdd.parse("Call mom", day: day))
    #expect(draft.title == "Call mom")
    #expect(draft.isAllDay)
    #expect(cal.isDate(draft.start, inSameDayAs: day))
}

@Test func timeOnlyLandsOnSelectedDay() throws {
    let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let draft = try #require(QuickAdd.parse("Standup 10:30", day: day))
    #expect(draft.title == "Standup")
    #expect(cal.isDate(draft.start, inSameDayAs: day))
    #expect(cal.dateComponents([.hour, .minute], from: draft.start) == DateComponents(hour: 10, minute: 30))
}

@Test func rangeSetsDuration() throws {
    let draft = try #require(QuickAdd.parse("Offsite 2-4pm next Tuesday", day: .now))
    #expect(draft.title == "Offsite")
    #expect(draft.end.timeIntervalSince(draft.start) == 7200)
}

@Test func emptyTextIsNil() {
    #expect(QuickAdd.parse("   ", day: .now) == nil)
}

@Test func twentyFourHourTimeIsTakenAsWritten() throws {
    // Regardless of the current time of day (the detector alone would pick 22:30 after 10:30).
    let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 12))!
    let morning = try #require(QuickAdd.parse("Standup 10:30", day: day))
    let evening = try #require(QuickAdd.parse("Gym 18:15", day: day))
    #expect(cal.component(.hour, from: morning.start) == 10)
    #expect(cal.component(.hour, from: evening.start) == 18)
}
