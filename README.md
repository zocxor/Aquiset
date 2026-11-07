# AQUISET

A calm daily-rhythm companion for hydration, sleep and waking, for iOS and Android,
built in Flutter with a custom **Liquid Glass** design system and native platform
features (AlarmKit alarms, interactive widgets, Live Activities / Live Updates, Siri and
Shortcuts, Control Center, Apple Watch).

Not a medical device: no diagnosis, no medical fluid targets, no sleep scores.

## What's here

```
apps/mobile_flutter/
  lib/
    core/design/            tokens (Day/Night), type, motion, environment
    core/design/glass/      GlassSurface, LiquidGlassNavBar, buttons, switch, segmented, toast
    core/design/            nature backdrop, rise-in
    core/time/              MinuteOfDay (midnight-safe schedule maths)
    features/hydration/     domain (DrinkLog, ReminderPlanner), data, controller, dashboard, vessel
    features/sleep/         domain (SleepSchedule, consistency), controller, dashboard, dial
    features/rituals/       optional challenges
    features/settings/      appearance, comfort, reminders, data export/delete
    platform/               RhythmPlatform: the one typed bridge to native code
    app/                    app, shell (backdrop, header, nav, toasts), service scope
  test/                     reminder rules, sleep maths, platform parsing
  ios/                      AquisetBridge (AlarmKit, nudges, Live Activity, watch sync),
                            App Intents + Shortcuts, widget extension, watchOS starter
  android/                  bridge, exact alarms + lock-screen alarm, nudges,
                            Live Update, Glance widget, shortcuts, manifest
services/api/openapi.yaml   /v1 sync API
supabase/migrations/        schema with row-level security
docs/                       DESIGN_SYSTEM (replaces blueprint §04), PLATFORM_FEATURES, ARCHITECTURE
```

## Run it

Prerequisites: Flutter 3.29 or newer (stable), Xcode 26+, Android Studio with SDK 36+.

```bash
cd apps/mobile_flutter
flutter create --platforms=android,ios --org com.aquiset .   # generates the platform shells; keeps our files
flutter pub get
flutter analyze
flutter test
flutter run
```

Then follow **docs/PLATFORM_FEATURES.md** once per platform to add the widget
extension, App Group, Glance dependencies and Info.plist keys.

Backend (optional for now; the app is fully offline-first):

```bash
supabase start
supabase db reset          # applies supabase/migrations
cp ../../.env.example .env # fill in your project URL and anon key
```

## Verification status

| Check | Result |
|---|---|
| Dart syntax (30 files) | pass (tree-sitter parse) |
| Swift (7) and Kotlin (8) syntax | pass (tree-sitter parse) |
| SQL migration | parses with the PostgreSQL parser (pglast) |
| OpenAPI spec | validates as OpenAPI 3.1 |
| Reminder rules | test expectations confirmed by an independent port of the planner |
| Colour contrast | every text token ≥ 4.5:1 on every glass weight, both modes (docs/DESIGN_SYSTEM.md §3) |
| `flutter analyze`, `flutter test`, device builds | **not run**: Flutter, Xcode and the Android SDK were not available where this was built. Run them first. |

Expect a short round of fixes on first native build, mostly SDK-version-specific
signatures in AlarmKit, `Notification.ProgressStyle` and Glance.

## Principles carried from the blueprint

Calm by default (no guilt or streak shaming), reminders capped and never escalating,
alarms independent of network/backend/AI, health copy sourced and marked "review
pending" until a qualified reviewer approves it, no ads at launch, export and delete
available from day one.
