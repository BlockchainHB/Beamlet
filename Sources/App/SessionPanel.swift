import SwiftUI
import CoreImage.CIFilterBuiltins
import BeamletCore

struct SessionPanel: View {
    @AppStorage("settingsTab") private var settingsTab: SettingsTab = .general
    @ObservedObject var session: SessionController
    @ObservedObject var preferences: Preferences
    @ObservedObject var updates: UpdateController
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var scheme
    @State private var showQR = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 22)

            HStack(alignment: .firstTextBaseline) {
                Text(session.state.phase.rawValue)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .tracking(-0.6)
                Spacer()
                if session.state.phase == .starting || session.state.phase == .reconnecting || session.state.phase == .stopping {
                    ProgressView().controlSize(.small).accessibilityLabel(session.state.phase.rawValue)
                }
            }
            Text(session.state.detail)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
                .padding(.top, 5)
                .frame(minHeight: 38, alignment: .topLeading)

            primaryAction.padding(.top, 18)

            HStack(spacing: 7) {
                Image(systemName: "folder").font(.system(size: 11)).accessibilityHidden(true)
                Text(displayFolder).lineLimit(1).truncationMode(.middle)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .help(displayFolder)
            .padding(.top, 12)

            Spacer().frame(height: 22)

            VStack(spacing: 3) {
                actionRow("Open in Claude", symbol: "arrow.up.right.square") { session.openSession() }
                    .disabled(!session.state.canOpenSession)
                    .help(session.state.canOpenSession ? "Open the connection in your default browser." : "Start Remote Control to connect your devices.")
                actionRow(copied ? "Link copied" : "Copy connection link", symbol: copied ? "checkmark" : "link") {
                    session.copySession()
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                }.disabled(!session.state.canOpenSession)
                actionRow(showQR ? "Hide QR code" : "Connect your phone", symbol: "qrcode") {
                    showQR.toggle()
                }.disabled(!session.state.canOpenSession)
                Divider().padding(.vertical, 4)
                actionRow("Settings", symbol: "gearshape", shortcut: "⌘,") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }.keyboardShortcut(",", modifiers: .command)
                actionRow("Quit Beamlet", symbol: "power", shortcut: "⌘Q") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            .padding(6)
            .background(Color.white.opacity(scheme == .dark ? 0.055 : 0.65), in: RoundedRectangle(cornerRadius: 16))

            if showQR, session.state.canOpenSession, let url = session.state.sessionURL {
                QRCodeView(url: url).padding(.top, 14)
            }

        }
        .padding(22)
        .frame(width: 340)
        .background { BeamletSurface() }
        .tint(BeamletStyle.accent)
        .onChange(of: session.state.canOpenSession) { _, allowed in if !allowed { showQR = false; copied = false } }
    }

    private var displayFolder: String {
        if let folder = session.activeFolder { return (folder as NSString).abbreviatingWithTildeInPath }
        return preferences.displayFolder
    }

    private var header: some View {
        HStack(spacing: 10) {
            BeamletMark(connected: session.state.phase == .online)
                .stroke(BeamletStyle.accent, style: .init(lineWidth: 2.7, lineCap: .round))
                .frame(width: 32, height: 32)
                .padding(10)
                .background(BeamletStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Beamlet").font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Claude, within reach.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if session.state.issue != nil, !session.isBusy {
            Button {
                settingsTab = .connection
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: { Text("Review setup").frame(maxWidth: .infinity).padding(.vertical, 4) }
            .modifier(BeamletPrimaryControl()).controlSize(.large)
            Button("Try again") { session.start() }
                .buttonStyle(.plain).font(.system(size: 12))
                .frame(maxWidth: .infinity).padding(.top, 5)
        } else {
            Button {
                if session.isBusy { session.stop() }
                else { session.start() }
            } label: {
                Text(session.isBusy ? "Stop Remote Control" : "Start Remote Control")
                    .fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .modifier(BeamletPrimaryControl())
            .controlSize(.large)
            .disabled(session.state.phase == .stopping || updates.checking)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private func actionRow(_ title: String, symbol: String, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary).frame(width: 18)
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut).font(.system(size: 11)).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .font(.system(size: 13))
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeamletRowButtonStyle())
    }
}

private struct QRCodeView: View {
    let url: URL
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 10) {
            if let image = makeCode() {
                Image(nsImage: image).interpolation(.none).resizable()
                    .frame(width: 164, height: 164).padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1))
                    .accessibilityLabel("Connection QR code. Scan with your phone, or use Copy connection link.")
            }
            Text("Scan to connect in Claude.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func makeCode() -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: output.extent.width, height: output.extent.height))
    }
}
