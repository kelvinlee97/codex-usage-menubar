import AppKit
import ServiceManagement
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Codex Usage")
                    .font(.headline)
                Spacer()
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Refreshing Codex usage")
                } else {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh usage (⌘R)")
                    .accessibilityLabel("Refresh Codex usage")
                }
            }

            if let snapshot = store.snapshot {
                if let primary = snapshot.primary {
                    QuotaRow(window: primary)
                }
                if let secondary = snapshot.secondary {
                    QuotaRow(window: secondary)
                }
                if let balance = snapshot.formattedCreditBalance {
                    LabeledContent("Credit balance", value: balance)
                        .font(.callout)
                }
                Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if snapshot.primary == nil && snapshot.secondary == nil {
                    Text("No usage windows were returned for this account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if store.isRefreshing {
                ProgressView("Loading usage…")
            }

            if let message = store.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Label(store.snapshot == nil ? "Unable to load usage" : "Last refresh failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    if let snapshot = store.snapshot {
                        Text("Showing data from \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    }
                    Text(message)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isRefreshing)
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        try LoginItemManager.setEnabled(enabled)
                        loginItemError = nil
                    } catch {
                        launchAtLogin = LoginItemManager.isEnabled
                        loginItemError = error.localizedDescription
                    }
                }

            if LoginItemManager.requiresApproval {
                Button("Open Login Items Settings") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Open Codex Usage") {
                    NSWorkspace.shared.open(
                        URL(string: "https://chatgpt.com/codex/cloud/settings/analytics#usage")!
                    )
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            Text("Unofficial; not affiliated with OpenAI.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
            Task { await store.refreshIfStale() }
        }
    }
}

private struct QuotaRow: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(window.title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(window.remainingPercent)% left")
                    .monospacedDigit()
            }
            ProgressView(value: Double(window.remainingPercent), total: 100)
                .tint(progressColor)
                .accessibilityLabel("\(window.title) remaining")
                .accessibilityValue("\(window.remainingPercent) percent")
            if let resetsAt = window.resetsAt {
                HStack(spacing: 3) {
                    if window.hasReset() {
                        // Without this the relative style counts upward: "Resets 4 minutes ago".
                        Text("Resetting…")
                    } else {
                        Text("Resets")
                        Text(resetsAt, style: .relative)
                    }
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityLabel("Resets \(resetsAt.formatted(date: .long, time: .shortened))")
            }
        }
    }

    private var progressColor: Color {
        if window.remainingPercent < 10 { return .red }
        if window.remainingPercent <= 20 { return .orange }
        return .accentColor
    }
}
