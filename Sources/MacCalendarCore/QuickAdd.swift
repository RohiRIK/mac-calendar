import Foundation

public struct EventDraft: Equatable, Sendable {
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
}

/// Turns "Lunch with Dan Fri 1pm" into an event: `NSDataDetector` finds the date phrase, the rest is
/// the title. No date → all-day on the selected day. A time with no date → that time on the selected day.
public enum QuickAdd {
    public static func parse(_ text: String, day: Date, calendar: Calendar = .current) -> EventDraft? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let ns = text as NSString
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        guard let match = detector?.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let found = match.date
        else { return allDay(text, on: day, calendar) }

        let phrase = ns.substring(with: match.range)
        let title = cleanTitle(ns.replacingCharacters(in: match.range, with: " "))
        guard matches(phrase, timePattern) else { return allDay(title, on: found, calendar) }

        // ponytail: regex guesses whether the phrase names a date; NSDataDetector does not say.
        let namesDate = phrase.replacingOccurrences(of: timeTokens, with: "", options: [.regularExpression, .caseInsensitive])
            .contains { $0.isLetter || $0.isNumber }
        let start = namesDate ? found : onDay(day, time: clock(in: phrase) ?? calendar.dateComponents([.hour, .minute], from: found), calendar) ?? found
        return EventDraft(title: title, start: start, end: start.addingTimeInterval(match.duration > 0 ? match.duration : 3600), isAllDay: false)
    }

    private static let timePattern = #"\d:\d{2}|\d\s*(am|pm)\b|\bnoon\b|\bmidnight\b"#
    private static let timeTokens = #"\d{1,2}(:\d{2})?\s*(-\s*\d{1,2}(:\d{2})?)?\s*(am|pm)?|\b(at|noon|midnight)\b"#

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func allDay(_ title: String, on day: Date, _ calendar: Calendar) -> EventDraft {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return EventDraft(title: title, start: start, end: end, isAllDay: true)
    }

    private static func onDay(_ day: Date, time: DateComponents, _ calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day)
    }

    /// "10:30" with no am/pm, read as a 24-hour time. NSDataDetector picks the next 10:30 instead,
    /// which after 10:30 in the morning is 22:30.
    private static func clock(in phrase: String) -> DateComponents? {
        guard !matches(phrase, #"am|pm"#),
              let match = phrase.firstMatch(of: /(\d{1,2}):(\d{2})/),
              let hour = Int(match.1), let minute = Int(match.2), hour < 24, minute < 60 else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    /// Collapses spaces and drops a dangling "on"/"at" left where the date phrase was.
    private static func cleanTitle(_ text: String) -> String {
        let title = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+(on|at|from|for)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "New Event" : title
    }
}
