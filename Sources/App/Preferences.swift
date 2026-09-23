import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    private let defaults: UserDefaults
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
        let suggested = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("dev").path
        folder = defaults.string(forKey: "folder") ?? (FileManager.default.fileExists(atPath: suggested) ? suggested : "")
        executable = defaults.string(forKey: "executable") ?? ""
        autoStart = defaults.bool(forKey: "autoStart")
        keepAwake = defaults.bool(forKey: "keepAwake")
        notifications = defaults.object(forKey: "notifications") as? Bool ?? true
    }

    var folderURL: URL { URL(fileURLWithPath: (folder as NSString).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath() }
    var displayFolder: String {
        guard !folder.isEmpty else { return "Choose a starting folder" }
        return (folder as NSString).abbreviatingWithTildeInPath
    }
}
