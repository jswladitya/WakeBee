import AppKit
import WakeBeeCore

/// Processes offered in the "End when it exits" picker.
struct WatchCandidates: Equatable {
    var terminal: [WatchedProcess] = []
    var apps: [WatchedProcess] = []
    var isEmpty: Bool { terminal.isEmpty && apps.isEmpty }
}

@MainActor
enum ProcessCatalog {
    /// Apps that never finish on their own are not useful to watch.
    private static let ignoredBundleIDs: Set<String> = ["com.apple.finder", "com.apple.systempreferences"]

    static func load(using processes: any ProcessInspecting) -> WatchCandidates {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular && !app.isTerminated && app.processIdentifier != ownPID
                    && !ignoredBundleIDs.contains(app.bundleIdentifier ?? "")
            }
            .compactMap { app -> WatchedProcess? in
                guard let process = processes.process(pid: app.processIdentifier) else { return nil }
                return WatchedProcess(pid: process.pid, name: app.localizedName ?? process.name,
                                      startedAt: process.startedAt)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return WatchCandidates(terminal: processes.candidates(), apps: apps)
    }
}
