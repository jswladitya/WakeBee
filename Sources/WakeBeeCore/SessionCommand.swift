import Foundation

/// Automation through the `wakebee://` URL scheme, so scripts and agents can
/// keep the Mac awake for exactly as long as their work runs:
///
///     open "wakebee://start?minutes=90"
///     open "wakebee://start?until=17:30"
///     open "wakebee://start?pid=$$"            # until this shell exits
///     open "wakebee://start?hours=2&pid=4321"  # whichever ends first
///     open "wakebee://extend?minutes=30"
///     open "wakebee://end"
///
/// Commands obey the same license, power, and duration rules as the popover.
/// They never enable closed-lid mode, which stays a deliberate in-app choice.
public enum SessionCommand: Equatable, Sendable {
    case start(SessionDuration, pid: Int32?)
    case toggle(SessionDuration, pid: Int32?)
    case extend(minutes: Int)
    case end

    public static let scheme = "wakebee"

    public init?(url: URL, now: Date = .now, calendar: Calendar = .current) {
        guard url.scheme?.lowercased() == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // Accept both wakebee://start and wakebee:start.
        let host = components.host ?? ""
        let action = (host.isEmpty ? components.path : host).lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            // Reject repeated keys rather than guess which one was meant.
            guard query[item.name.lowercased()] == nil, let value = item.value else { return nil }
            query[item.name.lowercased()] = value
        }

        switch action {
        case "start", "toggle":
            guard Set(query.keys).isSubset(of: ["minutes", "hours", "until", "pid"]),
                  let duration = Self.duration(query, now: now, calendar: calendar) else { return nil }
            var pid: Int32?
            if let text = query["pid"] {
                guard let value = Int32(text), value > 1 else { return nil }
                pid = value
            }
            self = action == "start" ? .start(duration, pid: pid) : .toggle(duration, pid: pid)
        case "extend":
            guard Set(query.keys).isSubset(of: ["minutes"]) else { return nil }
            var minutes = 15
            if let text = query["minutes"] {
                guard let value = Int(text) else { return nil }
                minutes = value
            }
            guard (1...SessionDuration.maximumMinutes).contains(minutes) else { return nil }
            self = .extend(minutes: minutes)
        case "end", "stop":
            guard query.isEmpty else { return nil }
            self = .end
        default:
            return nil
        }
    }

    private static func duration(_ query: [String: String], now: Date, calendar: Calendar) -> SessionDuration? {
        let timed = ["minutes", "hours"].filter { query[$0] != nil }
        guard timed.count + (query["until"] == nil ? 0 : 1) <= 1 else { return nil }
        if let text = query["minutes"] {
            guard let minutes = Int(text) else { return nil }
            let duration = SessionDuration.minutes(minutes)
            return duration.isValid(at: now) ? duration : nil
        }
        if let text = query["hours"] {
            guard let hours = Double(text), hours > 0, hours <= 24 else { return nil }
            let duration = SessionDuration.minutes(Int((hours * 60).rounded()))
            return duration.isValid(at: now) ? duration : nil
        }
        if let text = query["until"] {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts.allSatisfy({ part in (1...2).contains(part.count) && part.allSatisfy { $0.isASCII && $0.isNumber } }),
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute),
                  let end = calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, second: 0),
                                              matchingPolicy: .nextTime, repeatedTimePolicy: .first)
            else { return nil }
            let duration = SessionDuration.until(end)
            return duration.isValid(at: now) ? duration : nil
        }
        return .indefinitely
    }
}
