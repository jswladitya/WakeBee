import Foundation
import Observation

@MainActor
public protocol PowerManaging: AnyObject {
    /// Replace the current assertions atomically; on failure keep the old set.
    func activate(keepDisplayAwake: Bool) throws
    func deactivate()
}

@MainActor @Observable
public final class SessionController {
    public private(set) var session: AwakeSession?
    public private(set) var keepDisplayAwake: Bool
    public private(set) var lastEndReason: SessionEndReason?
    public var errorMessage: String?
    public private(set) var allowsNewSessions = true

    @ObservationIgnored private let power: any PowerManaging
    @ObservationIgnored private let processes: any ProcessInspecting
    @ObservationIgnored private let schedulesTimers: Bool
    @ObservationIgnored private var expiryTimer: Timer?
    @ObservationIgnored private var powerPolicy: SessionPowerPolicy = .unrestricted
    @ObservationIgnored private var powerState = ClosedLidPowerState(source: .unknown, batteryPercent: nil)

    public init(power: any PowerManaging, keepDisplayAwake: Bool = false, schedulesTimers: Bool = true,
                processes: any ProcessInspecting = SystemProcesses()) {
        self.power = power
        self.processes = processes
        self.keepDisplayAwake = keepDisplayAwake
        self.schedulesTimers = schedulesTimers
    }

    public var isActive: Bool { session != nil }

    public var statusMessage: String? {
        if let errorMessage { return errorMessage }
        guard let reason = lastEndReason, reason != .stopped, reason != .completed else { return nil }
        return reason.description
    }

    /// Finite sessions may finish; until-stopped sessions end when verification lapses.
    public func setLicenseAccess(_ allowed: Bool) {
        allowsNewSessions = allowed
        if !allowed, let current = session, current.endsAt == nil { end(reason: .licenseExpired) }
    }

    public func updatePowerSafety(policy: SessionPowerPolicy, state: ClosedLidPowerState) {
        powerPolicy = policy
        powerState = state
        if isActive, let reason = policy.stopReason(for: state) { end(reason: reason) }
    }

    @discardableResult
    public func start(_ duration: SessionDuration, watching watched: WatchedProcess? = nil,
                      at date: Date = .now) -> Bool {
        guard allowsNewSessions else {
            errorMessage = "Activate your WakeBee license to start a new session."
            return false
        }
        guard duration.isValid(at: date) else {
            errorMessage = "Choose 1 minute to 24 hours, or an end time within the next 24 hours."
            return false
        }
        guard session == nil else { return false }
        if let watched, !processes.isRunning(watched) {
            errorMessage = "\(watched.name) is no longer running. Choose another process to watch."
            return false
        }
        if let reason = powerPolicy.stopReason(for: powerState) {
            switch reason {
            case .lowBattery(let cutoff): errorMessage = "Charge above \(cutoff)% or connect a power adapter to start."
            default: errorMessage = reason.description
            }
            return false
        }
        do {
            try power.activate(keepDisplayAwake: keepDisplayAwake)
            let end: Date?
            switch duration {
            case .minutes(let minutes): end = date.addingTimeInterval(Double(minutes) * 60)
            case .until(let date): end = date
            case .indefinitely: end = nil
            }
            session = AwakeSession(startedAt: date, endsAt: end, watchedProcess: watched)
            lastEndReason = nil
            errorMessage = nil
            scheduleExpiry()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func end(reason: SessionEndReason = .stopped) {
        expiryTimer?.invalidate()
        expiryTimer = nil
        if session != nil { lastEndReason = reason }
        session = nil
        power.deactivate()
        errorMessage = nil
    }

    @discardableResult
    public func setKeepDisplayAwake(_ value: Bool) -> Bool {
        guard value != keepDisplayAwake else { return true }
        do {
            if isActive { try power.activate(keepDisplayAwake: value) }
            keepDisplayAwake = value
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func extend(by minutes: Int = 15, at date: Date = .now) {
        guard allowsNewSessions else { return }
        refresh(at: date)
        guard minutes > 0, minutes <= SessionDuration.maximumMinutes,
              let current = session, let end = current.endsAt else { return }
        // Keep a bounded duration even after repeated extensions.
        let maximum = current.startedAt.addingTimeInterval(Double(SessionDuration.maximumMinutes) * 60)
        session?.endsAt = min(end.addingTimeInterval(Double(minutes) * 60), maximum)
        scheduleExpiry()
    }

    /// Attach a process to the running session, or detach with nil.
    @discardableResult
    public func watch(_ watched: WatchedProcess?) -> Bool {
        guard session != nil else { return false }
        if let watched, !processes.isRunning(watched) {
            errorMessage = "\(watched.name) is no longer running."
            return false
        }
        session?.watchedProcess = watched
        errorMessage = nil
        return true
    }

    public func refresh(at date: Date = .now) {
        if let end = session?.endsAt, date >= end { self.end(reason: .completed) }
        if let watched = session?.watchedProcess, !processes.isRunning(watched) {
            self.end(reason: .watchedProcessExited(watched.name))
        }
    }

    private func scheduleExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard schedulesTimers, let end = session?.endsAt else { return }
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
                // If the system clock moved backwards, re-arm for the new deadline.
                if self?.session != nil { self?.scheduleExpiry() }
            }
        }
        timer.tolerance = 0.2
        expiryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
