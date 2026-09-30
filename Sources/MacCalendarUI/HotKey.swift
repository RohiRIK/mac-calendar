import AppKit
import Carbon.HIToolbox

/// System-wide ⌥⌘P that toggles the menu bar panel. Carbon `RegisterEventHotKey` needs no
/// Accessibility permission (an `NSEvent` global monitor would).
@MainActor
final class HotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    var isEnabled = false {
        didSet { if isEnabled != oldValue { isEnabled ? register() : unregister() } }
    }

    private func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.togglePanel() }
            return noErr
        }, 1, &spec, nil, &handler)
        RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(cmdKey | optionKey),
                            EventHotKeyID(signature: OSType(0x4D43_414C), id: 1),  // "MCAL"
                            GetApplicationEventTarget(), 0, &hotKey)
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }

    /// SwiftUI has no API to open a `MenuBarExtra` window, so click its status bar button.
    // ponytail: relies on MenuBarExtra hosting an NSStatusBarButton; switch to NSStatusItem + NSPanel
    // (MacAppArchitecture/AppShapes.md) if a macOS release changes that.
    static func togglePanel() {
        func button(in view: NSView?) -> NSStatusBarButton? {
            guard let view else { return nil }
            return view as? NSStatusBarButton ?? view.subviews.lazy.compactMap { button(in: $0) }.first
        }
        guard let statusButton = NSApp.windows.lazy.compactMap({ button(in: $0.contentView) }).first else { return }
        NSApp.activate()
        statusButton.performClick(nil)
    }
}
