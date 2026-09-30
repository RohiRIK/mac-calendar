import AppKit
import SwiftUI

// Menu-style building blocks modeled on the system Wi-Fi / Control Center menus:
// full-width rows, rounded hover highlight, 8 pt text inset, no cards or borders.

/// Clickable menu row with a rounded hover highlight.
struct MenuRow<Content: View>: View {
    var action: (() -> Void)?
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) { content }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .background {
                if hovering && action != nil {
                    RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                }
            }
            .contentShape(.rect)
            .onHover { hovering = $0 }
            .onTapGesture { action?() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(action != nil ? .isButton : [])
    }
}

/// Plain command row ("IP Settings…") with an optional key hint, like a menu item.
struct CommandRow: View {
    let title: String
    var key: String?
    let action: () -> Void

    var body: some View {
        MenuRow(action: action) {
            Text(title)
            Spacer()
            if let key { Text(key).foregroundStyle(.tertiary) }
        }
        .help(key.map { "\(title) (\($0))" } ?? title)
    }
}


struct MenuDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 8).padding(.vertical, 5)
    }
}

/// Resizes the menu bar window to the panel's height, keeping its top edge under the menu bar.
/// A `MenuBarExtra` window grows with its content but does not shrink until later, and then shrinks
/// toward its bottom edge, so a shorter page (6-week month → 5-week month) drops away from the menu bar.
struct FitWindowHeight: NSViewRepresentable {
    let height: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard let window = view.window, height > 0 else { return }
        let content = window.contentRect(forFrameRect: window.frame)
        guard abs(content.height - height) > 0.5 else { return }
        let fitted = NSRect(x: content.minX, y: content.maxY - height, width: content.width, height: height)
        window.setFrame(window.frameRect(forContentRect: fitted), display: true)
    }
}
