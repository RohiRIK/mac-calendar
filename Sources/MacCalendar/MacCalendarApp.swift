import MacCalendarUI
import SwiftUI

@main
struct MacCalendarApp: App {
    @State private var model = CalendarModel()
    @AppStorage(Prefs.showDateInMenuBar) private var showDate = false

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            // Calendar icon; optional short date beside it (Settings › Menu Bar).
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                if showDate { Text(model.today, format: .dateTime.weekday(.abbreviated).day()) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(model.today, format: .dateTime.weekday(.wide).month(.wide).day()))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
