import WakeBeeCore
import WakeBeeHelperProtocol
import Darwin
import Foundation
import OSLog

final class SystemSleepSetting: SleepSettingManaging {
    private let log = Logger(subsystem: HelperIdentity.service, category: "Sleep")
    private let folder = "/private/var/db/app.wakebee.helper"
    private var file: URL { URL(fileURLWithPath: folder).appendingPathComponent("recovery.json") }

    func readDisabled() throws -> Bool {
        try SystemSleepState.readDisabled()
    }
    func writeDisabled(_ value: Bool) throws {
        _ = try pmset(["-a", "disablesleep", value ? "1" : "0"])
        // powerd delivers preference updates to the kernel asynchronously.
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        repeat {
            if try readDisabled() == value { return }
            Thread.sleep(forTimeInterval: 0.05)
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw SettingError.unconfirmed
    }
    func saveRecovery(_ previousValue: Bool) throws {
        try prepareDirectory()
        try validateFileIfPresent()
        try JSONEncoder().encode(previousValue).write(to: file, options: .atomic)
        guard chmod(file.path, 0o600) == 0 else { throw SettingError.journal }
        // Flush the journal before changing the system setting.
        let fd = open(file.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw SettingError.journal }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw SettingError.journal }
        let directory = open(folder, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard directory >= 0 else { throw SettingError.journal }
        defer { close(directory) }
        guard fsync(directory) == 0 else { throw SettingError.journal }
    }
    func loadRecovery() throws -> Bool? {
        try prepareDirectory()
        guard try validateFileIfPresent() else { return nil }
        let data = try Data(contentsOf: file)
        guard data.count < 128 else { throw SettingError.journal }
        return try JSONDecoder().decode(Bool.self, from: data)
    }
    func clearRecovery() throws {
        if try validateFileIfPresent() { try FileManager.default.removeItem(at: file) }
    }
    func sleepIfLidClosed() {
        // An unreadable lid state (including desktops) never forces sleep.
        guard (try? SystemSleepState.readLidClosed()) == true else { return }
        do {
            _ = try pmset(["sleepnow"])
            log.notice("Safety stop with the lid closed; requested system sleep")
        } catch {
            log.error("Safety stop with the lid closed; sleep request failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    private func prepareDirectory() throws {
        guard geteuid() == 0 else { throw SettingError.journal }
        if mkdir(folder, 0o700) < 0 && errno != EEXIST { throw SettingError.journal }
        var info = stat()
        guard lstat(folder, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == 0, info.st_mode & 0o777 == 0o700 else { throw SettingError.journal }
    }
    @discardableResult private func validateFileIfPresent() throws -> Bool {
        var info = stat()
        if lstat(file.path, &info) < 0 {
            if errno == ENOENT { return false }
            throw SettingError.journal
        }
        guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == 0, info.st_mode & 0o077 == 0,
              info.st_nlink == 1 else { throw SettingError.journal }
        return true
    }
    private func pmset(_ arguments: [String]) throws -> String {
        let task = Process(), pipe = Pipe(), finished = DispatchSemaphore(value: 0)
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { _ in finished.signal() }
        try task.run()
        guard finished.wait(timeout: .now() + 3) == .success else {
            task.terminate()
            if finished.wait(timeout: .now() + 1) != .success { kill(task.processIdentifier, SIGKILL) }
            throw SettingError.command
        }
        guard task.terminationStatus == 0 else { throw SettingError.command }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
    enum SettingError: LocalizedError {
        case unconfirmed, journal, command
        var errorDescription: String? {
            switch self {
            case .unconfirmed: "macOS did not confirm the sleep setting change. Keep the lid open."
            case .journal: "The sleep recovery journal could not be secured."
            case .command: "macOS could not update its sleep setting."
            }
        }
    }
}
