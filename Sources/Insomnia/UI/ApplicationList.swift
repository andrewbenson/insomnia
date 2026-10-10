import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Reads metadata only; selecting or dropping a bundle never launches it.
enum ApplicationBundles {
    /// Names for bundled defaults even when Launch Services cannot find an
    /// installation. Live bundle metadata takes precedence.
    static let knownNames = [
        "com.tinyspeck.slackmacgap": "Slack",
        "net.whatsapp.WhatsApp": "WhatsApp",
        "com.hnc.Discord": "Discord",
        "com.t3tools.t3code": "T3 Code",
        "com.t3tools.t3code.reasoning": "T3 Code (Reasoning)",
        "com.conductor.app": "Conductor",
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "iTerm2",
        "com.mitchellh.ghostty": "Ghostty",
        "dev.warp.Warp-Stable": "Warp",
        "com.google.Chrome": "Google Chrome",
        "org.chromium.Chromium": "Chromium",
        "company.thebrowser.Browser": "Arc",
        "com.docker.docker": "Docker Desktop",
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "dev.zed.Zed": "Zed",
        "com.google.antigravity": "Google Antigravity",
        "com.anthropic.claudefordesktop": "Claude",
        "com.openai.codex": "ChatGPT",
        "io.tailscale.ipn.macsys": "Tailscale",
        "ai.elementlabs.lmstudio": "LM Studio",
        "com.electron.ollama": "Ollama",
    ]

    static func identifier(at url: URL) -> String? {
        guard url.isFileURL, url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url.resolvingSymlinksInPath()),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              let identifier = bundle.bundleIdentifier,
              !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return identifier
    }

    static func identifiers(in urls: [URL]) -> [String] {
        var seen = Set<String>()
        return urls.compactMap(identifier).filter { seen.insert($0).inserted }
    }

    @MainActor
    static func presentation(for identifier: String) -> (name: String, icon: NSImage, isInstalled: Bool) {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == identifier }
        let candidate = running?.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        let url = candidate.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        let bundle = url.flatMap { Bundle(url: $0) }
        let name = running?.localizedName
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? knownNames[identifier]
            ?? url?.deletingPathExtension().lastPathComponent
            ?? identifier
        let icon = running?.icon ?? url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 32, height: 32))
        return (name, icon, url != nil || running != nil)
    }
}

/// One editor shared by the pause and protected-app lists. Only identifiers
/// are persisted, so missing apps remain editable after moving machines.
struct ApplicationList: View {
    let title: String
    let items: [String]
    let add: (String) -> Void
    let remove: (String) -> Void

    @State private var isDropTarget = false
    @State private var newIdentifier = ""
    @State private var showIdentifierEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("Add applications with + or drag them here.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(items, id: \.self) { identifier in
                                applicationRow(identifier)
                                if identifier != items.last { Divider().padding(.leading, 46) }
                            }
                        }
                    }
                    .frame(height: min(CGFloat(items.count) * 46, 184))
                }
                Divider()
                HStack(spacing: 12) {
                    Button(action: chooseApplications) { Image(systemName: "plus") }
                        .help("Add applications")
                        .accessibilityLabel("Add applications to \(title)")
                    Menu {
                        ForEach(RunningApps.candidates(excluding: items), id: \.bundleID) { app in
                            Button(app.name) { add(app.bundleID) }
                        }
                    } label: {
                        Text("Running apps")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Spacer()
                    Text("Drop apps here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isDropTarget ? 2 : 1)
            }
            .dropDestination(for: URL.self) { urls, _ in
                let identifiers = ApplicationBundles.identifiers(in: urls)
                identifiers.filter { !items.contains($0) }.forEach(add)
                return !identifiers.isEmpty
            } isTargeted: { isDropTarget = $0 }

            SettingsDisclosure("Add by bundle identifier", isExpanded: $showIdentifierEntry) {
                HStack {
                    TextField("com.example.application", text: $newIdentifier)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addIdentifier)
                    Button("Add", action: addIdentifier)
                        .disabled(newIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
    }

    private func applicationRow(_ identifier: String) -> some View {
        let app = ApplicationBundles.presentation(for: identifier)
        return HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(app.name).lineLimit(1)
                    if !app.isInstalled {
                        Text("Not installed").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Text(identifier).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .help(identifier)
            Spacer(minLength: 4)
            Button { remove(identifier) } label: {
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove \(app.name)")
            .accessibilityLabel("Remove \(app.name) from \(title)")
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
    }

    private func chooseApplications() {
        let panel = NSOpenPanel()
        panel.title = "Add applications"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK else { return }
        ApplicationBundles.identifiers(in: panel.urls).filter { !items.contains($0) }.forEach(add)
    }

    private func addIdentifier() {
        let identifier = newIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return }
        if !items.contains(identifier) { add(identifier) }
        newIdentifier = ""
    }
}
