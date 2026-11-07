// AquisetWidgets extension: home & Lock Screen widgets, Control Center
// control and Live Activities. Shares ios/Shared/* with the Runner target.
//
// On iOS 26+ the system renders these in Liquid Glass (clear and tinted
// home screen modes) automatically; `.widgetAccentable()` marks what should
// pick up the tint, and the container background is dropped in accented mode.

import AppIntents
import SwiftUI
import WidgetKit
#if canImport(AlarmKit)
import AlarmKit
#endif

private enum Palette {
    static let aqua = Color(red: 0.024, green: 0.40, blue: 0.427)
    static let aquaNight = Color(red: 0.38, green: 0.84, blue: 0.85)
    static let lav = Color(red: 0.73, green: 0.68, blue: 0.96)
    static let dayTop = Color(red: 0.84, green: 0.92, blue: 0.92)
    static let dayBottom = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let nightTop = Color(red: 0.03, green: 0.06, blue: 0.11)
    static let nightBottom = Color(red: 0.08, green: 0.13, blue: 0.23)
}

@main
struct AquisetWidgetsBundle: WidgetBundle {
    var body: some Widget {
        HydrationWidget()
        SleepWidget()
        WindDownLiveActivity()
        if #available(iOS 18.0, *) {
            QuickLogControl()
        }
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmLiveActivity()
        }
        #endif
    }
}

// MARK: - Timeline

struct RhythmEntry: TimelineEntry {
    let date: Date
    let snapshot: RhythmSnapshot
}

struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        completion(RhythmEntry(date: .now, snapshot: context.isPreview ? .placeholder : RhythmStore.snapshot()))
    }

    /// One entry now, refreshed at midnight so totals reset; the app reloads
    /// timelines on every change in between.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [RhythmEntry(date: .now, snapshot: RhythmStore.snapshot())], policy: .after(midnight)))
    }
}

struct WidgetBackdrop: View {
    let night: Bool

    var body: some View {
        LinearGradient(
            colors: night ? [Palette.nightTop, Palette.nightBottom] : [Palette.dayTop, Palette.dayBottom],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Hydration widget

struct HydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AquisetHydration", provider: RhythmProvider()) { entry in
            HydrationWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(night: entry.snapshot.night) }
        }
        .configurationDisplayName("Water today")
        .description("Your water so far, with one-tap logging.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct HydrationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RhythmEntry

    private var s: RhythmSnapshot { entry.snapshot }
    private var accent: Color { s.night ? Palette.aquaNight : Palette.aqua }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: s.progress) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(String(format: "%.1f", Double(s.totalMl) / 1000))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.totalMl) ml").font(.headline).widgetAccentable()
                Text("of \(s.goalMl) ml · your goal").font(.caption2)
                ProgressView(value: s.progress).tint(accent)
            }
        case .accessoryInline:
            Label("\(s.totalMl) ml today", systemImage: "drop")
        case .systemMedium:
            HStack(spacing: 16) {
                VesselShape(progress: s.progress, accent: accent)
                    .frame(width: 64, height: 104)
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                    Text("\(s.totalMl) ml").font(.system(size: 30, weight: .regular, design: .serif))
                    Text("\(s.drinksToday) drinks · goal \(s.goalMl) ml").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        logButton(ml: 250, title: "Glass")
                        logButton(ml: 500, title: "Bottle")
                    }
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("Water", systemImage: "drop.fill").font(.caption.weight(.bold)).foregroundStyle(accent)
                Text("\(s.totalMl) ml").font(.system(size: 28, weight: .regular, design: .serif)).minimumScaleFactor(0.7)
                ProgressView(value: s.progress).tint(accent)
                Spacer(minLength: 0)
                logButton(ml: 250, title: "250 ml")
            }
        }
    }

    private func logButton(ml: Int, title: String) -> some View {
        Button(intent: LogDrinkIntent(amountMl: ml)) {
            Label(title, systemImage: "plus")
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(accent)
        .widgetAccentable()
    }
}

