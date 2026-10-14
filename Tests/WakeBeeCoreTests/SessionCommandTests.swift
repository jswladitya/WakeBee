import Foundation
import Testing
@testable import WakeBeeCore

@Suite struct SessionCommandTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    // 1970-01-12 13:46:40 UTC
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func command(_ text: String) -> SessionCommand? {
        SessionCommand(url: URL(string: text)!, now: now, calendar: calendar)
    }

    @Test func startParsesEveryDurationForm() {
        #expect(command("wakebee://start") == .start(.indefinitely, pid: nil))
        #expect(command("wakebee://start?minutes=90") == .start(.minutes(90), pid: nil))
        #expect(command("wakebee://start?hours=1.5") == .start(.minutes(90), pid: nil))
        #expect(command("WAKEBEE://START?Minutes=5") == .start(.minutes(5), pid: nil))
        #expect(command("wakebee:start?minutes=5") == .start(.minutes(5), pid: nil))
        #expect(command("wakebee://start?pid=4321") == .start(.indefinitely, pid: 4321))
        #expect(command("wakebee://start?minutes=30&pid=4321") == .start(.minutes(30), pid: 4321))
        #expect(command("wakebee://toggle?minutes=30") == .toggle(.minutes(30), pid: nil))
    }

    @Test func untilUsesTheNextOccurrenceOfTheClockTime() {
        let later = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: now)!
        #expect(command("wakebee://start?until=17:30") == .start(.until(later), pid: nil))
        let tomorrow = calendar.date(byAdding: .day, value: 1,
                                     to: calendar.date(bySettingHour: 9, minute: 5, second: 0, of: now)!)!
        #expect(command("wakebee://start?until=9:05") == .start(.until(tomorrow), pid: nil))
    }

    @Test func rejectsAmbiguousOrOutOfRangeInput() {
        for text in ["wakebee://start?minutes=0", "wakebee://start?minutes=1441", "wakebee://start?minutes=abc",
                     "wakebee://start?hours=25", "wakebee://start?hours=nan", "wakebee://start?hours=1e300",
                     "wakebee://start?minutes=5&hours=1", "wakebee://start?minutes=5&until=10:00",
                     "wakebee://start?minutes=5&minutes=10", "wakebee://start?until=24:00",
                     "wakebee://start?until=10:60", "wakebee://start?until=10", "wakebee://start?until=+1:05",
                     "wakebee://start?pid=0", "wakebee://start?pid=1", "wakebee://start?pid=-5",
                     "wakebee://start?pid=x", "wakebee://start?closedLid=1", "wakebee://start?minutes",
                     "wakebee://extend?minutes=0", "wakebee://extend?hours=1", "wakebee://end?now=1",
                     "wakebee://sleep", "https://start?minutes=5"] {
            #expect(command(text) == nil, "\(text)")
        }
    }

    @Test func extendAndEnd() {
        #expect(command("wakebee://extend") == .extend(minutes: 15))
        #expect(command("wakebee://extend?minutes=60") == .extend(minutes: 60))
        #expect(command("wakebee://end") == .end)
        #expect(command("wakebee://stop") == .end)
    }

    @Test func menuBarCountdownRoundsUpToTheMinute() {
        #expect(MenuBarCountdown.string(seconds: 0) == "0m")
        #expect(MenuBarCountdown.string(seconds: 1) == "1m")
        #expect(MenuBarCountdown.string(seconds: 60) == "1m")
        #expect(MenuBarCountdown.string(seconds: 61) == "2m")
        #expect(MenuBarCountdown.string(seconds: 3599) == "1h 00m")
        #expect(MenuBarCountdown.string(seconds: 3600 + 5 * 60) == "1h 05m")
        #expect(MenuBarCountdown.string(seconds: 86400) == "24h 00m")
        #expect(MenuBarCountdown.string(seconds: -30) == "0m")
    }
}
