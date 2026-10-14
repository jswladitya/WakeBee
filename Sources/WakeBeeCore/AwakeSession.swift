import Foundation

public struct AwakeSession: Equatable, Sendable {
    public let startedAt: Date
    public var endsAt: Date?
    /// When set, the session also ends as soon as this process exits.
    public var watchedProcess: WatchedProcess?

    public init(startedAt: Date, endsAt: Date?, watchedProcess: WatchedProcess? = nil) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.watchedProcess = watchedProcess
    }

    public func remainingSeconds(at date: Date) -> Int? {
        guard let endsAt else { return nil }
        return max(0, Int(ceil(endsAt.timeIntervalSince(date))))
    }
}

public enum SessionEndReason: Equatable, Sendable {
    case stopped, completed, systemSleep
    case lowBattery(Int), powerRequired, powerUnknown, licenseExpired
    case watchedProcessExited(String)

    public var description: String {
        switch self {
        case .stopped: "Session ended."
        case .completed: "Session complete."
        case .systemSleep: "Session ended when your Mac went to sleep."
        case .lowBattery(let cutoff): "Session ended at the \(cutoff)% battery cutoff."
        case .powerRequired: "Plug in your charger to continue, or allow battery use in Settings."
        case .powerUnknown: "Could not verify battery or power status. Session protection is off."
        case .licenseExpired: "Verify your license to start another session."
        case .watchedProcessExited(let name): "\(name) finished, so the session ended."
        }
    }
}

public enum Countdown {
    public static func string(seconds: Int) -> String {
        let seconds = max(0, seconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainder = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

/// Compact remaining time for the menu bar, rounded up to the minute so it
/// never claims a session is over before it is.
public enum MenuBarCountdown {
    public static func string(seconds: Int) -> String {
        let minutes = (max(0, seconds) + 59) / 60
        guard minutes >= 60 else { return "\(minutes)m" }
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
