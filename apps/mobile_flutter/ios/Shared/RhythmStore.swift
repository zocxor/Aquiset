// Shared by: Runner, AquisetWidgets (and AquisetWatch for the model types).
// Everything here lives in the App Group so widgets, Control Center, Siri
// and the app all read and write the same small store.

import Foundation

enum AquisetShared {
    static let appGroup = "group.com.aquiset.app"
    static let externalLogsNotification = "com.aquiset.app.externalLogs" as CFString
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
}

/// What the widgets show. Written by the Flutter app on every change.
struct RhythmSnapshot: Codable, Equatable {
    var totalMl: Int
    var goalMl: Int
    var drinksToday: Int
    var nextNudge: Date?
    var bedtimeLabel: String
    var wakeLabel: String
    var windDownLabel: String
    var alarmOn: Bool
    var night: Bool
    var updatedAt: Date

    static let placeholder = RhythmSnapshot(
        totalMl: 1250, goalMl: 2000, drinksToday: 4, nextNudge: nil,
        bedtimeLabel: "11:00 pm", wakeLabel: "6:45 am", windDownLabel: "10:30 pm",
        alarmOn: true, night: false, updatedAt: .now
    )

    var progress: Double { goalMl > 0 ? min(1, Double(totalMl) / Double(goalMl)) : 0 }

    /// Totals reset when the snapshot is from an earlier day.
    func forToday(_ now: Date = .now) -> RhythmSnapshot {
        guard !Calendar.current.isDate(updatedAt, inSameDayAs: now) else { return self }
        var copy = self
        copy.totalMl = 0
        copy.drinksToday = 0
        copy.updatedAt = now
        return copy
    }
}

extension RhythmSnapshot {
    init(map: [String: Any]) {
        func ms(_ key: String) -> Date? {
            guard let v = map[key] as? NSNumber else { return nil }
            return Date(timeIntervalSince1970: v.doubleValue / 1000)
        }
        self.init(
            totalMl: (map["totalMl"] as? NSNumber)?.intValue ?? 0,
            goalMl: (map["goalMl"] as? NSNumber)?.intValue ?? 2000,
            drinksToday: (map["drinksToday"] as? NSNumber)?.intValue ?? 0,
            nextNudge: ms("nextNudgeEpochMs"),
            bedtimeLabel: map["bedtimeLabel"] as? String ?? "",
            wakeLabel: map["wakeLabel"] as? String ?? "",
            windDownLabel: map["windDownLabel"] as? String ?? "",
            alarmOn: map["alarmOn"] as? Bool ?? false,
            night: map["night"] as? Bool ?? false,
            updatedAt: ms("updatedEpochMs") ?? .now
        )
    }
}

/// A drink logged outside the app, waiting for Flutter to import it.
struct PendingLog: Codable {
    var id: String
    var ml: Int
    var kind: String
    var epochMs: Int64
    var source: String

    var asMap: [String: Any] { ["id": id, "ml": ml, "kind": kind, "epochMs": epochMs, "source": source] }
}

enum RhythmStore {
    private static let snapshotKey = "rhythm.snapshot.v1"
    private static let pendingKey = "rhythm.pendingLogs.v1"
    private static let launchKey = "rhythm.launchAction.v1"

    static func snapshot() -> RhythmSnapshot {
        guard let data = AquisetShared.defaults.data(forKey: snapshotKey),
              let s = try? JSONDecoder().decode(RhythmSnapshot.self, from: data) else { return .placeholder }
        return s.forToday()
    }

    static func save(_ snapshot: RhythmSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            AquisetShared.defaults.set(data, forKey: snapshotKey)
        }
    }

    /// Queues a drink and updates the snapshot optimistically so the widget
    /// shows the new total immediately, before the app has even opened.
    @discardableResult
    static func appendPendingLog(ml: Int, source: String) -> RhythmSnapshot {
        let kind = [100: "sip", 200: "cup", 250: "glass", 500: "bottle"][ml] ?? "custom"
        let log = PendingLog(
            id: UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            ml: ml, kind: kind,
            epochMs: Int64(Date().timeIntervalSince1970 * 1000),
            source: source
        )
        var queue = pending()
        queue.append(log)
        if let data = try? JSONEncoder().encode(queue) { AquisetShared.defaults.set(data, forKey: pendingKey) }

        var s = snapshot()
        s.totalMl += ml
        s.drinksToday += 1
        s.updatedAt = .now
        save(s)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AquisetShared.externalLogsNotification), nil, nil, true
        )
        return s
    }

    static func pending() -> [PendingLog] {
        guard let data = AquisetShared.defaults.data(forKey: pendingKey) else { return [] }
        return (try? JSONDecoder().decode([PendingLog].self, from: data)) ?? []
    }

    static func drainPendingLogs() -> [PendingLog] {
        let queue = pending()
        AquisetShared.defaults.removeObject(forKey: pendingKey)
        return queue
    }

    static func setLaunchAction(_ action: [String: Any]) {
        AquisetShared.defaults.set(action, forKey: launchKey)
    }

    static func takeLaunchAction() -> [String: Any]? {
        let action = AquisetShared.defaults.dictionary(forKey: launchKey)
        AquisetShared.defaults.removeObject(forKey: launchKey)
        return action
    }
}
