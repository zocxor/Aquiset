// Flutter ⇄ iOS bridge for channel "aquiset/platform".
// Alarms run entirely on-device (AlarmKit on iOS 26+, local notifications
// before that) and never depend on the network, backend or AI services.

import ActivityKit
import Flutter
import SwiftUI
import UIKit
import UserNotifications
import WatchConnectivity
import WidgetKit
#if canImport(AlarmKit)
import AlarmKit
#endif

final class AquisetBridge: NSObject {
    static let shared = AquisetBridge()
    private var channel: FlutterMethodChannel?

    func attach(to messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "aquiset/platform", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
        self.channel = channel
        WatchSync.shared.activate()
        observeExternalLogs()
        NotificationCenter.default.addObserver(
            self, selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    /// Tell Dart that widgets / Siri / the watch queued drinks.
    func notifyExternalLogs() {
        channel?.invokeMethod("externalLogsAvailable", arguments: nil)
    }

    @objc private func didBecomeActive() {
        if let action = RhythmStore.takeLaunchAction() {
            channel?.invokeMethod("action", arguments: action)
        }
        if !RhythmStore.pending().isEmpty { notifyExternalLogs() }
    }

    private func observeExternalLogs() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let bridge = Unmanaged<AquisetBridge>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { bridge.notifyExternalLogs() }
            },
            AquisetShared.externalLogsNotification, nil, .deliverImmediately
        )
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "alarm.capability":
            Task { @MainActor in result(await Alarms.capability()) }
        case "alarm.requestPermission":
            Task { @MainActor in result(await Alarms.requestPermission()) }
        case "alarm.schedule":
            Task { @MainActor in result(await Alarms.schedule(AlarmSpec(args))) }
        case "alarm.cancel":
            Task { @MainActor in
                await Alarms.cancel(id: args["id"] as? String ?? "")
                result(nil)
            }
        case "alarm.test":
            Task { @MainActor in result(await Alarms.test(seconds: (args["seconds"] as? NSNumber)?.intValue ?? 10)) }
        case "alarm.openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            result(nil)
        case "nudge.schedule":
            Nudges.schedule(args)
            result(nil)
        case "nudge.cancelAll":
            Nudges.cancelAll()
            result(nil)
        case "widgets.publish":
            RhythmStore.save(RhythmSnapshot(map: args))
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
            WatchSync.shared.push(args)
            result(nil)
        case "widgets.drainLogs":
            result(RhythmStore.drainPendingLogs().map(\.asMap))
        case "live.start":
            Task { @MainActor in result(await WindDownActivity.start(args)) }
        case "live.update":
            Task { @MainActor in
                await WindDownActivity.update(args)
                result(nil)
            }
        case "live.end":
            Task { @MainActor in
                await WindDownActivity.end()
                result(nil)
            }
        case "launch.take":
            result(RhythmStore.takeLaunchAction())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Alarms

struct AlarmSpec {
    var id: String
    var hour: Int
    var minute: Int
    var weekdays: [Int] // ISO, 1 = Monday
    var label: String
    var snoozeMinutes: Int

    init(_ m: [String: Any]) {
        id = m["id"] as? String ?? "wake"
        hour = (m["hour"] as? NSNumber)?.intValue ?? 7
        minute = (m["minute"] as? NSNumber)?.intValue ?? 0
        weekdays = (m["weekdays"] as? [NSNumber])?.map(\.intValue) ?? []
        label = m["label"] as? String ?? "Good morning"
        snoozeMinutes = (m["snoozeMinutes"] as? NSNumber)?.intValue ?? 9
    }

    init(id: String, hour: Int, minute: Int, weekdays: [Int], label: String, snoozeMinutes: Int) {
        self.id = id; self.hour = hour; self.minute = minute
        self.weekdays = weekdays; self.label = label; self.snoozeMinutes = snoozeMinutes
    }
}

/// Stable UUIDs for our string alarm ids (AlarmKit identifies alarms by UUID).
enum AlarmIDs {
    private static let key = "alarm.uuidMap.v1"

    static func uuid(for id: String) -> UUID {
        var map = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        if let s = map[id], let uuid = UUID(uuidString: s) { return uuid }
        let uuid = UUID()
        map[id] = uuid.uuidString
        UserDefaults.standard.set(map, forKey: key)
        return uuid
    }
}

enum Alarms {
    static func capability() async -> [String: Any] {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return AlarmKitEngine.capability() }
        #endif
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return ["backend": "notifications", "authorized": status == .authorized,
                "exactAllowed": true, "canRequest": status == .notDetermined]
    }

    static func requestPermission() async -> [String: Any] {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return await AlarmKitEngine.requestPermission() }
        #endif
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        return await capability()
    }

    static func schedule(_ spec: AlarmSpec) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return await AlarmKitEngine.schedule(spec) }
        #endif
        return NotificationAlarms.schedule(spec)
    }

    static func cancel(id: String) async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { AlarmKitEngine.cancel(id: id); return }
        #endif
        NotificationAlarms.cancel(id: id)
    }

    static func test(seconds: Int) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) { return await AlarmKitEngine.test(seconds: seconds) }
        #endif
        return NotificationAlarms.test(seconds: seconds)
    }
}

#if canImport(AlarmKit)
/// Real alarms: ring through silent mode and Focus, show in the Dynamic
/// Island and on a paired Apple Watch. Needs NSAlarmKitUsageDescription.
@available(iOS 26.0, *)
enum AlarmKitEngine {
    private static var manager: AlarmManager { .shared }

    static func capability() -> [String: Any] {
        let state = manager.authorizationState
        return ["backend": "alarmKit", "authorized": state == .authorized,
                "exactAllowed": true, "canRequest": state == .notDetermined]
    }

