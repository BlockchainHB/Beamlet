import AppKit
import Network
import ServiceManagement
import UserNotifications
import IOKit.pwr_mgt
import IOKit.ps

@MainActor
final class PowerManager: ObservableObject {
    @Published private(set) var preventingSleep = false
    private var assertion = IOPMAssertionID(0)
    func update(enabled: Bool, running: Bool) {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let wanted = enabled && running && source == kIOPSACPowerValue
        guard wanted != preventingSleep else { return }
        if wanted {
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                    "Beamlet Remote Control is running" as CFString, &assertion)
            preventingSleep = result == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(assertion)
            preventingSleep = false
        }
    }
}

@MainActor
final class SystemServices: ObservableObject {
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus?
    @Published private(set) var requestingNotifications = false
    @Published private(set) var notificationError: String?
    private let network = NWPathMonitor()
    private var observers: [NSObjectProtocol] = []
    private var previousNetwork: Bool?
    var onNetwork: ((Bool) -> Void)?
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    init(observeSystem: Bool = true) {
        guard observeSystem else { return }
        network.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self, self.previousNetwork != available else { return }
                self.previousNetwork = available
                self.onNetwork?(available)
            }
        }
        network.start(queue: DispatchQueue(label: "app.beamlet.network"))
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onSleep?() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.onWake?() }
        })
    }

    deinit {
        network.cancel()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func notifyAttention(_ message: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Beamlet needs your attention"
            content.body = message
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "beamlet-attention", content: content, trigger: nil))
        }
    }

    func refreshNotificationAuthorization() async {
        notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestNotifications() {
        guard !requestingNotifications else { return }
        requestingNotifications = true
        notificationError = nil
        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            } catch {
                notificationError = "Couldn't request permission. Check Notifications in System Settings."
            }
            await refreshNotificationAuthorization()
            requestingNotifications = false
        }
    }
}

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var message: String?
    init() { refresh() }
    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        message = SMAppService.mainApp.status == .requiresApproval ? "Allow Beamlet in System Settings → Login Items." : nil
    }
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refresh()
        } catch {
            refresh()
            message = "Couldn't change the login item. Check System Settings → Login Items."
        }
    }
}
