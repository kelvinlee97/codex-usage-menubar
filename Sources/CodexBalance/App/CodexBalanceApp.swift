import SwiftUI

@main
struct CodexBalanceApp: App {
    @StateObject private var store: UsageStore

    init() {
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
