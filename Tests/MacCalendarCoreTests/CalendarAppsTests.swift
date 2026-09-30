import Testing
@testable import MacCalendarCore

// Info.plist fragments shaped like the real apps' CFBundleDocumentTypes.
private var outlook: [String: Any] { ["CFBundleDocumentTypes": [
    ["CFBundleTypeName": "Microsoft Outlook calendar event", "LSItemContentTypes": ["com.apple.ical.ics"], "LSHandlerRank": "Default"],
]] }
private var byExtension: [String: Any] { ["CFBundleDocumentTypes": [["CFBundleTypeExtensions": ["ICS"]]]] }
private var byMIME: [String: Any] { ["CFBundleDocumentTypes": [["CFBundleTypeMIMETypes": ["text/calendar"]]]] }
private var byModernType: [String: Any] { ["CFBundleDocumentTypes": [["LSItemContentTypes": ["public.calendar-event"]]]] }
private var textEditor: [String: Any] { ["CFBundleDocumentTypes": [["LSItemContentTypes": ["public.plain-text", "public.data"]]]] }

@Test func detectsExplicitCalendarDeclarations() {
    for info in [outlook, byExtension, byMIME, byModernType] {
        #expect(CalendarApps.opensCalendarFiles(info: info))
    }
}

@Test func ignoresGenericFileHandlers() {
    #expect(!CalendarApps.opensCalendarFiles(info: textEditor))
    #expect(!CalendarApps.opensCalendarFiles(info: [:]))
}
