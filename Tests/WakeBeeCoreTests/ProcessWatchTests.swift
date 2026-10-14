import Foundation
import Testing
@testable import WakeBeeCore

private final class FakeProcesses: ProcessInspecting {
    var running: [WatchedProcess] = []
    func process(pid: Int32) -> WatchedProcess? { running.first { $0.pid == pid } }
    func isRunning(_ process: WatchedProcess) -> Bool { running.contains { $0.isSameInstance(as: process) } }
    func candidates() -> [WatchedProcess] { running }
}

@MainActor private final class WatchPower: PowerManaging {
    var active = false
    func activate(keepDisplayAwake: Bool) throws { active = true }
    func deactivate() { active = false }
}

@Suite @MainActor struct ProcessWatchTests {
    private let origin = Date(timeIntervalSince1970: 1_000_000)
    private let agent = WatchedProcess(pid: 4321, name: "claude", startedAt: 900_000)

    private func makeController() -> (SessionController, WatchPower, FakeProcesses) {
        let power = WatchPower(), processes = FakeProcesses()
        processes.running = [agent]
        return (SessionController(power: power, schedulesTimers: false, processes: processes), power, processes)
    }

    @Test func sessionEndsWhenTheWatchedProcessExits() {
        let (controller, power, processes) = makeController()
        #expect(controller.start(.indefinitely, watching: agent, at: origin))
        controller.refresh(at: origin.addingTimeInterval(3600))
        #expect(power.active)
        processes.running = []
        controller.refresh(at: origin.addingTimeInterval(3602))
        #expect(!power.active && !controller.isActive)
        #expect(controller.lastEndReason == .watchedProcessExited("claude"))
        #expect(controller.statusMessage == "claude finished, so the session ended.")
    }

    @Test func timerStillEndsAWatchedSessionFirst() {
        let (controller, power, _) = makeController()
        controller.start(.minutes(10), watching: agent, at: origin)
        controller.refresh(at: origin.addingTimeInterval(600))
        #expect(!power.active && controller.lastEndReason == .completed)
    }

    @Test func reusedPIDIsNotTheWatchedProcess() {
        let (controller, power, processes) = makeController()
        controller.start(.indefinitely, watching: agent, at: origin)
        processes.running = [WatchedProcess(pid: agent.pid, name: "claude", startedAt: 950_000)]
        controller.refresh(at: origin.addingTimeInterval(4))
        #expect(!power.active && controller.lastEndReason == .watchedProcessExited("claude"))
    }

    @Test func cannotStartWatchingAProcessThatAlreadyExited() {
        let (controller, power, processes) = makeController()
        processes.running = []
        #expect(!controller.start(.indefinitely, watching: agent, at: origin))
        #expect(!power.active)
        #expect(controller.errorMessage == "claude is no longer running. Choose another process to watch.")
    }

    @Test func detachingKeepsTheSessionRunning() {
        let (controller, power, processes) = makeController()
        controller.start(.indefinitely, watching: agent, at: origin)
        #expect(controller.watch(nil))
        processes.running = []
        controller.refresh(at: origin.addingTimeInterval(60))
        #expect(power.active && controller.isActive)
        #expect(!controller.watch(agent))
        #expect(controller.session?.watchedProcess == nil)
    }

    @Test func candidatesKeepTerminalWorkAndDropShellsDaemonsAndOtherUsers() {
        func record(_ pid: Int32, _ name: String, start: TimeInterval, uid: uid_t = 501, tty: Bool = true) -> ProcessRecord {
            ProcessRecord(process: WatchedProcess(pid: pid, name: name, startedAt: start), uid: uid, hasTerminal: tty)
        }
        let records = [
            record(10, "-zsh", start: 1), record(11, "zsh", start: 2), record(12, "login", start: 3),
            record(20, "claude", start: 10), record(21, "claude", start: 30), record(22, "python3", start: 20),
            record(30, "launchd-helper", start: 40, tty: false), record(31, "codex", start: 50, uid: 0),
            record(40, "WakeBee", start: 60), record(41, "", start: 70),
        ]
        let result = ProcessCandidates.filter(records, uid: 501, excluding: 40)
        #expect(result.map(\.pid) == [21, 22])
        #expect(ProcessCandidates.filter(records, uid: 501, excluding: 40, limit: 1).map(\.name) == ["claude"])
    }
}
