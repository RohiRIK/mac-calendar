# Mac Calendar

A tiny native macOS menu bar calendar. Click the calendar icon in the menu bar for a
month view.

<img src="docs/screenshots/panel.png" width="355" alt="Mac Calendar panel: September 2026 month grid with today highlighted, Open Microsoft Outlook, Settings and Quit">
<img src="docs/screenshots/settings.png" width="476" alt="Mac Calendar Settings: Open at Login, Calendar app (Microsoft Outlook), Show date next to icon, First day of week, Show week numbers, Show days from other months">

- Month grid with today highlighted; week start and day names follow your system settings.
- `←` / `→` change month, `T` jumps back to today (or use the header buttons).
- Updates itself at midnight, after sleep, and on time zone changes.
- Menu bar shows a calendar icon (optionally with the date).
- Open your calendar app, Settings… (⌘,), Quit (⌘Q).
- Settings: Open at Login, calendar app (detects every installed app that opens calendar files, e.g.
  Calendar, Outlook, Fantastical; default = system default), show date in menu bar, first day of week,
  week numbers, days from other months.

No permissions, no network, no dependencies. Swift 6 + SwiftUI, macOS 15+.

## Build

```bash
scripts/check.sh              # tests + release bundle
open build/MacCalendar.app
```

## License

MIT
