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
            // Detect on open so apps installed while running show up.
            apps = model.calendarApps
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
