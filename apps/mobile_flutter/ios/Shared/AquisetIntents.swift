// Shared by: Runner, AquisetWidgets.
// App Intents power interactive widget buttons, the Control Center control,
// the Action button, Siri and the Shortcuts app with one implementation.

import ActivityKit
import AppIntents
import WidgetKit
#if canImport(AlarmKit)
import AlarmKit
#endif

struct LogDrinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a drink"
    static let description = IntentDescription("Adds a drink to today's water in AQUISET.")
    static let openAppWhenRun = false

    @Parameter(title: "Amount (ml)", default: 250, inclusiveRange: (50, 1500))
    var amountMl: Int

    init() {}

    init(amountMl: Int) {
        self.amountMl = amountMl
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = RhythmStore.appendPendingLog(ml: amountMl, source: "shortcut")
        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        return .result(dialog: "Logged \(amountMl) ml. \(snapshot.totalMl) ml today.")
    }
}

struct StartWindDownIntent: AppIntent {
    static let title: LocalizedStringResource = "Start wind-down"
    static let description = IntentDescription("Opens AQUISET's wind-down and starts the bedtime countdown.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        RhythmStore.setLaunchAction(["type": "startWindDown"])
        return .result()
    }
}

/// Live Activity for the wind-down countdown (Lock Screen + Dynamic Island).
struct WindDownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepsDone: Int
        var stepsTotal: Int
    }

    var bedtime: Date
    var wake: Date
}

#if canImport(AlarmKit)
/// AlarmKit metadata. Empty for now; add fields to customise the alarm's
/// Live Activity (for example the day's planned rest).
@available(iOS 26.0, *)
struct AquisetAlarmMetadata: AlarmMetadata {}
#endif
