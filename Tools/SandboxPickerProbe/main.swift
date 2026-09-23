// Local UI diagnostic: select only the Claude executable; runs --version, never login.
import AppKit

@MainActor
final class Delegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var result: NSTextField!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 240), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Beamlet Sandbox Access Test"
        let view = NSView(frame: window.contentView!.bounds)
        let button = NSButton(title: "Choose installed Claude executable…", target: self, action: #selector(choose))
        button.frame = NSRect(x: 24, y: 174, width: 550, height: 36)
        result = NSTextField(wrappingLabelWithString: "Checks --version in App Sandbox. Does not open a Remote Control session or read account credentials.")
        result.frame = NSRect(x: 24, y: 25, width: 550, height: 135)
        view.addSubview(button); view.addSubview(result); window.contentView = view
        NSApp.setActivationPolicy(.regular); window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func choose() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true
        panel.showsHiddenFiles = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let selected = panel.url else { return }
        let accessed = selected.startAccessingSecurityScopedResource()
        defer { if accessed { selected.stopAccessingSecurityScopedResource() } }
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let task = Process(), input = Pipe(), output = Pipe()
            task.executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/BeamletRunner")
            task.arguments = [selected.path, folder.path, folder.appendingPathComponent("probe.lock").path, "--version"]
            task.standardInput = input; task.standardOutput = output; task.standardError = output
            try task.run(); try output.fileHandleForWriting.close()
            let data = output.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit(); try input.fileHandleForWriting.close()
            result.stringValue = "Security-scoped access: \(accessed). Runner exit: \(task.terminationStatus).\n" + String(decoding: data.prefix(2000), as: UTF8.self)
        } catch { result.stringValue = "Probe failed: \(error.localizedDescription)" }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = Delegate(); app.delegate = delegate; app.run()
}
