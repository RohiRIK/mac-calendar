import AppKit
import MacCalendarCore
import SwiftUI

/// Menu bar panel: month header, weekday row, six-week grid, app commands.
public struct PanelView: View {
    let model: CalendarModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.calendarApp) private var calendarAppID = ""
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system
    @AppStorage(Prefs.accent) private var accent: AccentChoice = .system

    public init(model: CalendarModel) { self.model = model }

    /// A menu bar app is never active; activate first or Settings opens behind other windows.
    private func showSettings() {
        dismiss()
        NSApp.activate()
        openSettings()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonthHeader(model: model)
            MonthGridView(model: model)
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
        // Menu bar windows keep an old height when content changes; size to content every time.
        .fixedSize(horizontal: false, vertical: true)
        .themed(theme, accent)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { model.showMonth(offset: -1); return .handled }
        .onKeyPress(.rightArrow) { model.showMonth(offset: 1); return .handled }
        .onKeyPress("t") { model.showToday(); return .handled }
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
        HStack(spacing: 2) {
            Text(model.month, format: .dateTime.month(.wide).year())
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            HeaderButton(symbol: "chevron.left", help: "Previous Month (←)") { model.showMonth(offset: -1) }
            HeaderButton(symbol: "circle.fill", help: "Today (T)", disabled: model.isShowingToday) { model.showToday() }
            HeaderButton(symbol: "chevron.right", help: "Next Month (→)") { model.showMonth(offset: 1) }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
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
            ForEach(Array(model.days.enumerated()), id: \.element.id) { index, day in
                if showWeekNumbers, index.isMultiple(of: 7) {
                    Text(model.weekNumbers[index / 7], format: .number)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Week \(model.weekNumbers[index / 7])")
                }
                DayCell(day: day, visible: day.inMonth || showOtherMonths)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct DayCell: View {
    let day: CalendarDay
    var visible = true

    var body: some View {
        Text(day.day, format: .number)
            .font(.callout.weight(day.isToday ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(day.isToday ? AnyShapeStyle(.white) : day.inMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .frame(width: 28, height: 28)
            .background {
                if day.isToday { Circle().fill(.tint) }
            }
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(!visible)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityAddTraits(day.isToday ? .isSelected : [])
    }
}

#Preview("September 2026") {
    PanelView(model: .preview())
}

#Preview("February 2026 (starts on Sunday)") {
    PanelView(model: .preview((2026, 2, 14)))
}
