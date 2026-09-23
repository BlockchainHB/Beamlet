import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    @Published private(set) var accessError: String?
    private var folderAccess: SecurityScopedSelection?
    private var executableAccess: SecurityScopedSelection?
    var requiresExplicitAccess: Bool {
        #if APP_STORE
        true
        #else
        false
        #endif
    }
    @Published var folder: String { didSet { defaults.set(folder, forKey: "folder") } }
    @Published var executable: String { didSet { defaults.set(executable, forKey: "executable") } }
    @Published var autoStart: Bool { didSet { defaults.set(autoStart, forKey: "autoStart") } }
    @Published var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: "keepAwake") } }
    @Published var notifications: Bool { didSet { defaults.set(notifications, forKey: "notifications") } }
    var manuallyStopped: Bool {
        get { defaults.bool(forKey: "manuallyStopped") }
        set { defaults.set(newValue, forKey: "manuallyStopped") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if APP_STORE
        folder = ""
        executable = ""
        #else
        let suggested = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("dev").path
        folder = defaults.string(forKey: "folder") ?? (FileManager.default.fileExists(atPath: suggested) ? suggested : "")
        executable = defaults.string(forKey: "executable") ?? ""
        #endif
        autoStart = defaults.bool(forKey: "autoStart")
        keepAwake = defaults.bool(forKey: "keepAwake")
        notifications = defaults.object(forKey: "notifications") as? Bool ?? true
        #if APP_STORE
        do {
            folderAccess = try SecurityScopedSelection.restore(key: "folderBookmark", defaults: defaults)
            folder = folderAccess?.url.path ?? ""
        } catch { accessError = "Choose your starting folder again to restore access." }
        do {
            executableAccess = try SecurityScopedSelection.restore(key: "executableBookmark", defaults: defaults, readOnly: true)
            executable = executableAccess?.url.path ?? ""
        } catch { accessError = "Choose your Claude Code executable again to restore access." }
        #endif
    }

    func selectFolder(_ url: URL) {
        do {
            #if APP_STORE
            folderAccess = try SecurityScopedSelection.select(url, key: "folderBookmark", defaults: defaults)
            #endif
            folder = url.path
            accessError = nil
        } catch { accessError = "Couldn't retain folder access. Choose the folder again." }
    }

    func selectExecutable(_ url: URL) {
        do {
            #if APP_STORE
            executableAccess = try SecurityScopedSelection.select(url, key: "executableBookmark", defaults: defaults, readOnly: true)
            #endif
            executable = url.path
            accessError = nil
        } catch { accessError = "Couldn't retain executable access. Choose Claude Code again." }
    }

    var folderURL: URL { URL(fileURLWithPath: (folder as NSString).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath() }
    var displayFolder: String {
        guard !folder.isEmpty else { return "Choose a starting folder" }
        return (folder as NSString).abbreviatingWithTildeInPath
    }
}
