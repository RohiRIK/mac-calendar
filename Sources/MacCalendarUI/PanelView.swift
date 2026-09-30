import AppKit
import MacCalendarCore
import SwiftUI

/// Menu bar panel: header, month grid or week list, the selected day's agenda, quick add, commands.
public struct PanelView: View {
    let model: CalendarModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.calendarApp) private var calendarAppID = ""
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system
    @AppStorage(Prefs.accent) private var accent: AccentChoice = .system
    @AppStorage(Prefs.showEvents) private var showEvents = false
    @AppStorage(Prefs.showReminders) private var showReminders = false
    @AppStorage(Prefs.showHolidays) private var showHolidays = false
    @FocusState private var focused: Bool
    @State private var height: CGFloat = 0

    public init(model: CalendarModel) { self.model = model }

    private var showsAgenda: Bool { showEvents || showReminders || showHolidays }

    /// A menu bar app is never active; activate first or Settings opens behind other windows.
    private func showSettings() {
        dismiss()
        NSApp.activate()
        openSettings()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonthHeader(model: model)
            // Week view takes exactly the month view's height (the month page stays laid out,
            // invisible), so switching views never resizes the window.
            let week = model.mode == .week
            VStack(spacing: 0) {
                MonthGridView(model: model)
                if showsAgenda {
                    MenuDivider()
                    DayAgendaView(model: model)
                }
            }
            .opacity(week ? 0 : 1)
            .allowsHitTesting(!week)
            .accessibilityHidden(week)
            .overlay(alignment: .top) {
                if week { WeekListView(model: model) }
            }
            if model.agenda.canAddEvents {
                QuickAddField(model: model)
            }
            MenuDivider()
            CommandRow(title: "Open \(model.calendarApp(id: calendarAppID)?.name ?? "Calendar")") {
                model.openCalendarApp(id: calendarAppID)
            }
            MenuDivider()
            CommandRow(title: "Settings…", key: "⌘,", action: showSettings)
            CommandRow(title: "Quit Mac Calendar", key: "⌘Q", action: model.quit)
        }
        .padding(6)
        .frame(width: 272)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .background(FitWindowHeight(height: height))
        .themed(theme, accent)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .task(id: model.visibleRange) { model.agenda.load(model.visibleRange) }
        .onKeyPress(.leftArrow) { model.showPage(offset: -1); return .handled }
        .onKeyPress(.rightArrow) { model.showPage(offset: 1); return .handled }
        .onKeyPress("t") { model.showToday(); return .handled }
        .onKeyPress("w") { model.mode = model.mode == .month ? .week : .month; return .handled }
        .onKeyPress(keys: ["q", ","]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if press.key == "q" { model.quit() } else { showSettings() }
            return .handled
        }
    }
}

struct MonthHeader: View {
    let model: CalendarModel

    var body: some View {
        let unit = model.mode == .month ? "Month" : "Week"
        HStack(spacing: 2) {
            title
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            HeaderButton(symbol: model.mode == .month ? "list.bullet" : "calendar",
                         help: model.mode == .month ? "Week View (W)" : "Month View (W)") {
                model.mode = model.mode == .month ? .week : .month
            }
            HeaderButton(symbol: "chevron.left", help: "Previous \(unit) (←)") { model.showPage(offset: -1) }
            HeaderButton(symbol: "circle.fill", help: "Today (T)", disabled: model.isShowingToday) { model.showToday() }
            HeaderButton(symbol: "chevron.right", help: "Next \(unit) (→)") { model.showPage(offset: 1) }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    @ViewBuilder private var title: some View {
        if model.mode == .month {
            Text(model.month, format: .dateTime.month(.wide).year())
        } else if let first = model.weekDays.first?.date, let last = model.weekDays.last?.date {
            Text(first..<last, format: .interval.month(.abbreviated).day())
        }
    }
}

private struct HeaderButton: View {
    let symbol: String
    let help: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "circle.fill" ? 6 : 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct MonthGridView: View {
    let model: CalendarModel
    @AppStorage(Prefs.showWeekNumbers) private var showWeekNumbers = false
    @AppStorage(Prefs.showOtherMonths) private var showOtherMonths = true
    @AppStorage(Prefs.showHebrewDates) private var showHebrewDates = false

    /// All six weeks, or, with other-month days hidden, only weeks holding this month's days
    /// (an empty last row would leave a gap).
    private var days: [CalendarDay] {
        showOtherMonths ? model.days : MonthGrid.trimmingEmptyWeeks(model.days)
    }

    private var columns: [GridItem] {
        let days = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return showWeekNumbers ? [GridItem(.fixed(22), spacing: 2)] + days : days
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            if showWeekNumbers { Color.clear.frame(height: 20) }
            ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(height: 20)
                    .accessibilityHidden(true)
            }
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if showWeekNumbers, index.isMultiple(of: 7) {
                    Text(model.weekNumbers[index / 7], format: .number)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Week \(model.weekNumbers[index / 7])")
                }
                DayCell(day: day, visible: day.inMonth || showOtherMonths, selected: model.isSelected(day.date),
                        hebrew: showHebrewDates ? HebrewDates.dayLabel(day.date) : nil,
                        dots: model.agenda.items(on: day.date).prefix(3).map(\.color)) {
                    model.select(day.date)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct DayCell: View {
    let day: CalendarDay
    var visible = true
    var selected = false
    /// Hebrew day in letters, shown under the number when enabled in Settings.
    var hebrew: String?
    /// Colors of the day's first events, reminders or holidays.
    var dots: [Color] = []
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(day.day, format: .number)
                    .font(.callout.weight(day.isToday ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(day.isToday ? AnyShapeStyle(.white) : day.inMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .frame(width: 26, height: 26)
                    .background {
                        if day.isToday { Circle().fill(.tint) }
                        else if selected { Circle().fill(.quaternary) }
                    }
                if let hebrew {
                    Text(hebrew)
                        .font(.system(size: 9))
                        .foregroundStyle(day.inMonth ? .secondary : .tertiary)
                }
                HStack(spacing: 2) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .disabled(!visible)
        .accessibilityHidden(!visible)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityValue(dots.isEmpty ? "" : "\(dots.count) items")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("September 2026") {
    PanelView(model: .preview())
}

#Preview("February 2026 (starts on Sunday)") {
    PanelView(model: .preview((2026, 2, 14)))
}

#Preview("Week view") {
    let model = CalendarModel.preview()
    model.mode = .week
    return PanelView(model: model)
}
