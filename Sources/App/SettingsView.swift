import SwiftUI
import BeamletCore
import ServiceManagement
import UserNotifications

enum SettingsTab: String, CaseIterable {
    case general, connection, about

    var title: String {
        switch self {
        case .general: return "General"
        case .connection: return "Connection"
        case .about: return "About"
        }
    }
}

struct SettingsView: View {
    @AppStorage("settingsTab") private var selection: SettingsTab = .general
    @ObservedObject var preferences: Preferences
    @ObservedObject var session: SessionController
    @ObservedObject var login: LoginItem
    @ObservedObject var updates: UpdateController
    @ObservedObject var power: PowerManager
    @State private var showDiagnostics = false
    @State private var setupCopied = false
    @FocusState private var focusedTab: SettingsTab?

    @State private var showSetup = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                sidebarButton(.general, symbol: "slider.horizontal.3")
                sidebarButton(.connection, symbol: "antenna.radiowaves.left.and.right")
                sidebarButton(.about, symbol: "info.circle")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .frame(width: 170)
            .frame(maxHeight: .infinity)
            .onMoveCommand { direction in
                let tabs = SettingsTab.allCases
                guard let index = tabs.firstIndex(of: focusedTab ?? selection) else { return }
                let next: Int
                switch direction {
                case .up: next = max(0, index - 1)
                case .down: next = min(tabs.count - 1, index + 1)
                default: return
                }
                selection = tabs[next]
                focusedTab = tabs[next]
            }
            .background {
                SettingsSidebarMaterial()
                    .ignoresSafeArea(.container, edges: .top)
            }
            Divider().ignoresSafeArea(.container, edges: .top)
            VStack(alignment: .leading, spacing: 0) {
                Text(selection.title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 4)
                Group {
                    switch selection {
                    case .general: general
                    case .connection: connection
                    case .about: about
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { BeamletSurface().ignoresSafeArea(.container, edges: .top) }
        }
        .frame(width: 700, height: 540)
        .tint(BeamletStyle.accent)
        .background(SettingsWindowChrome())
        .onAppear { login.refresh() }
    }

    private func sidebarButton(_ tab: SettingsTab, symbol: String) -> some View {
        Button {
            selection = tab
            focusedTab = tab
        } label: {
            sidebarLabel(tab.title, symbol: symbol)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .padding(.horizontal, 9)
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(SettingsSidebarButtonStyle(selected: selection == tab))
        .focusable()
        .focused($focusedTab, equals: tab)
        .focusEffectDisabled()
        .overlay {
            if focusedTab == tab {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.primary.opacity(0.4), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private func sidebarLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text(title).font(.system(size: 13))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var general: some View {
        settingsForm {
            Section("Startup") {
                Toggle(isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) })) {
                    settingLabel("Launch at login", detail: "Keep Beamlet in your menu bar when you sign in.")
                }
                .accessibilityLabel("Launch at login")
                .accessibilityHint("Keep Beamlet in your menu bar when you sign in.")
                if let message = login.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    Button("Open Login Items settings") { SMAppService.openSystemSettingsLoginItems() }
                }
                Toggle(isOn: $preferences.autoStart) {
                    settingLabel("Connect automatically", detail: "Start Remote Control when Beamlet opens. Pressing Stop keeps it stopped until you start again.")
                }
                .accessibilityLabel("Connect automatically")
                .accessibilityHint("Pressing Stop keeps it stopped until you start again.")
            }
            Section("Power") {
                Toggle(isOn: $preferences.keepAwake) {
                    settingLabel("Keep Mac awake", detail: "While Remote Control runs and your Mac is plugged in. The display can still sleep.")
                }
                .accessibilityLabel("Keep Mac awake")
                .accessibilityHint("Only while Remote Control runs and your Mac is plugged in.")
                if power.preventingSleep {
                    Label("Keeping this Mac awake on power", systemImage: "bolt")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Closing the lid can still put your Mac to sleep.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Notifications") {
                NotificationSettings(preferences: preferences, services: session.services)
            }
        }
    }

    private var connection: some View {
        settingsForm {
            Section("Workspace") {
                HStack(spacing: 16) {
                    settingLabel("Starting folder", detail: preferences.displayFolder, path: true)
                    Spacer(minLength: 0)
                    Button("Choose…") { chooseFolder() }
                        .accessibilityLabel("Choose starting folder")
                        .disabled(preferences.requiresExplicitAccess && session.isBusy)
                }
                if let active = session.activeFolder, active != preferences.folderURL.path {
                    Text("Your new folder will be used the next time you start Remote Control.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Claude Code") {
                HStack(spacing: 16) {
                    settingLabel("Installed executable", detail: executableLabel, path: true)
                    Spacer(minLength: 0)
                    Button("Choose…") { chooseExecutable() }
                        .accessibilityLabel("Choose Claude Code executable")
                        .disabled(preferences.requiresExplicitAccess && session.isBusy)
                }
                #if !APP_STORE
                if !preferences.executable.isEmpty {
                    Button("Use automatically detected Claude Code") { preferences.executable = "" }
                }
                #endif
                #if APP_STORE
                Text("Choose your installed Claude Code executable. Sign-in access is still being validated.")
                    .font(.caption).foregroundStyle(.secondary)
                #else
                Text("Uses your existing Claude Code sign-in and permissions.")
                    .font(.caption).foregroundStyle(.secondary)
                #endif
            }
            if let error = preferences.accessError {
                Section { Text(error).foregroundStyle(.secondary) }
            }
            #if APP_STORE
            Section {
                Text("App Store compatibility build: Claude Code sign-in and external tool access are still being validated. Stop any Remote Control started in Terminal before testing here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            #endif
            if let issue = session.state.issue {
                Section {
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                DisclosureGroup("Set up in Terminal", isExpanded: $showSetup) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sign in with /login, trust your starting folder, then run /remote-control and accept consent. Exit Claude before starting Beamlet.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("Open Terminal") { openTerminal() }
                            Button(setupCopied ? "Command copied" : "Copy command") { copySetup() }
                        }
                        .disabled(!canCopySetup)
                        Text("The setup command is copied for you to paste into Terminal.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }
            }
        }
        .onAppear { if session.state.issue != nil { showSetup = true } }
        .onChange(of: preferences.folder) { _, _ in setupCopied = false }
        .onChange(of: preferences.executable) { _, _ in setupCopied = false }
    }

    private var about: some View {
        settingsForm {
            Section {
                HStack(spacing: 16) {
                    BeamletMark().stroke(BeamletStyle.accent, style: .init(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40).padding(14)
                        .background(BeamletStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Beamlet").font(.system(size: 25, weight: .semibold, design: .rounded))
                        Text("Claude, within reach.").foregroundStyle(.secondary)
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            #if !APP_STORE
            Section("Updates") {
                HStack {
                    if updates.configured {
                        Button("Check for Updates…") { updates.check() }
                            .disabled(session.isBusy || updates.checking)
                    } else {
                        Link("View GitHub releases…", destination: URL(string: "https://github.com/BlockchainHB/Beamlet/releases")!)
                    }
                    if updates.hasDeferredInstall {
                        Button("Install update") { updates.installWhenStopped() }.disabled(session.isBusy)
                    }
                }
                Text(session.isBusy && updates.configured ? "Stop Remote Control before installing an update." : updates.message)
                    .font(.caption).foregroundStyle(.secondary)
            }
            #endif
            Section("Privacy & support") {
                Text("Connection events stay on this Mac. No analytics, automatic uploads, or saved conversations.")
                    .font(.callout).foregroundStyle(.secondary)
                Link("Privacy policy", destination: URL(string: "https://blockchainhb.github.io/Beamlet/privacy/")!)
                Link("Terms of use", destination: URL(string: "https://blockchainhb.github.io/Beamlet/terms/")!)
                Link("Support", destination: URL(string: "https://blockchainhb.github.io/Beamlet/support/")!)
                DisclosureGroup("Connection diagnostics", isExpanded: $showDiagnostics) {
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView {
                            Text(session.diagnostics.entries.isEmpty ? "No connection events yet." : session.diagnostics.entries.joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(height: 100)
                        Button("Copy diagnostics") { session.copyDiagnostics() }
                    }.padding(.vertical, 8)
                }
            }
            Text("Independent companion for Claude Code. Not affiliated with Anthropic.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var canCopySetup: Bool {
        !preferences.folder.isEmpty && CLIInstallation.executable(override: preferences.executable) != nil
    }

    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Form(content: content)
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
    }

    private func settingLabel(_ title: String, detail: String, path: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(detail).font(.caption).foregroundStyle(.secondary)
                .lineLimit(path ? 1 : nil).truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .help(path ? detail : "")
    }

    private var executableLabel: String {
        guard let executable = CLIInstallation.executable(override: preferences.executable) else { return "Not found" }
        return (executable.path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose folder"
        if panel.runModal() == .OK, let url = panel.url { preferences.selectFolder(url) }
    }

    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Claude"
        if panel.runModal() == .OK, let url = panel.url { preferences.selectExecutable(url) }
    }

    private func copySetup() {
        guard let executable = CLIInstallation.executable(override: preferences.executable), !preferences.folder.isEmpty else { return }
        func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "cd -- \(quote(preferences.folderURL.path)) && \(quote(executable.path))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        setupCopied = true
    }

    private func openTerminal() {
        copySetup()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
}

/// Neutral navigation selection, with native glass on supported macOS versions.
private struct SettingsSidebarButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, selected: selected)
    }

    private struct Row: View {
        let configuration: ButtonStyle.Configuration
        let selected: Bool
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(.primary)
                .background { surface }
                .overlay {
                    if selected && contrast == .increased {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.5), lineWidth: 1)
                    }
                }
                .onHover { hovered = $0 }
        }

        @ViewBuilder private var surface: some View {
            if #available(macOS 26, *), selected, !reduceTransparency, contrast != .increased {
                RoundedRectangle(cornerRadius: 10).fill(.clear)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.16 : selected ? 0.10 : hovered ? 0.05 : 0))
            }
        }
    }
}

private struct NotificationSettings: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var services: SystemServices

    var body: some View {
        Group {
            Toggle(isOn: $preferences.notifications) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notify when attention is needed")
                    Text("A quiet heads-up when the connection needs your help.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 3)
            }
            .accessibilityLabel("Notify when attention is needed")
            .onChange(of: preferences.notifications) { _, enabled in
                if enabled && services.notificationAuthorization == .notDetermined { services.requestNotifications() }
            }
            if preferences.notifications {
                switch services.notificationAuthorization {
                case .notDetermined:
                    Button(services.requestingNotifications ? "Requesting permission…" : "Allow notifications…") {
                        services.requestNotifications()
                    }.disabled(services.requestingNotifications)
                case .denied:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notifications are turned off for Beamlet in macOS.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Open Notification Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                default:
                    EmptyView()
                }
                if let error = services.notificationError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
            .task { await services.refreshNotificationAuthorization() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { await services.refreshNotificationAuthorization() }
            }
    }
}

/// Apply the same compact native window chrome to Settings and its debug preview.
private struct SettingsWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowView: NSView {
        private var observers: [NSObjectProtocol] = []
        private weak var attachedWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== attachedWindow else { return }
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
            attachedWindow = window
            window.styleMask.formUnion([.titled, .closable, .miniaturizable, .fullSizeContentView])
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.toolbar = nil
            window.standardWindowButton(.closeButton)?.isHidden = false
            window.standardWindowButton(.miniaturizeButton)?.isHidden = false
            SettingsWindowManager.shared.opened(window)
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated {
                    if let window { SettingsWindowManager.shared.opened(window) }
                }
            })
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak window] _ in
                MainActor.assumeIsolated {
                    if let window { SettingsWindowManager.shared.closed(window) }
                }
            })
        }

        deinit {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
        }
    }
}

/// Match the native Settings sidebar, including system transparency preferences.
private struct SettingsSidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Dock presence belongs to open Settings windows; the connection lives independently.
@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private let windows = NSHashTable<NSWindow>.weakObjects()
    // Retain the last Settings window so a Dock/Finder reopen can restore it after close.
    private var lastWindow: NSWindow?

    func opened(_ window: NSWindow) {
        lastWindow = window
        windows.add(window)
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
    }

    func closed(_ window: NSWindow) {
        windows.remove(window)
        if windows.allObjects.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }

    @discardableResult
    func reopen() -> Bool {
        guard let window = windows.allObjects.first ?? lastWindow else { return false }
        opened(window)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
