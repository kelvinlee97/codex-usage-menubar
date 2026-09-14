import AppKit
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
        let path = "/Applications/ChatGPT.app/Contents/Resources/chatgptTemplate@2x.png"
        guard let image = NSImage(contentsOfFile: path) else {
            return Image(systemName: "sparkles")
        }
        image.isTemplate = true
        return Image(nsImage: image)
    }
}
