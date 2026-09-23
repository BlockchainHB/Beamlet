import Foundation
import Combine
#if !APP_STORE
import Sparkle

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var configured = false
    @Published private(set) var message = "Download new versions from GitHub Releases. Automatic updates are not enabled."
    @Published private(set) var checking = false
    private var controller: SPUStandardUpdaterController?
    private let session: SessionController
    private var deferredInstall: (() -> Void)?

    init(session: SessionController) {
        self.session = session
        super.init()
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              URLComponents(string: feed)?.scheme == "https",
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        configured = true
        message = "Signed updates, delivered directly to Beamlet."
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        controller?.updater.sendsSystemProfile = false
        controller?.updater.automaticallyDownloadsUpdates = false
    }

    func check() {
        guard configured, !session.isBusy else {
            message = configured ? "Stop Remote Control before updating Beamlet." : "Download new versions from GitHub Releases. Automatic updates are not enabled."
            return
        }
        checking = true
        controller?.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard !session.isBusy else { throw busyError }
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate updateItem: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        guard !session.isBusy else { throw busyError }
    }

    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard session.isBusy else { return false }
        deferredInstall = installHandler
        message = "Update ready. Stop Remote Control, then install the update."
        return true
    }

    func installWhenStopped() {
        guard !session.isBusy, let install = deferredInstall else { return }
        deferredInstall = nil
        install()
    }

    var hasDeferredInstall: Bool { deferredInstall != nil }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        checking = false
    }

    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }

    private var busyError: NSError {
        NSError(domain: "BeamletUpdates", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Stop Remote Control before updating Beamlet."])
    }
}

#else
/// The store target does not link or embed any external updater.
@MainActor
final class UpdateController: ObservableObject {
    let configured = false
    let checking = false
    init(session: SessionController) {}
}
#endif
