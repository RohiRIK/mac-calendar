import EventKit
import SwiftUI

/// ⌘, Settings window. App preferences live here, never in the menu bar panel.
public struct SettingsView: View {
    @Bindable var model: CalendarModel
    @AppStorage(Prefs.showDateInMenuBar) private var showDateInMenuBar = false
    @AppStorage(Prefs.showWeekNumbers) private var showWeekNumbers = false
    @AppStorage(Prefs.showOtherMonths) private var showOtherMonths = true
    @AppStorage(Prefs.calendarApp) private var calendarAppID = ""
    @AppStorage(Prefs.theme) private var theme: AppTheme = .system
    @AppStorage(Prefs.accent) private var accent: AccentChoice = .system
    @AppStorage(Prefs.showEvents) private var showEvents = false
    @AppStorage(Prefs.showReminders) private var showReminders = false
    @AppStorage(Prefs.hiddenCalendars) private var hiddenCalendars = ""
    @AppStorage(Prefs.showHebrewDates) private var showHebrewDates = false
    @AppStorage(Prefs.showHolidays) private var showHolidays = false
    @AppStorage(Prefs.hotKeyEnabled) private var hotKeyEnabled = true
    @State private var apps: [CalendarApp] = []

    public init(model: CalendarModel) { self.model = model }

    public var body: some View {
        Form {
            Section("General") {
                Toggle(isOn: Binding(get: { model.opensAtLogin }, set: model.setOpensAtLogin)) {
                    Text("Open at Login")
                    Text("Start Mac Calendar when you log in.")
                }
                if let message = model.message {
                    Text(message).foregroundStyle(.red)
                }
                Picker(selection: $calendarAppID) {
                    Text("System Default (\(model.calendarApp(id: "")?.name ?? "Calendar"))").tag("")
                    Divider()
                    ForEach(apps) { app in
                        Label {
                            Text(app.name)
                        } icon: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        }
                        .tag(app.id)
                    }
                } label: {
                    Text("Calendar app")
                    Text("Opened by the Open command in the menu. Lists every installed app that opens calendar files.")
                }
            }

            Section("Events") {
                Toggle(isOn: Binding(get: { showEvents }, set: { on in
                    showEvents = on
                    if on, model.agenda.eventsStatus == .notDetermined { model.agenda.requestEventsAccess() }
                })) {
                    Text("Show calendar events")
                    Text("Dots in the grid, a list for the selected day, and Add Event in the panel.")
                }
                if showEvents {
                    AccessNote(status: model.agenda.eventsStatus, what: "calendars", pane: "Calendars", request: model.agenda.requestEventsAccess)
                }
                if showEvents, model.agenda.eventsStatus == .fullAccess {
                    ForEach(model.agenda.calendars) { calendar in
                        let hidden = hiddenCalendars.split(separator: ",").map(String.init)
                        Toggle(isOn: Binding(
                            get: { !hidden.contains(calendar.id) },
                            set: { hiddenCalendars = ($0 ? hidden.filter { $0 != calendar.id } : hidden + [calendar.id]).joined(separator: ",") }
                        )) {
                            Label {
                                Text(calendar.title)
                                Text(calendar.source)
                            } icon: {
                                Circle().fill(calendar.color).frame(width: 10, height: 10)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }

            Section("Reminders") {
                Toggle(isOn: Binding(get: { showReminders }, set: { on in
                    showReminders = on
                    if on, model.agenda.remindersStatus == .notDetermined { model.agenda.requestRemindersAccess() }
                })) {
                    Text("Show reminders")
                    Text("Reminders due each day, with a button to check them off.")
                }
                if showReminders {
                    AccessNote(status: model.agenda.remindersStatus, what: "reminders", pane: "Reminders", request: model.agenda.requestRemindersAccess)
                }
            }

            Section("Hebrew Calendar") {
                Toggle("Show Hebrew dates", isOn: $showHebrewDates)
                Toggle("Show Israeli holidays", isOn: $showHolidays)
            }

            Section("Keyboard") {
                Toggle(isOn: $hotKeyEnabled) {
                    Text("Open with ⌥⌘P")
                    Text("Shows the calendar from any app.")
                }
            }

            Section("Appearance") {
                Picker(selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Theme")
                    Text("Applies to the panel and this window.")
                }
                .pickerStyle(.segmented)
                LabeledContent {
                    AccentSwatches(selection: $accent)
                } label: {
                    Text("Accent color")
                    Text(accent.title)
                }
            }

            Section("Menu Bar") {
                Toggle("Show date next to icon", isOn: $showDateInMenuBar)
            }

            Section("Calendar") {
                Picker("First day of week", selection: $model.firstWeekday) {
                    Text("System Setting").tag(0)
                    Divider()
                    ForEach([1, 2, 7], id: \.self) { day in
                        Text(Calendar.current.standaloneWeekdaySymbols[day - 1]).tag(day)
                    }
                }
                Toggle("Show week numbers", isOn: $showWeekNumbers)
                Toggle("Show days from other months", isOn: $showOtherMonths)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .themed(theme, accent)
        .onAppear {
            model.refreshLoginItem()
            model.agenda.accessChanged()
            // Detect on open so apps installed while running show up.
            apps = model.calendarApps
        }
    }
}

/// Why a data type is off when access was denied, with a way to fix it.
private struct AccessNote: View {
    let status: EKAuthorizationStatus
    let what: String
    let pane: String
    let request: () -> Void

    var body: some View {
        switch status {
        case .fullAccess:
            EmptyView()
        case .notDetermined:
            LabeledContent {
                Button("Allow Access…", action: request)
            } label: {
                Text("Mac Calendar needs access to your \(what).")
            }
        default:
            LabeledContent {
                Button("Open Privacy Settings…") { AgendaModel.openPrivacySettings(pane) }
            } label: {
                Text("No access to \(what)").foregroundStyle(.red)
                Text("Allow Mac Calendar in System Settings › Privacy & Security › \(pane).")
            }
        }
    }
}

/// Round color swatches like System Settings > Appearance > Accent color.
private struct AccentSwatches: View {
    @Binding var selection: AccentChoice

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AccentChoice.allCases) { choice in
                Button { selection = choice } label: {
                    Circle()
                        .fill(choice.color.map { AnyShapeStyle($0) }
                              ?? AnyShapeStyle(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center)))
                        .frame(width: 16, height: 16)
                        .overlay {
                            if selection == choice {
                                Circle().fill(.white).frame(width: 6, height: 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(choice.title)
                .accessibilityLabel(choice.title)
                .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
    }
}

#Preview("Settings") {
    SettingsView(model: .preview())
}
