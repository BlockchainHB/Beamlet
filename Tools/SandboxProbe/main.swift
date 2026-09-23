// A command-line diagnostic, not a UI app. Never opens Claude or reads credentials.
import Foundation

let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BeamletProbe-\(UUID())")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let runner = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/BeamletRunner")
let process = Process(), input = Pipe(), output = Pipe()
process.executableURL = runner
let executable = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/bin/echo"
let argument = CommandLine.arguments.count > 1 ? "--version" : "BEAMLET_SANDBOX_PTY_OK"
process.arguments = [executable, folder.path, folder.appendingPathComponent("probe.lock").path, argument]
process.standardInput = input
process.standardOutput = output
process.standardError = output
try process.run()
try output.fileHandleForWriting.close()
let result = output.fileHandleForReading.readDataToEndOfFile()
process.waitUntilExit()
try input.fileHandleForWriting.close()
print("container_home=\(NSHomeDirectory().contains("/Library/Containers/"))")
print("runner_exit=\(process.terminationStatus)")
print(String(decoding: result, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
exit(process.terminationStatus)
