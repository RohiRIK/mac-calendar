import AppKit
import UniformTypeIdentifiers
import MacCalendarCore
import Observation
import ServiceManagement

@MainActor
@Observable
public final class CalendarModel {
    /// Any date inside the month on screen.
    public private(set) var month: Date
    public private(set) var today: Date
    public private(set) var opensAtLogin: Bool
    public private(set) var message: String?

    /// Weekday that starts the grid: 0 = system setting, 1 = Sunday … 7 = Saturday. Saved in UserDefaults.
    public var firstWeekday: Int {
        didSet { if persists { UserDefaults.standard.set(firstWeekday, forKey: Prefs.firstWeekday) } }
    }

    private let baseCalendar: Calendar
    private let persists: Bool
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    public init(today: Date = .now, calendar: Calendar = .autoupdatingCurrent, observeSystem: Bool = true) {
        self.today = today
        self.month = today
        self.baseCalendar = calendar
        self.persists = observeSystem
        self.firstWeekday = observeSystem ? UserDefaults.standard.integer(forKey: Prefs.firstWeekday) : 0
        self.opensAtLogin = observeSystem && SMAppService.mainApp.status == .enabled
        guard observeSystem else { return }
        // Midnight, wake from sleep across a day, and time zone or clock changes all post one of these.
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dayChanged() }
            })
        }
    }

    private var calendar: Calendar {
        guard firstWeekday != 0 else { return baseCalendar }
        var cal = baseCalendar
        cal.firstWeekday = firstWeekday
        return cal
    }

    public var days: [CalendarDay] { MonthGrid.days(month: month, today: today, calendar: calendar) }
    public var weekNumbers: [Int] { MonthGrid.weekNumbers(days: days, calendar: calendar) }
    public var weekdaySymbols: [String] { MonthGrid.weekdaySymbols(calendar: calendar) }
    public var isShowingToday: Bool { calendar.isDate(month, equalTo: today, toGranularity: .month) }

    public func showMonth(offset: Int) {
        month = calendar.date(byAdding: .month, value: offset, to: month) ?? month
    }

    public func showToday() { month = today }

    private func dayChanged() {
        let wasShowingToday = isShowingToday
        today = .now
        if wasShowingToday { month = today }
    }

    /// Re-read the login item; the user can change it in System Settings › Login Items.
    public func refreshLoginItem() { opensAtLogin = SMAppService.mainApp.status == .enabled }

    public func setOpensAtLogin(_ on: Bool) {
        message = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = "Could not change Open at Login: \(error.localizedDescription)"
        }
        let status = SMAppService.mainApp.status
        opensAtLogin = status == .enabled
        if status == .requiresApproval {
            message = "Allow Mac Calendar in System Settings > General > Login Items."
        }
    }

    /// Calendar apps installed on this Mac: anything registered to open .ics files or webcal: links
    /// (Calendar, Outlook, Fantastical, Notion Calendar, BusyCal, …), deduplicated, sorted by name.
    public var calendarApps: [CalendarApp] {
        let workspace = NSWorkspace.shared
        // `.ics` resolves to com.apple.ical.ics, which Outlook declares; public.calendar-event alone misses it.
        let fileTypes = [UTType(filenameExtension: "ics"), .calendarEvent].compactMap { $0 }
        let fileHandlers = fileTypes.flatMap { workspace.urlsForApplications(toOpen: $0) }
            .filter { CalendarApps.opensCalendarFiles(info: Bundle(url: $0)?.infoDictionary ?? [:]) }
        // webcal: handlers declare the scheme explicitly, so no filter is needed.
        let linkHandlers = workspace.urlsForApplications(toOpen: URL(string: "webcal://example.com")!)
        var seen = CalendarApps.excludedBundleIDs
        return (fileHandlers + linkHandlers).compactMap(CalendarApp.init).filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Chosen app; else the system default for .ics files when it is a real calendar app; else Calendar.app.
    public func calendarApp(id: String) -> CalendarApp? {
        let workspace = NSWorkspace.shared
        let defaultID = UTType(filenameExtension: "ics")
            .flatMap { workspace.urlForApplication(toOpen: $0) }
            .flatMap { Bundle(url: $0)?.bundleIdentifier }
            .flatMap { CalendarApps.excludedBundleIDs.contains($0) ? nil : $0 }
        let url = [id, defaultID ?? "", "com.apple.iCal"].lazy
            .filter { !$0.isEmpty }
            .compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
            .first
        return url.flatMap(CalendarApp.init)
    }

    public func openCalendarApp(id: String) {
        guard let app = calendarApp(id: id) else { return }
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
    }

    public func quit() { NSApplication.shared.terminate(nil) }
}

extension CalendarModel {
    /// Fixed date and Sunday-start calendar so previews render the same every time.
    static func preview(_ ymd: (Int, Int, Int) = (2026, 9, 29)) -> CalendarModel {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US")
        let date = cal.date(from: DateComponents(year: ymd.0, month: ymd.1, day: ymd.2))!
        return CalendarModel(today: date, calendar: cal, observeSystem: false)
    }
}

public struct CalendarApp: Identifiable, Hashable {
    public let id: String  // bundle identifier
    public let name: String
    public let url: URL

    init?(url: URL) {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        self.id = id
        self.url = url
        self.name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
