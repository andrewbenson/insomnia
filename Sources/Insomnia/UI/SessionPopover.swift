import AppKit
import SwiftUI

/// Native controls live in the system popover, never inside the status-item label.
/// Editing has no session side effects; only the explicit action buttons mutate it.
struct SessionPopover: View {
    let manager: SessionManager
    let status: any StatusSource
    @Environment(\.openSettings) private var openSettings
    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 0
    @State private var busy = false
    @State private var browserToRelaunch: ThrottledBrowser?

    private var duration: TimeInterval {
        TimeInterval(days) * 86_400 + TimeInterval(hours) * 3_600 + TimeInterval(minutes) * 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(manager.isActive ? "Awake · \(manager.remainingText) remaining" : "Insomnia")
                .font(.headline)
            Form {
                HStack {
                    durationField("Days", value: $days)
                    durationField("Hours", value: $hours)
                    durationField("Minutes", value: $minutes)
                }
            }
            HStack {
                Button(manager.isActive ? "Add Time" : "Start") {
                    let seconds = duration
                    perform {
                        if manager.isActive { await manager.extend(by: seconds) }
                        else { await manager.start(duration: seconds) }
                    }
                }
                .disabled(busy || duration <= 0 || days < 0 || hours < 0 || minutes < 0 || duration > 30 * 86_400)
                if manager.isActive {
                    Button("End Session", role: .destructive) {
                        perform { _ = await manager.end(reason: .user) }
                    }
                    .disabled(busy)
                }
                if busy { ProgressView().controlSize(.small) }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(StatusMenu.liveItems(manager: manager, status: status).enumerated()), id: \.offset) { _, item in
                        statusRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            HStack {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            status.refreshOnDemand()
            let initial = Int(manager.isActive ? 30 * 60 : manager.config.defaultPreset)
            days = initial / 86_400
            hours = initial % 86_400 / 3_600
            minutes = initial % 3_600 / 60
        }
        .alert("Relaunch browser?", isPresented: Binding(
            get: { browserToRelaunch != nil },
            set: { if !$0 { browserToRelaunch = nil } }
        )) {
            Button("Relaunch") {
                if let browser = browserToRelaunch { status.relaunchUnthrottled(browser) }
                browserToRelaunch = nil
            }
            Button("Cancel", role: .cancel) { browserToRelaunch = nil }
        } message: {
            Text("The browser will quit. Its windows return only through its own session restore.")
        }
    }

    private func durationField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption)
            TextField(label, value: value, format: .number.grouping(.never))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder private func statusRow(_ item: StatusMenu.Item) -> some View {
        switch item.kind {
        case .info: Text(item.title).font(.caption).foregroundStyle(.secondary)
        case .warning: Text(item.title).font(.caption).foregroundStyle(.orange)
        case let .relaunchBrowser(browser):
            Button(item.title) { browserToRelaunch = browser }
        case let .stopWaitingForOutput(output):
            Button(item.title) { perform { await manager.stopWaitingForOutput(output) } }.disabled(busy)
        case .separator, .settings, .quit: EmptyView()
        }
    }

    private func perform(_ action: @escaping @MainActor () async -> Void) {
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            await action()
            busy = false
        }
    }
}
