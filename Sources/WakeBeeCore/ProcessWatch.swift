import Foundation
import Darwin

/// A specific process instance. The start time guards against PID reuse:
/// a recycled PID with a different start time is a different process.
public struct WatchedProcess: Equatable, Hashable, Sendable, Identifiable {
    public let pid: Int32
    public let name: String
    public let startedAt: TimeInterval
    public var id: Int32 { pid }

    public init(pid: Int32, name: String, startedAt: TimeInterval) {
        self.pid = pid
        self.name = name
        self.startedAt = startedAt
    }

    public func isSameInstance(as other: WatchedProcess) -> Bool {
        pid == other.pid && abs(startedAt - other.startedAt) < 0.001
    }
}

public protocol ProcessInspecting {
    /// The live process with this PID, or nil when it does not exist.
    func process(pid: Int32) -> WatchedProcess?
    func isRunning(_ process: WatchedProcess) -> Bool
    /// Processes a person is likely to want to watch, newest first.
    func candidates() -> [WatchedProcess]
}

/// Raw process facts, separated from libproc so filtering stays testable.
public struct ProcessRecord: Equatable, Sendable {
    public let process: WatchedProcess
    public let uid: uid_t
    public let hasTerminal: Bool

    public init(process: WatchedProcess, uid: uid_t, hasTerminal: Bool) {
        self.process = process
        self.uid = uid
        self.hasTerminal = hasTerminal
    }
}

public enum ProcessCandidates {
    /// Interactive shells and terminal plumbing are never the work itself.
    static let ignoredNames: Set<String> = [
        "login", "sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh", "nu",
        "tmux", "screen", "ssh-agent", "ps", "top", "htop", "less", "more", "man",
        "sudo", "su", "caffeinate", "pmset", "launchctl"
    ]

    /// Terminal-attached processes owned by this user, deduplicated by name
    /// with the newest instance kept. Agents and scripts started in a terminal
    /// land here; background daemons and other users' processes do not.
    public static func filter(_ records: [ProcessRecord], uid: uid_t, excluding ownPID: Int32,
                              limit: Int = 20) -> [WatchedProcess] {
        var newestByName: [String: WatchedProcess] = [:]
        for record in records {
            let process = record.process
            let name = process.name.hasPrefix("-") ? String(process.name.dropFirst()) : process.name
            guard record.uid == uid, record.hasTerminal, process.pid != ownPID, process.pid > 1,
                  !name.isEmpty, !ignoredNames.contains(name) else { continue }
            if let existing = newestByName[name], existing.startedAt >= process.startedAt { continue }
            newestByName[name] = process
        }
        return newestByName.values
            .sorted { $0.startedAt != $1.startedAt ? $0.startedAt > $1.startedAt : $0.pid > $1.pid }
            .prefix(limit)
            .map { $0 }
    }
}

/// Reads process state with libproc. Owned processes are always readable.
public struct SystemProcesses: ProcessInspecting {
    /// `SZOMB` in <sys/proc.h>: exited but not yet reaped.
    private static let zombieStatus: UInt32 = 5

    public init() {}

    public func process(pid: Int32) -> WatchedProcess? {
        guard let info = Self.info(pid: pid), info.pbi_status != Self.zombieStatus else { return nil }
        return Self.process(from: info, pid: pid)
    }

    public func isRunning(_ watched: WatchedProcess) -> Bool {
        if let info = Self.info(pid: watched.pid) {
            guard info.pbi_status != Self.zombieStatus else { return false }
            return Self.process(from: info, pid: watched.pid).isSameInstance(as: watched)
        }
        // Unreadable but present (another user's process) still counts as running.
        return kill(watched.pid, 0) == 0 || errno == EPERM
    }

    public func candidates() -> [WatchedProcess] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let filled = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard filled > 0 else { return [] }
        let records: [ProcessRecord] = pids.prefix(min(Int(filled), pids.count)).compactMap { pid in
            guard pid > 0, let info = Self.info(pid: pid), info.pbi_status != Self.zombieStatus else { return nil }
            return ProcessRecord(process: Self.process(from: info, pid: pid), uid: info.pbi_uid,
                                 hasTerminal: info.e_tdev != UInt32.max && info.e_tdev != 0)
        }
        return ProcessCandidates.filter(records, uid: getuid(), excluding: getpid())
    }

    private static func info(pid: Int32) -> proc_bsdinfo? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    private static func process(from info: proc_bsdinfo, pid: Int32) -> WatchedProcess {
        // pbi_name holds the full name; pbi_comm is truncated to 16 bytes.
        let full = withUnsafeBytes(of: info.pbi_name) { Self.string(from: $0) }
        let short = withUnsafeBytes(of: info.pbi_comm) { Self.string(from: $0) }
        let started = TimeInterval(info.pbi_start_tvsec) + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        return WatchedProcess(pid: pid, name: full.isEmpty ? short : full, startedAt: started)
    }

    private static func string(from bytes: UnsafeRawBufferPointer) -> String {
        String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}
