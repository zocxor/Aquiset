# Platform features (iOS 26/27, Android 16/17)

Everything below talks to Flutter through one channel, `aquiset/platform`
(`lib/platform/rhythm_platform.dart`). Every Dart call degrades safely when the
native side is missing, so the app still runs in tests and on unsupported devices.

| Feature | iOS | Android |
|---|---|---|
| Wake alarm | **AlarmKit** (iOS 26+): rings through silent mode and Focus, shows in Dynamic Island and on Apple Watch. Before 26: time-sensitive notifications | `AlarmManager.setAlarmClock` + alarm-usage channel + lock-screen `AlarmActivity`; re-armed after reboot, update, time or zone change |
| Test alarm | AlarmKit `.fixed` schedule in 10 s | one-off exact alarm in 10 s |
| Hydration nudges | provisional (quiet) local notifications | inexact `setAndAllowWhileIdle` + default channel with a "Log a glass" action |
| Home widgets | WidgetKit: Water today (small, medium) and Tonight, with **interactive +250/+500 ml buttons** | Glance "Today" widget with +250 ml button |
| Lock Screen | circular gauge, rectangular, inline accessories | (Android has no lock-screen widgets) |
| Control Center / Action button | `ControlWidget` "Log a glass" (iOS 18+) | static app shortcuts (long-press icon) |
| Siri / Shortcuts / Spotlight | App Intents + App Shortcuts: "Log a glass in AQUISET", "Start wind-down in AQUISET" | — |
| Wind-down countdown | **Live Activity** on Lock Screen and Dynamic Island | **Live Update** (Android 16+): promoted ongoing notification with `ProgressStyle` and a bedtime status-bar chip; ongoing countdown before 16 |
| Watch | watchOS starter app: today's water, +250/+500 ml, bedtime | AlarmManager notifications bridge to Wear OS automatically |

Logs made outside the app (widget, Control Center, Siri, watch) are queued in a shared
store with a device-generated id, shown optimistically on the widget at once, and
imported by the app on resume or immediately if it is open. Ids double as idempotency
keys, so nothing is counted twice.

## iOS setup (Xcode 26+)

1. Run `flutter create --platforms=ios --org com.aquiset .` once, then open
   `ios/Runner.xcworkspace`. Set the bundle id to `com.aquiset.app`.
2. **App Group** `group.com.aquiset.app` on Runner and the widget extension.
3. Add a **Widget Extension** target named `AquisetWidgets` (include Live Activity,
   deployment target iOS 17.0). Replace its generated Swift with
   `ios/AquisetWidgets/AquisetWidgets.swift`.
4. Add `ios/Shared/RhythmStore.swift` and `ios/Shared/AquisetIntents.swift` to
   **both** Runner and AquisetWidgets. Add `ios/Runner/AquisetBridge.swift`,
   `AquisetShortcuts.swift` and the provided `AppDelegate.swift` to Runner only.
5. Optional: add a **watchOS App** target `AquisetWatch` and use
   `ios/AquisetWatch/AquisetWatchApp.swift`.
6. Runner `Info.plist`:
   - `NSAlarmKitUsageDescription`: "AQUISET rings the wake-up alarm you set."
     (AlarmKit refuses to schedule without it.)
   - `NSSupportsLiveActivities` = YES
7. Capabilities: Push Notifications is **not** needed (everything is local). Add
   *Time Sensitive Notifications* for the pre-iOS 26 alarm fallback.
8. If your Flutter template uses the UIScene lifecycle, attach the bridge in the
   implicit-engine callback instead of `didFinishLaunching`.

## Android setup (compileSdk 36+, minSdk 28)

1. Run `flutter create --platforms=android --org com.aquiset .` once. Keep the
   provided `AndroidManifest.xml` (create does not overwrite it), delete the generated
   `kotlin/com/aquiset/aquiset/MainActivity.kt`, and in `android/app/build.gradle.kts`
   set `namespace = "com.aquiset.app"`, `applicationId = "com.aquiset.app"`,
   `minSdk = 28`, `compileSdk = 36` (or newer).
2. Glance needs Compose. Add to `android/app/build.gradle.kts`:
   ```kotlin
   plugins { id("org.jetbrains.kotlin.plugin.compose") }   // version = your Kotlin version
   dependencies {
       implementation("androidx.glance:glance-appwidget:1.1.1")
       implementation("androidx.glance:glance-material3:1.1.1")
       implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
   }
   ```
   Check for newer stable versions before release.
3. Permissions are declared in the manifest. At runtime the app asks for
   notifications (Android 13+) when the person turns the alarm on, and sends them to
   the exact-alarm screen if needed. The alarm card says plainly when exact alarms are
   off ("may ring late").

## Store-policy decisions for the owner

- **Exact alarms (Google Play):** the build declares `SCHEDULE_EXACT_ALARM`
  (user-granted). `USE_EXACT_ALARM` is restricted to apps whose core function is an
  alarm clock; decide with Play policy review before switching.
- **Full-screen intent (Android 14+):** limited to alarm and calling apps and can be
  revoked; the code checks `canUseFullScreenIntent()` and falls back to a heads-up
  notification.
- **Live Updates:** Google's guidance limits them to user-started, time-bound
  activities. Wind-down qualifies only because the person starts it; never post one
  for reminders.
- **AlarmKit:** the alarm presentation is forwarded to a paired Apple Watch by the
  system.

## Next on this list

- Android 17 `MetricStyle` for the wind-down Live Update (bedtime, wake, steps as three
  metrics), once the API 37 reference is final in your toolchain.
- iOS 27 App Intents **intent schemas** so Siri understands natural phrasing without
  fixed phrases.
- Wear OS tile and a watchOS complication.
- Health Connect / HealthKit sleep import (opt-in, blueprint section 13).

None of the native code was compiled in this workspace (no Xcode or Android SDK here).
All Swift and Kotlin files pass a syntax parse; expect a short round of fixes on first
build, mostly around SDK-version-specific signatures (AlarmKit, ProgressStyle, Glance).
