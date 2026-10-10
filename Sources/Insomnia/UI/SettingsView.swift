import AppKit
import SwiftUI

/// The settings window (spec 10). Every change is written straight through
/// `manager.config` to config.json.
struct SettingsView: View {
    enum Page: String, CaseIterable, Identifiable {
        case general = "General"
        case lidPower = "Lid & Power"
        case apps = "Apps"
        case network = "Network"

        var id: Self { self }
        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .lidPower: "laptopcomputer"
            case .apps: "square.stack.3d.up"
            case .network: "wifi"
            }
        }
    }

    let manager: SessionManager
    let secrets: any HotspotSecretStore
    let locationPermission: LocationPermission
    /// Launch at login as macOS reports it, not as config.json remembers it.
    let loginItem: LoginItem

    @State private var newPreset = ""
    @State private var presetError: String?
    @State private var selectedPage: Page? = .lidPower
    @State private var showProtectedApps = true
    @State private var showLidHelp = false
    @State private var showDimmingDetails = false
    @State private var showAutomaticPausing = false
    @State private var showAppNap = false
    @State private var showTmux = false
    @State private var showPrivacy = false
    @State private var showConfigFile = false
    @State private var newTmuxTarget = ""
    /// The password field, saving, what was saved, and the notice under
    /// the field.
    @State private var hotspot = HotspotPasswordField()
    /// Names of the apps the automatic lid-close scope would freeze right
    /// now (the freeze list excluded); refreshed on appear and toggle.
    @State private var wouldFreeze: [String] = []

    init(manager: SessionManager, secrets: any HotspotSecretStore, locationPermission: LocationPermission, loginItem: LoginItem, initialPage: Page = .lidPower) {
        self.manager = manager
        self.secrets = secrets
        self.locationPermission = locationPermission
        self.loginItem = loginItem
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Page.allCases, selection: $selectedPage) { page in
                Label(page.rawValue, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(150)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Text((selectedPage ?? .lidPower).rawValue)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                ScrollView {
                    GlassEffectContainer(spacing: 20) {
                        VStack(alignment: .leading, spacing: 20) {
                            pageContent
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .toggleStyle(.switch)
                .textFieldStyle(.roundedBorder)
                .buttonStyle(.glass)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 680, height: 480)
        .onAppear {
            loadPassword()
            refreshWouldFreeze()
            // The user may have approved or removed the item in System
            // Settings since the launch-time check (LoginItem also re-reads
            // whenever the app becomes active, for a window left open).
            loginItem.refresh()
        }
        // The failover may find the saved password unreadable while the
        // window is open, and an SSID edit makes the notice about another
        // hotspot's item: the notice follows both.
        .onChange(of: manager.services?.status.hotspotPasswordReport) { recheckPassword() }
        .onChange(of: HotspotSSID.normalized(manager.config.hotspotSSID)) { recheckPassword() }
        // The preview depends on the toggle, both lists and what is running:
        // recompute on any config change and whenever an app launches or quits.
        .onChange(of: manager.config) { refreshWouldFreeze() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refreshWouldFreeze() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refreshWouldFreeze() }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage ?? .lidPower {
        case .general:
            appSection
            sessionSection
        case .lidPower:
            lidSection
            powerSection
        case .apps:
            Picker("Application list", selection: $showProtectedApps) {
                Text("Paused").tag(false)
                Text("Protected").tag(true)
            }
            .pickerStyle(.segmented)
            if showProtectedApps { agentSection } else { pauseSection }
        case .network:
            networkSection
        }
    }

    // MARK: Bindings

    private func bind<T: Equatable>(_ keyPath: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(
            get: { manager.config[keyPath: keyPath] },
            set: { value in
                guard manager.config[keyPath: keyPath] != value else { return }
                manager.config[keyPath: keyPath] = value
                save()
            }
        )
    }

    private func save() {
        do {
            try manager.store.saveConfig(manager.config)
        } catch {
            Log.error("could not save config: \(error.localizedDescription)")
        }
    }

    private func update(_ change: (inout Config) -> Void) {
        var c = manager.config
        change(&c)
        guard c != manager.config else { return }
        manager.config = c
        save()
    }

    /// The floor steppers go through the Config setters, which move the
    /// other floor when the two would cross.
    private var lowPowerFloor: Binding<Int> {
        Binding(get: { manager.config.lowPowerFloor }, set: { v in update { $0.setLowPowerFloor(v) } })
    }

    private var endFloor: Binding<Int> {
        Binding(get: { manager.config.endFloor }, set: { v in update { $0.setEndFloor(v) } })
    }

    // MARK: Sections

    private var sessionSection: some View {
        SettingsCard("Session") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))], spacing: 8) {
                ForEach(manager.config.presets, id: \.self) { p in
                    HStack(spacing: 6) {
                        Text(chipLabel(for: p)).monospacedDigit()
                        if p == manager.config.defaultPreset {
                            Image(systemName: "checkmark").font(.caption).foregroundStyle(.secondary)
                                .accessibilityLabel("Default preset")
                        }
                        Spacer(minLength: 0)
                        removeButton { update { $0.presets.removeAll { $0 == p } } }
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            HStack {
                TextField("Add preset", text: $newPreset)
                    .textFieldStyle(.roundedBorder)
                    .help("Examples: 30m, 2h, 1h30m, 3d")
                    .onSubmit(addPreset)
                Button("Add", action: addPreset)
                    .disabled(DurationParser.seconds(from: newPreset) == nil)
            }
            if let presetError {
                Text(presetError).font(.caption).foregroundStyle(.red)
            }
            Picker("Default preset", selection: bind(\.defaultPreset)) {
                ForEach(manager.config.presets, id: \.self) { p in
                    Text(chipLabel(for: p)).tag(p)
                }
                if !manager.config.presets.contains(manager.config.defaultPreset) {
                    Text(chipLabel(for: manager.config.defaultPreset)).tag(manager.config.defaultPreset)
                }
            }
            LabeledContent("Maximum session") {
                Text(chipLabel(for: manager.config.maxDuration)).foregroundStyle(.secondary)
            }
        }
    }

    private func addPreset() {
        guard let s = DurationParser.seconds(from: newPreset) else { return }
        guard s <= manager.config.maxDuration else {
            presetError = "Presets cannot exceed \(chipLabel(for: manager.config.maxDuration))."
            return
        }
        presetError = nil
        update {
            if !$0.presets.contains(s) {
                $0.presets.append(s)
                $0.presets.sort()
            }
        }
        newPreset = ""
    }

    /// Under the mute toggle and in the README. Apple Platform Security,
    /// "Hardware microphone disconnect".
    static let microphoneNote = "On Mac laptops with Apple silicon or a T2 chip, closing the lid disconnects the built-in microphone in hardware. Recording a meeting with the lid closed needs AirPods or an external mic."

    private var lidSection: some View {
        SettingsCard("Lid-close actions") {
            // The one-time lid-close update, for a user who has
            // notifications turned off. Stays until dismissed.
            if let notice = manager.config.lidCloseDefaultsNotice {
                HStack(alignment: .firstTextBaseline) {
                    Text(notice.settingsLine)
                        .font(.callout)
                    Spacer()
                    Button("Dismiss") { manager.dismissLidCloseNotice() }
                }
            }
            SettingsToggle("Darken display and keyboard", isOn: bind(\.darkenDisplayOnLidClose))
            if !manager.darkenRefusals.isEmpty {
                SettingsDisclosure("Dimming has limited support on this Mac", isExpanded: $showDimmingDetails) {
                    ForEach(manager.darkenRefusals, id: \.self) { reason in
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.orange)
            }
            SettingsToggle("Mute audio on lid close", isOn: bind(\.muteOnLidClose))
            SettingsToggle("Low Power Mode while the lid is closed", isOn: bind(\.lowPowerOnLidClose))
                // A floor input: apply it now if the lid is already closed.
                .onChange(of: manager.config.lowPowerOnLidClose) { manager.services?.reevaluateFloors() }
            SettingsDisclosure("About lid-close actions", isExpanded: $showLidHelp) {
                Text(Self.microphoneNote)
                Text("The display brightness and keyboard backlight are saved, set to zero and restored when the lid opens. If Insomnia is not running when you open the lid, press the brightness-up key.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var pauseSection: some View {
        SettingsCard(footer: "Listed apps pause when the lid closes and resume when it opens. Protected apps are never paused.") {
            ApplicationList(
                title: "Pause with lid closed",
                items: manager.config.freezeList,
                add: { id in update { if !$0.freezeList.contains(id) { $0.freezeList.append(id) } } },
                remove: { id in update { $0.freezeList.removeAll { $0 == id } } }
            )
            SettingsDisclosure("Automatic pausing", isExpanded: $showAutomaticPausing) {
                SettingsToggle("Pause other apps too", isOn: bind(\.freezeAllApps))
                if manager.config.freezeAllApps {
                    Text(wouldFreezeText).font(.caption).foregroundStyle(.secondary)
                }
                SettingsToggle("Pause Docker when no containers are running", isOn: bind(\.dockerRule))
                Text("Protected apps, Apple apps, editors, terminals, browsers, meeting apps and background services are excluded from automatic pausing. An explicit entry above overrides built-in protection. A container that starts just before Docker is paused may also be paused.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var agentSection: some View {
        SettingsCard(footer: "These apps are excluded from pausing, including when they also appear in the pause list.") {
            ApplicationList(
                title: "Protected apps",
                items: manager.config.agentList,
                add: { id in update { if !$0.agentList.contains(id) { $0.agentList.append(id) } } },
                remove: { id in update { $0.agentList.removeAll { $0 == id } } }
            )
            SettingsDisclosure("App Nap", isExpanded: $showAppNap) {
                SettingsToggle("Disable App Nap during sessions", isOn: bind(\.disableAppNapForAgents))
                Text("Prevents these apps from being throttled. Their previous preferences are restored when the session ends.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var wouldFreezeText: String {
        guard manager.config.freezeAllApps else { return "Would freeze now: the list above only" }
        return wouldFreeze.isEmpty ? "Would freeze now: nothing else" : "Would freeze now: \(wouldFreeze.joined(separator: ", "))"
    }

    /// Same planner as the lid-close action, over the apps running now.
    private func refreshWouldFreeze() {
        let selfId = Bundle.main.bundleIdentifier ?? Paths.bundleIdentifier
        wouldFreeze = FreezePlanner.automaticCandidates(config: manager.config, apps: Freezer.runningApps(), selfBundleId: selfId).map(\.name)
    }

    private var powerSection: some View {
        SettingsCard("Battery and thermal") {
            Stepper(value: lowPowerFloor, in: 0...100, step: Config.floorStep) {
                LabeledContent("Low Power Mode below", value: "\(manager.config.lowPowerFloor)%")
            }
            Stepper(value: endFloor, in: 0...Config.maxEndFloor, step: Config.floorStep) {
                LabeledContent("End session below", value: "\(manager.config.endFloor)%")
            }
            Text("0 turns the battery end off. The end floor stays below the Low Power Mode floor. Moving one onto the other moves it along.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsToggle("Apply thermal limits", isOn: bind(\.thermalRules))
                .help("Low Power Mode when hot; end the session at critical temperature")
        }
    }

    private var networkSection: some View {
        SettingsCard("Network failover") {
            TextField("Hotspot SSID", text: bind(\.hotspotSSID))
            HStack {
                SecureField("Hotspot password", text: Binding(get: { hotspot.password }, set: { hotspot.edit($0) }))
                    .onSubmit(savePassword)
                Button(hotspot.buttonTitle(ssid: manager.config.hotspotSSID), action: savePassword)
                    .disabled(hotspot.password.isEmpty || hotspot.saving)
            }
            if let notice = hotspot.notice {
                Text(notice).font(.caption).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Location: \(locationPermission.statusDescription)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if locationPermission.isDenied {
                        Button("Open Location Services") {
                            locationPermission.openLocationServicesSettings()
                        }
                    }
                }
                // macOS has no when-in-use grant for Mac apps: the grant is
                // recorded as Location Services access for Insomnia.
                Text("Used only to read Wi-Fi network names.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            SettingsDisclosure("tmux automation", isExpanded: $showTmux) {
            Stepper(value: nudgeSeconds, in: 10...900, step: 10) {
                LabeledContent("Nudge tmux after", value: "\(Int(manager.config.nudgeThreshold)) s offline")
            }
            Text("After that long offline, Insomnia types \"continue\" into each pane listed below. Only a pane you have marked with this tmux command is nudged. Mark a dedicated pane, not one you type in.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(TmuxNudge.markCommand())
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            SettingsToggle("Press Enter after continue", isOn: bind(\.tmuxNudgePressesEnter))
            Text("Enter submits whatever is already typed in that pane, including a line that was never finished. When off, \"continue\" is typed and nothing submits it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(manager.config.tmuxTargets, id: \.self) { t in
                HStack {
                    Text(t).font(.system(.body, design: .monospaced))
                    Spacer()
                    removeButton {
                        update { $0.tmuxTargets.removeAll { $0 == t } }
                    }
                }
            }
            HStack {
                TextField("tmux target (session:window.pane)", text: $newTmuxTarget)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTmuxTarget)
                Button("Add", action: addTmuxTarget)
                    .disabled(newTmuxTarget.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            }
            SettingsDisclosure("Password and privacy", isExpanded: $showPrivacy) {
                Text("The password stays in your login Keychain. After reinstalling an ad-hoc signed build, enter it again. Location permission is used only to read Wi-Fi network names; Insomnia never requests location updates.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var nudgeSeconds: Binding<Int> {
        Binding(
            get: { Int(manager.config.nudgeThreshold) },
            set: { seconds in update { $0.nudgeThreshold = TimeInterval(seconds) } }
        )
    }

    /// Fills the field when the window appears (`loadForField`).
    private func loadPassword() {
        let request = hotspot.startLoad(ssid: manager.config.hotspotSSID)
        Task {
            await Self.loadForField(request, secrets: secrets) {
                hotspot.finishRead($0, ssid: manager.config.hotspotSSID, password: $1.password, notice: $1.notice)
            }
        }
    }

    /// Reads the notice again for the hotspot configured now, without a
    /// prompt and without touching the field.
    private func recheckPassword() {
        recheckPassword(hotspot.startRead(ssid: manager.config.hotspotSSID))
    }

    private func recheckPassword(_ request: HotspotPasswordField.Read) {
        Task {
            await Self.readForField(
                request,
                first: { await recheckedNotice() },
                again: { await recheckedNotice() },
                finish: { hotspot.finishRead($0, ssid: manager.config.hotspotSSID, password: $1.password, notice: $1.notice) }
            )
        }
    }

    private func recheckedNotice() async -> (password: String, notice: String?) {
        let notice = await Self.hotspotNotice(
            reported: manager.services?.status.hotspotPasswordReport,
            ssid: manager.config.hotspotSSID,
            reread: secrets.peek
        )
        return ("", notice)
    }

    /// Loads the saved password into the field, without a keychain prompt.
    /// An item this build may not read leaves the field empty and says
    /// why, so the user re-enters it; saving then replaces the item (see
    /// `KeychainStore`). The read can wait behind a save, so a field
    /// edited meanwhile is kept, even one typed in and emptied again, and
    /// a password read for an SSID edited away meanwhile is not shown: the
    /// SSID configured now is read instead. That read is a peek: the
    /// account a later save moves the password from stays the one the
    /// window loaded, as it does for any SSID edit, so the old SSID's item
    /// is still removed.
    static func loadForField(
        _ request: HotspotPasswordField.Read,
        secrets: any HotspotSecretStore,
        finish: @MainActor (HotspotPasswordField.Read, (password: String, notice: String?)) -> HotspotPasswordField.ReadAnswer
    ) async {
        await readForField(
            request,
            first: { await loadedPassword(secrets.load) },
            again: { await loadedPassword(secrets.peek) },
            finish: finish
        )
    }

    /// Runs a load or recheck for the field: `first` reads, and `finish`
    /// takes the answer. While the SSID was edited during the read,
    /// `finish` drops the answer, and `again` reads the SSID configured
    /// now, until an answer is used or dropped.
    static func readForField(
        _ request: HotspotPasswordField.Read,
        first: @MainActor () async -> (password: String, notice: String?),
        again: @MainActor () async -> (password: String, notice: String?),
        finish: @MainActor (HotspotPasswordField.Read, (password: String, notice: String?)) -> HotspotPasswordField.ReadAnswer
    ) async {
        var answer = await first()
        var request = request
        while case let .readAgain(next) = finish(request, answer) {
            request = next
            answer = await again()
        }
    }

    /// A prompt-free load: the password for the field, or an empty field
    /// and a notice saying why it cannot be shown.
    static func loadedPassword(_ load: () async throws -> String?) async -> (password: String, notice: String?) {
        do {
            return (try await load() ?? "", nil)
        } catch let error as KeychainError {
            return ("", error.problem.settingsNotice)
        } catch {
            return ("", HotspotPasswordProblem.error(error.localizedDescription).settingsNotice)
        }
    }

    /// The notice under the password field for the hotspot `ssid`
    /// configured now. A problem the failover reports about that hotspot
    /// shows as it is. A report about another SSID, one edited away since,
    /// does not apply, and a cleared report is not taken as "readable": it
    /// also clears when the session ends. Then the keychain is read again,
    /// without a prompt, and the notice says what that read finds. The
    /// field is left as the user has it, and the reread is a peek: a load
    /// would make an SSID typed since then the account a save moves the
    /// password from, and the old SSID's item would stay behind.
    static func hotspotNotice(reported: HotspotPasswordReport?, ssid: String, reread: () async throws -> String?) async -> String? {
        if let problem = reported?.problem(for: ssid) { return problem.settingsNotice }
        return await loadedPassword(reread).notice
    }

    /// Saves, or clears for an empty field. The button shows "Saving..."
    /// until the keychain answers; one save at a time.
    private func savePassword() {
        guard hotspot.startSave() else { return }
        if !HotspotSSID.normalized(manager.config.hotspotSSID).isEmpty {
            locationPermission.requestWhenInUse()
        }
        let password = hotspot.password
        Task {
            let outcome = await Self.storePassword(password, in: secrets)
            let recheck = hotspot.finishSave(outcome, ssid: manager.config.hotspotSSID)
            // The failover's report first, so the recheck reads it as the
            // save left it.
            Self.passwordStored(outcome, configuredSSID: manager.config.hotspotSSID, services: manager.services)
            if let recheck { recheckPassword(recheck) }
        }
    }

    /// A save or clear answered. The failover's report goes, and the next
    /// outage notifies afresh, unless the report is about the hotspot
    /// configured now and the save neither stored for it nor removed its
    /// item (`HotspotPasswordReport.stands`).
    static func passwordStored(_ outcome: HotspotStoreOutcome, configuredSSID: String, services: AppServices?) {
        guard case let .stored(stored) = outcome else { return }
        services?.hotspotPasswordChanged(stored.change, configuredSSID: configuredSSID)
    }

    /// Saves `password`, or clears the saved one when it is empty, and
    /// returns what was stored under which SSID and which loaded account
    /// it removed, or the notice for a failure. The store does the keychain work on `KeychainQueue`, so a
    /// save waiting on a keychain dialog waits there while the main actor
    /// (the battery floor, the deadline timer, End) carries on.
    static func storePassword(_ password: String, in secrets: any HotspotSecretStore) async -> HotspotStoreOutcome {
        do {
            let change = if password.isEmpty {
                try await secrets.delete()
            } else {
                try await secrets.save(password)
            }
            return .stored(.init(ssid: change.ssid, password: password, removed: change.removed))
        } catch {
            Log.error("could not save hotspot password: \(error.localizedDescription)")
            return .failed(notice: "Could not save the hotspot password: \(error.localizedDescription)")
        }
    }

    private func addTmuxTarget() {
        let t = newTmuxTarget.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        update { if !$0.tmuxTargets.contains(t) { $0.tmuxTargets.append(t) } }
        newTmuxTarget = ""
    }

    private var appSection: some View {
        SettingsCard("App") {
            SettingsToggle("Launch at login", isOn: launchAtLogin)
            loginItemNote
            SettingsDisclosure("Configuration file", isExpanded: $showConfigFile) {
                Text(manager.paths.configFile.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if LidSimulationBuild.isCompiledIn {
                Text(LidSimulationBuild.marker)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// The switch shows what macOS has on file (`LoginItem.isRegistered`:
    /// enabled or waiting for approval), so a registration that an upgrade
    /// dropped reads as off even while config.json still says on, and a
    /// pending one can be withdrawn by turning the switch off; the note
    /// below explains the state.
    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { loginItem.isRegistered },
            set: { on in
                // Persist only what macOS accepted; a refused change leaves
                // the flag as it was and its error on screen.
                update { config in _ = loginItem.set(on, config: &config) }
            }
        )
    }

    /// One line under the switch: the last error, a pending approval with
    /// the button that opens Login Items, or a flag macOS no longer honours.
    @ViewBuilder
    private var loginItemNote: some View {
        if let error = loginItem.error {
            Text("Login item: \(error)").font(.caption).foregroundStyle(.red)
        } else if loginItem.needsApproval {
            HStack {
                Text("Waiting for approval in System Settings > General > Login Items. Turn the switch off to withdraw it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Open Login Items") { loginItem.openLoginItems() }
            }
        } else if manager.config.launchAtLogin, !loginItem.isRegistered {
            Text("Login item: macOS reports it \(loginItem.status.description). Turn the switch on to register it again.")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Remove")
    }
}

/// Running apps offered by "Add running app…": everything with a bundle id
/// that is not Apple's own.
@MainActor
enum RunningApps {
    struct Entry: Hashable {
        let bundleID: String
        let name: String
    }

    static func candidates(excluding: [String]) -> [Entry] {
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        var out: [Entry] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, !id.hasPrefix("com.apple."), id != me,
                  app.activationPolicy != .prohibited,
                  !excluding.contains(id), !seen.contains(id) else { continue }
            seen.insert(id)
            out.append(Entry(bundleID: id, name: app.localizedName ?? id))
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Name of a running app for a bundle id, or the last path component.
    static func displayName(for bundleID: String) -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let name = app.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
