import SwiftUI

@MainActor
final class AppModel {
    static let shared = AppModel()
    let preferences = Preferences()
    let login = LoginItem()
    let session: SessionController
    let updates: UpdateController
    private init() {
        session = SessionController(preferences: preferences)
        updates = UpdateController(session: session)
    }
}

@main
struct BeamletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var session = AppModel.shared.session
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            SessionPanel(session: session, preferences: model.preferences, updates: model.updates)
        } label: {
            Image(nsImage: BeamletMark.menuBarImage(connected: session.state.phase == .online))
                .accessibilityLabel("Beamlet, \(session.state.phase.rawValue)")
                .help("Beamlet · \(session.state.phase.rawValue)")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(preferences: model.preferences, session: session, login: model.login,
                         updates: model.updates, power: session.power)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminating = false
#if DEBUG
    private var designPreview: NSWindow?
#endif
    func applicationDidFinishLaunching(_ notification: Notification) {
#if DEBUG
        if CommandLine.arguments.contains("--preview-panel") || Bundle.main.object(forInfoDictionaryKey: "BeamletDesignPreview") as? Bool == true {
            let model = AppModel.shared
            if CommandLine.arguments.contains("--preview-dark") || Bundle.main.object(forInfoDictionaryKey: "BeamletPreviewAppearance") as? String == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
            if CommandLine.arguments.contains("--preview-light") || Bundle.main.object(forInfoDictionaryKey: "BeamletPreviewAppearance") as? String == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
            let previewSettings = Bundle.main.object(forInfoDictionaryKey: "BeamletPreviewSettings") as? Bool == true
            let content = previewSettings
                ? AnyView(SettingsView(preferences: model.preferences, session: model.session, login: model.login,
                                       updates: model.updates, power: model.session.power))
                : AnyView(SessionPanel(session: model.session, preferences: model.preferences, updates: model.updates))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 480),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = previewSettings ? "Beamlet Settings Preview" : "Beamlet Design Preview"
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            designPreview = window
            return
        }
#endif
        AppModel.shared.session.startAutomaticallyIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.reopen()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let session = AppModel.shared.session
        guard session.isBusy else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        session.onFullyStopped = {
            DispatchQueue.main.async { NSApp.reply(toApplicationShouldTerminate: true) }
        }
        session.stop(explicit: false)
        return .terminateLater
    }
}
