import WakeBeeCore
import Foundation
import Observation

@MainActor @Observable
final class AppModel {
    let preferences: Preferences
    let license: LicenseStore
    let session: SessionController
    let closedLid = ClosedLidService()
    let loginItem = LoginItemService()
    let updates = UpdateService()
    var durationDraft: DurationDraft
    var sessionMode = SessionMode.duration
    var sessionEndDate = Date.now.addingTimeInterval(30 * 60)
    var settingsTab = SettingsTab.general
    var showingSettings = false
    var isPopoverVisible = false
    /// Optional process for the next session; the session ends when it exits.
    var watchedProcess: WatchedProcess?
    private(set) var watchCandidates = WatchCandidates()
    private(set) var blockedStartAttempts = 0
    @ObservationIgnored private var sessionMonitor: SessionMonitor?
    @ObservationIgnored private let processes: any ProcessInspecting

    init() {
        let license = LicenseStore(storage: MigratingLicenseStorage())
        self.license = license
        let preferences = Preferences()
        self.preferences = preferences
        self.durationDraft = DurationDraft(totalMinutes: preferences.initialMinutes)
        let processes = SystemProcesses()
        self.processes = processes
        let session = SessionController(power: PowerAssertionService(),
                                        keepDisplayAwake: preferences.keepDisplayAwake,
                                        processes: processes)
        session.setLicenseAccess(license.isUnlocked)
        self.session = session
        updates.safetyPolicy = { [weak self] in
            guard let self else {
                return UpdateSafetyPolicy(sessionActive: true, helperBusy: false, protectionActive: false,
                                          helperRegistered: false, sleepDisabled: nil)
            }
            return self.updateSafetyPolicy
        }
        self.sessionMonitor = SessionMonitor(session: session, beforeRefresh: { [weak self] in
            self?.synchronizeSafeguards()
        }) { [weak self] hasDemand in
            guard let self else { return }
            self.closedLid.update(hasDemand: hasDemand, policy: self.preferences.closedLidPolicy)
        }
    }

    func showSettings(_ tab: SettingsTab) {
        settingsTab = tab
        showingSettings = true
    }

    func start() {
        guard let duration = requestedSession else { return }
        if startSession(duration, watching: watchedProcess) {
            preferences.remember(duration)
            // A PID belongs to one run of a process; never carry it into the next session.
            watchedProcess = nil
        }
    }

    @discardableResult
    func startSession(_ duration: SessionDuration, watching watched: WatchedProcess? = nil) -> Bool {
        guard updates.allowsStartingSession, !session.isActive else { return false }
        synchronizeSafeguards()
        session.updatePowerSafety(policy: preferences.sessionPowerPolicy, state: SystemPowerState.snapshot)
        let started = session.start(duration, watching: watched)
        if !started && session.statusMessage != nil { blockedStartAttempts += 1 }
        refreshSession()
        return started
    }

    func end() {
        session.end()
        refreshSession()
    }

    func extend() { extendSession(by: 15) }

    func extendSession(by minutes: Int) {
        synchronizeSafeguards()
        session.extend(by: minutes)
        refreshSession()
    }

    func stopWatchingProcess() {
        session.watch(nil)
    }

    func refreshWatchCandidates() {
        watchCandidates = ProcessCatalog.load(using: processes)
        // Drop a selection whose process has since exited.
        if let watchedProcess, !processes.isRunning(watchedProcess) { self.watchedProcess = nil }
    }

    /// Runs a `wakebee://` command. Returns false when it could not be carried
    /// out, so the caller can surface the reason in the popover.
    @discardableResult
    func perform(_ command: SessionCommand) -> Bool {
        switch command {
        case .start(let duration, let pid):
            // An existing session already keeps the Mac awake; leave it untouched.
            guard !session.isActive else { return true }
            return startSession(duration, forPID: pid)
        case .toggle(let duration, let pid):
            if session.isActive { end(); return true }
            return startSession(duration, forPID: pid)
        case .extend(let minutes):
            guard session.session?.endsAt != nil, license.isUnlocked else { return false }
            extendSession(by: minutes)
            return true
        case .end:
            end()
            return true
        }
    }

    private func startSession(_ duration: SessionDuration, forPID pid: Int32?) -> Bool {
        guard let pid else { return startSession(duration) }
        guard let process = processes.process(pid: pid) else {
            session.errorMessage = "No running process has ID \(pid), so no session was started."
            blockedStartAttempts += 1
            return false
        }
        return startSession(duration, watching: process)
    }

    func setDisplayAwake(_ enabled: Bool) {
        if session.setKeepDisplayAwake(enabled) { preferences.keepDisplayAwake = enabled }
    }

    func setupClosedLid() {
        guard license.isUnlocked, updates.allowsStartingSession else { return }
        closedLid.enableAfterSetup()
    }

    func setClosedLid(_ enabled: Bool) {
        guard !enabled || updates.allowsStartingSession else { return }
        guard !enabled || license.isUnlocked else { return }
        closedLid.setEnabled(enabled)
        sessionMonitor?.refresh()
    }

    func handleSystemSleep() {
        closedLid.setEnabled(false)
        session.end(reason: .systemSleep)
    }

    private func refreshSession() {
        sessionMonitor?.refresh()
    }

    var requestedSession: SessionDuration? {
        switch sessionMode {
        case .duration: durationDraft.duration
        case .untilTime: .until(Calendar.current.dateInterval(of: .minute, for: sessionEndDate)?.start ?? sessionEndDate)
        case .untilStopped: .indefinitely
        }
    }

    func refreshPowerSettings() {
        synchronizeSafeguards()
        refreshSession()
    }

    private func synchronizeSafeguards() {
        let wasActive = session.isActive
        license.refreshIfNeeded()
        session.setLicenseAccess(license.isUnlocked)
        // Idle monitoring still refreshes license access, but does not poll IOKit.
        if session.isActive {
            session.updatePowerSafety(policy: preferences.sessionPowerPolicy, state: SystemPowerState.snapshot)
        }
        if wasActive && !session.isActive { closedLid.setEnabled(false) }
    }

    func shutdown() {
        sessionMonitor?.stop()
        closedLid.setEnabled(false)
        session.end()
    }

    var canCheckForUpdates: Bool {
        updates.canCheckForUpdates && !session.isActive && !closedLid.isActive && !closedLid.isBusy
    }

    var updateSafetyPolicy: UpdateSafetyPolicy {
        UpdateSafetyPolicy(sessionActive: session.isActive, helperBusy: closedLid.isBusy,
                           protectionActive: closedLid.isActive, helperRegistered: closedLid.isRegistered,
                           sleepDisabled: closedLid.isRegistered ? try? SystemSleepState.readDisabled() : nil)
    }
}

enum SettingsTab: Hashable { case general, closedLid, license }
enum SessionMode: String, CaseIterable, Identifiable {
    case duration, untilTime, untilStopped
    var id: Self { self }
    var label: String {
        switch self {
        case .duration: "For a duration"
        case .untilTime: "Until a specific time"
        case .untilStopped: "Until I stop it"
        }
    }
}
