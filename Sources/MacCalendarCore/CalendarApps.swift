import Foundation

public enum CalendarApps {
    /// Calendar's own .ics import helper: it opens files but is not an app anyone launches.
    public static let excludedBundleIDs: Set<String> = ["com.apple.CalendarFileHandler"]

    /// True when an app's Info.plist explicitly declares calendar files (.ics / text/calendar).
    /// LaunchServices also lists editors and browsers that open any text or data file for .ics;
    /// an explicit declaration is what separates Calendar, Outlook, Fantastical from TextEdit or Chrome.
    public static func opensCalendarFiles(info: [String: Any]) -> Bool {
        let types = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        return types.contains { type in
            let utis = type["LSItemContentTypes"] as? [String] ?? []
            let extensions = type["CFBundleTypeExtensions"] as? [String] ?? []
            let mimeTypes = type["CFBundleTypeMIMETypes"] as? [String] ?? []
            return utis.contains { calendarUTIs.contains($0) }
                || extensions.contains { $0.lowercased() == "ics" }
                || mimeTypes.contains("text/calendar")
        }
    }

    private static let calendarUTIs: Set<String> = ["com.apple.ical.ics", "com.apple.ical.vcs", "public.calendar-event"]
}
