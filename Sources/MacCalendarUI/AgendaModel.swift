import AppKit
import EventKit
import MacCalendarCore
import Observation
import SwiftUI

/// One row in a day's list: a calendar event, a reminder due that day, or an Israeli holiday.
public struct AgendaItem: Identifiable, Hashable, Sendable {
    public enum Kind: Int, Sendable { case holiday, event, reminder }
    public let id: String
    public let kind: Kind
    public let title: String
    /// nil = all-day (events, holidays) or no due time (reminders).
    public let start: Date?
    public let end: Date?
    public let color: Color
}

/// Event calendar shown in Settings › Events so the user can hide it.
public struct CalendarInfo: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let source: String
    public let color: Color
}

/// Events and reminders (EventKit) plus holidays (Core) for the days on screen. Reloads itself when
/// the calendar database or the app's preferences change, so views only say which range they show.
@MainActor
@Observable
public final class AgendaModel {
    public private(set) var eventsStatus: EKAuthorizationStatus
    public private(set) var remindersStatus: EKAuthorizationStatus
    public private(set) var calendars: [CalendarInfo] = []
    public private(set) var message: String?
    private var items: [Date: [AgendaItem]] = [:]

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var range: DateInterval?
    /// Bumped on every reload so a slow reminders fetch cannot overwrite newer results.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(calendar: Calendar, observeSystem: Bool) {
        self.calendar = calendar
        eventsStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        guard observeSystem else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            },
            // Settings toggles (show events, hidden calendars, holidays) are UserDefaults writes.
            center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            },
        ]
    }

    private var defaults: UserDefaults { .standard }
    public var showsEvents: Bool { defaults.bool(forKey: Prefs.showEvents) && eventsStatus == .fullAccess }
    public var showsReminders: Bool { defaults.bool(forKey: Prefs.showReminders) && remindersStatus == .fullAccess }
    public var canAddEvents: Bool { showsEvents }

    public func items(on day: Date) -> [AgendaItem] { items[calendar.startOfDay(for: day)] ?? [] }

    /// Show `range` (the visible grid or week). Cheap to call again with the same range.
    public func load(_ range: DateInterval) {
        guard range != self.range else { return }
        self.range = range
        reload()
    }

    private func reload() {
        guard let range else { return }
        generation += 1
        var result: [Date: [AgendaItem]] = [:]
        if defaults.bool(forKey: Prefs.showHolidays) {
            for holiday in HebrewDates.holidays(from: range.start, to: range.end, calendar: calendar) {
                result[holiday.date, default: []].append(AgendaItem(
                    id: "holiday-\(holiday.date.timeIntervalSince1970)-\(holiday.name)", kind: .holiday,
                    title: holiday.name, start: nil, end: nil, color: .secondary))
            }
        }
        if showsEvents { addEvents(in: range, to: &result) }
        items = result.mapValues(Self.sorted)
        if showsReminders { fetchReminders(in: range, generation: generation) }
    }

    private func addEvents(in range: DateInterval, to result: inout [Date: [AgendaItem]]) {
        let hidden = Set((defaults.string(forKey: Prefs.hiddenCalendars) ?? "").split(separator: ",").map(String.init))
        let calendars = store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: calendars)
        for event in store.events(matching: predicate) {
            let item = AgendaItem(
                id: "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)", kind: .event,
                title: event.title ?? "", start: event.isAllDay ? nil : event.startDate,
                end: event.isAllDay ? nil : event.endDate, color: Color(cgColor: event.calendar.cgColor))
            // A multi-day event is listed on every visible day it covers.
            var day = calendar.startOfDay(for: max(event.startDate, range.start))
            repeat {
                result[day, default: []].append(item)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            } while day < min(event.endDate, range.end)
        }
    }

    private func fetchReminders(in range: DateInterval, generation: Int) {
        let calendar = calendar
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: range.start, ending: range.end, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            // Map on EventKit's queue: EKReminder is not Sendable.
            let found: [(Date, AgendaItem)] = (reminders ?? []).compactMap { reminder in
                guard let due = reminder.dueDateComponents, let date = calendar.date(from: due) else { return nil }
                return (calendar.startOfDay(for: date), AgendaItem(
                    id: reminder.calendarItemIdentifier, kind: .reminder, title: reminder.title ?? "",
                    start: due.hour == nil ? nil : date, end: nil, color: Color(cgColor: reminder.calendar.cgColor)))
            }
            Task { @MainActor in self?.merge(found, generation: generation) }
        }
    }

    private func merge(_ reminders: [(Date, AgendaItem)], generation: Int) {
        guard generation == self.generation else { return }
        var result = items
        for (day, item) in reminders { result[day, default: []].append(item) }
        items = result.mapValues(Self.sorted)
    }

    /// Holidays, then all-day items, then by time.
    private static func sorted(_ items: [AgendaItem]) -> [AgendaItem] {
        items.sorted {
            ($0.kind == .holiday ? 0 : 1, $0.start ?? .distantPast, $0.kind.rawValue, $0.title)
                < ($1.kind == .holiday ? 0 : 1, $1.start ?? .distantPast, $1.kind.rawValue, $1.title)
        }
    }

    // MARK: Actions

    /// Saves a quick-add draft to the default calendar. Returns false and sets `message` on failure.
    public func add(_ draft: EventDraft) -> Bool {
        message = nil
        guard canAddEvents, let target = store.defaultCalendarForNewEvents else {
            message = "No calendar to add events to."
            return false
        }
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.isAllDay ? draft.start : draft.end
        event.calendar = target
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            message = "Could not add the event: \(error.localizedDescription)"
            return false
        }
    }

    public func complete(_ item: AgendaItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do { try store.save(reminder, commit: true) } catch {
            message = "Could not complete the reminder: \(error.localizedDescription)"
        }
    }

    // MARK: Access (called only from a Settings toggle)

    public func requestEventsAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            Task { @MainActor in self?.accessChanged() }
        }
    }

    public func requestRemindersAccess() {
        store.requestFullAccessToReminders { [weak self] _, _ in
            Task { @MainActor in self?.accessChanged() }
        }
    }

    /// Re-read access (the user can change it in System Settings) and the calendar list.
    public func accessChanged() {
        eventsStatus = EKEventStore.authorizationStatus(for: .event)
        remindersStatus = EKEventStore.authorizationStatus(for: .reminder)
        if eventsStatus == .fullAccess {
            store.refreshSourcesIfNecessary()
            calendars = store.calendars(for: .event)
                .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title,
                                    color: Color(cgColor: $0.cgColor)) }
                .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
        }
        reload()
    }

    public static func openPrivacySettings(_ pane: String) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)")!
        NSWorkspace.shared.open(url)
    }
}