/// Mini version of the in-app glass vessel.
struct VesselShape: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 22).fill(.white.opacity(0.25))
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [accent.opacity(0.55), accent], startPoint: .top, endPoint: .bottom))
                    .frame(height: max(8, geo.size.height * progress))
                    .widgetAccentable()
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.6), lineWidth: 1))
        }
    }
}

// MARK: - Sleep widget

struct SleepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AquisetSleep", provider: RhythmProvider()) { entry in
            SleepWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(night: true) }
        }
        .configurationDisplayName("Tonight")
        .description("Your wind-down, bedtime and wake alarm.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct SleepWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RhythmEntry

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryInline:
            Label("Bed \(s.bedtimeLabel) · Alarm \(s.alarmOn ? s.wakeLabel : "off")", systemImage: "moon")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Wind-down \(s.windDownLabel)", systemImage: "moon.stars").font(.caption).widgetAccentable()
                Text("Bed \(s.bedtimeLabel)").font(.headline)
                Text(s.alarmOn ? "Alarm \(s.wakeLabel)" : "Alarm off").font(.caption2)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("Tonight", systemImage: "moon.stars.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.lav)
                Text(s.bedtimeLabel).font(.system(size: 28, design: .serif)).foregroundStyle(.white)
                Text("Wind-down \(s.windDownLabel)").font(.caption).foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 0)
                Label(s.alarmOn ? s.wakeLabel : "Alarm off", systemImage: "alarm")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Control Center / Lock Screen / Action button

@available(iOS 18.0, *)
struct QuickLogControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aquiset.app.quicklog") {
            ControlWidgetButton(action: LogDrinkIntent(amountMl: 250)) {
                Label("Log a glass", systemImage: "drop.fill")
            }
        }
        .displayName("Log a glass")
        .description("Adds 250 ml to today in AQUISET.")
    }
}

// MARK: - Live Activities

struct WindDownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WindDownAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill").font(.title2).foregroundStyle(Palette.lav)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wind-down").font(.headline)
                    HStack(spacing: 4) {
                        Text("Bed in")
                        Text(timerInterval: Date.now...max(context.attributes.bedtime, .now), countsDown: true)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
                Spacer()
                Text("\(context.state.stepsDone)/\(context.state.stepsTotal)").font(.title3.monospacedDigit())
            }
            .padding()
            .foregroundStyle(.white)
            .activityBackgroundTint(Palette.nightBottom.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Wind-down", systemImage: "moon.stars.fill").foregroundStyle(Palette.lav)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.stepsDone)/\(context.state.stepsTotal) steps")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Bed in")
                        Text(timerInterval: Date.now...max(context.attributes.bedtime, .now), countsDown: true)
                            .monospacedDigit()
                        Spacer()
                        Label(context.attributes.wake.formatted(date: .omitted, time: .shortened), systemImage: "alarm")
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill").foregroundStyle(Palette.lav)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(context.attributes.bedtime, .now), countsDown: true)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "moon.fill").foregroundStyle(Palette.lav)
            }
        }
    }
}

#if canImport(AlarmKit)
/// AlarmKit needs a Live Activity for its countdown (snooze) presentation,
/// otherwise the system may dismiss the alarm.
@available(iOS 26.0, *)
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<AquisetAlarmMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "alarm.fill").font(.title2)
                Text(context.attributes.presentation.alert.title).font(.headline)
                Spacer()
                Image(systemName: "zzz")
            }
            .padding()
            .foregroundStyle(.white)
            .activityBackgroundTint(Palette.nightBottom.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                }
            } compactLeading: {
                Image(systemName: "alarm")
            } compactTrailing: {
                Image(systemName: "zzz")
            } minimal: {
                Image(systemName: "alarm")
            }
        }
    }
}
#endif
