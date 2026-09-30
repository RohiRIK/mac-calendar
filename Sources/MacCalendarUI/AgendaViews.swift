import MacCalendarCore
import SwiftUI

/// The selected day's holidays, events and reminders, under the month grid. As tall as its rows,
/// scrolling past about six.
struct DayAgendaView: View {
    let model: CalendarModel
    @AppStorage(Prefs.showHebrewDates) private var showHebrewDates = false

    var body: some View {
        let items = model.agenda.items(on: model.selectedDay)
        VStack(alignment: .leading, spacing: 2) {
            DayTitle(date: model.selectedDay, hebrew: showHebrewDates ? HebrewDates.fullLabel(model.selectedDay) : nil)
            if items.isEmpty {
                Text("No events")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
            } else {
                CappedScroll(maxHeight: 6 * AgendaRow.height) {
                    VStack(spacing: 0) {
                        ForEach(items) { AgendaRow(item: $0, agenda: model.agenda) }
                    }
                }
            }
        }
    }
}

/// "Wednesday, 30 Sep" on the left, optional Hebrew date on the right.
private struct DayTitle: View {
    let date: Date
    var hebrew: String?
    var highlighted = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(highlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Spacer()
            if let hebrew {
                Text(hebrew)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

/// As tall as its content up to `maxHeight`, then scrolls.
private struct CappedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .frame(height: min(height, maxHeight))
    }
}

/// Time column, calendar color bar (reminders: a checkbox circle, holidays: a star), title.
struct AgendaRow: View {
    static let height: CGFloat = 24
    let item: AgendaItem
    let agenda: AgendaModel

    var body: some View {
        HStack(spacing: 8) {
            Text(time)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            marker
                .frame(width: 12)
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
                .foregroundStyle(item.kind == .holiday ? .secondary : .primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.height)
        .help(item.title)
    }

    @ViewBuilder private var marker: some View {
        switch item.kind {
        case .holiday:
            Image(systemName: "star.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        case .event:
            Capsule().fill(item.color).frame(width: 3, height: 14)
        case .reminder:
            Button { agenda.complete(item) } label: {
                Circle().strokeBorder(item.color, lineWidth: 1.5).frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .help("Mark as Completed")
            .accessibilityLabel("Complete \(item.title)")
        }
    }

    private var time: String {
        guard let start = item.start else { return item.kind == .event ? "all-day" : "" }
        return start.formatted(date: .omitted, time: .shortened)
    }
}

/// Week view, as tall as the month view: every day of the week with its items, scrolled to the
/// selected day. Click a day title to select it for Add Event.
struct WeekListView: View {
    let model: CalendarModel
    @AppStorage(Prefs.showHebrewDates) private var showHebrewDates = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(model.weekDays) { day in
                        let items = model.agenda.items(on: day.date)
                        VStack(alignment: .leading, spacing: 0) {
                            DayTitle(date: day.date, hebrew: showHebrewDates ? HebrewDates.dayLabel(day.date) : nil,
                                     highlighted: day.isToday)
                                .padding(.vertical, 3)
                                .background {
                                    if model.isSelected(day.date) {
                                        RoundedRectangle(cornerRadius: 6).fill(.quinary)
                                    }
                                }
                                .contentShape(.rect)
                                .onTapGesture { model.select(day.date) }
                                .accessibilityAddTraits(model.isSelected(day.date) ? [.isButton, .isSelected] : .isButton)
                            if items.isEmpty {
                                Text("No events")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 8)
                                    .frame(height: 18)
                            }
                            ForEach(items) { AgendaRow(item: $0, agenda: model.agenda) }
                        }
                        .id(day.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear {
                if let selected = model.weekDays.first(where: { model.isSelected($0.date) }) {
                    proxy.scrollTo(selected.id, anchor: .top)
                }
            }
        }
    }
}

/// "Lunch with Dan Fri 1pm" → a new event in the default calendar. No date → the selected day.
struct QuickAddField: View {
    let model: CalendarModel
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                TextField("Add Event", text: $text, prompt: Text("Add event, e.g. Lunch Fri 1pm"))
                    .textFieldStyle(.plain)
                    .onSubmit(add)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            if let message = model.agenda.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.leading, 30)
            }
        }
        .padding(.top, 4)
    }

    private func add() {
        guard let draft = QuickAdd.parse(text, day: model.selectedDay), model.agenda.add(draft) else { return }
        text = ""
        model.select(draft.start)
    }
}
