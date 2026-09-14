import Darwin
import SwiftUI

@main
struct CodexBalanceApp: App {
    @StateObject private var store: UsageStore

    init() {
        // The Codex subprocess can die between polls; writing to its stdin then raises SIGPIPE,
        // whose default disposition kills this app outright rather than surfacing an error.
        // Ignoring it turns that case into an EPIPE the client can catch and recover from.
        signal(SIGPIPE, SIG_IGN)
        SelfCheck.runIfRequested()
        _store = StateObject(wrappedValue: UsageStore())
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(store: store)
        } label: {
            HStack(spacing: 4) {
                menuBarIcon
                    .frame(width: 18, height: 18)
                Text(store.menuBarText)
                    .monospacedDigit()
            }
                .opacity(store.isShowingStaleData ? 0.55 : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.accessibilityLabel)
                .task { store.start() }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: Image {
        Image(systemName: "gauge.with.dots.needle.67percent")
    }
}