    static func requestPermission() async -> [String: Any] {
        _ = try? await manager.requestAuthorization()
        return capability()
    }

    static func schedule(_ spec: AlarmSpec) async -> Bool {
        let id = AlarmIDs.uuid(for: spec.id)
        try? manager.cancel(id: id)
        let days = spec.weekdays.compactMap(Locale.Weekday.fromISO)
        let weekly = Alarm.Schedule.relative(.init(
            time: .init(hour: spec.hour, minute: spec.minute),
            repeats: days.isEmpty ? .never : .weekly(days)
        ))
        return await register(id: id, schedule: weekly, spec: spec)
    }

    static func cancel(id: String) {
        try? manager.cancel(id: AlarmIDs.uuid(for: id))
    }

    static func test(seconds: Int) async -> Bool {
        let spec = AlarmSpec(id: "test", hour: 0, minute: 0, weekdays: [], label: "Test alarm", snoozeMinutes: 9)
        return await register(id: UUID(), schedule: .fixed(Date().addingTimeInterval(TimeInterval(seconds))), spec: spec)
    }

    private static func register(id: UUID, schedule: Alarm.Schedule, spec: AlarmSpec) async -> Bool {
        let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        let snooze = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")
        let pause = AlarmButton(text: "Pause", textColor: .white, systemImageName: "pause.circle")
        let resume = AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.circle")
        let presentation = AlarmPresentation(
            alert: .init(
                title: LocalizedStringResource(stringLiteral: spec.label),
                stopButton: stop,
                secondaryButton: snooze,
                secondaryButtonBehavior: .countdown
            ),
            countdown: .init(title: "Snoozing", pauseButton: pause),
            paused: .init(title: "Paused", resumeButton: resume)
        )
        let attributes = AlarmAttributes<AquisetAlarmMetadata>(
            presentation: presentation,
            metadata: AquisetAlarmMetadata(),
            tintColor: Color(red: 0.024, green: 0.40, blue: 0.427)
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: TimeInterval(spec.snoozeMinutes * 60)),
            schedule: schedule,
            attributes: attributes
        )
        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            return true
        } catch {
            return false
        }
    }
}

extension Locale.Weekday {
    static func fromISO(_ day: Int) -> Locale.Weekday? {
        switch day {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        case 7: return .sunday
        default: return nil
        }
    }
}
#endif

/// Fallback before iOS 26: time-sensitive notifications. Honest limitation:
/// silent mode can mute them, and the alarm card says so.
enum NotificationAlarms {
    private static func ids(_ id: String) -> [String] { (0...7).map { "alarm.\(id).\($0)" } }

    static func schedule(_ spec: AlarmSpec) -> Bool {
        cancel(id: spec.id)
        let content = UNMutableNotificationContent()
        content.title = spec.label
        content.body = "Time to wake up"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let center = UNUserNotificationCenter.current()
        let days = spec.weekdays.isEmpty ? [0] : spec.weekdays
        for day in days {
            var date = DateComponents(hour: spec.hour, minute: spec.minute)
            if day > 0 { date.weekday = day % 7 + 1 } // ISO → Gregorian (Sunday = 1)
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: !spec.weekdays.isEmpty)
            center.add(UNNotificationRequest(identifier: "alarm.\(spec.id).\(day)", content: content, trigger: trigger))
        }
        return true
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids(id))
    }

    static func test(seconds: Int) -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "Test alarm"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "alarm.test.0", content: content, trigger: trigger))
        return true
    }
}

// MARK: - Hydration nudges

enum Nudges {
    /// Uses provisional authorization: nudges arrive quietly in Notification
    /// Center without an upfront prompt, matching "calm by default".
    static func schedule(_ args: [String: Any]) {
        guard let ms = args["epochMs"] as? NSNumber else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .provisional]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = args["title"] as? String ?? "A gentle nudge"
            content.body = args["body"] as? String ?? ""
            content.interruptionLevel = .passive
            content.threadIdentifier = "hydration"
            let seconds = max(1, ms.doubleValue / 1000 - Date().timeIntervalSince1970)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            center.add(UNNotificationRequest(identifier: "nudge", content: content, trigger: trigger))
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nudge"])
    }
}

// MARK: - Wind-down Live Activity

enum WindDownActivity {
    private static func content(_ args: [String: Any]) -> WindDownAttributes.ContentState {
        .init(stepsDone: (args["stepsDone"] as? NSNumber)?.intValue ?? 0,
              stepsTotal: (args["stepsTotal"] as? NSNumber)?.intValue ?? 4)
    }

    private static func date(_ args: [String: Any], _ key: String) -> Date {
        Date(timeIntervalSince1970: ((args[key] as? NSNumber)?.doubleValue ?? 0) / 1000)
    }

    static func start(_ args: [String: Any]) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        await end()
        let attributes = WindDownAttributes(bedtime: date(args, "bedtimeEpochMs"), wake: date(args, "wakeEpochMs"))
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: content(args), staleDate: attributes.wake),
                pushType: nil
            )
            return true
        } catch {
            return false
        }
    }

    static func update(_ args: [String: Any]) async {
        for activity in Activity<WindDownAttributes>.activities {
            await activity.update(.init(state: content(args), staleDate: activity.attributes.wake))
        }
    }

    static func end() async {
        for activity in Activity<WindDownAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

// MARK: - Apple Watch

final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ map: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(map.compactMapValues { $0 is NSNull ? nil : $0 })
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let ml = (userInfo["logMl"] as? NSNumber)?.intValue else { return }
        RhythmStore.appendPendingLog(ml: ml, source: "watch")
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
            AquisetBridge.shared.notifyExternalLogs()
        }
    }
}
