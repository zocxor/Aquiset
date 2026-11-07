# Architecture

```
Flutter UI (glass design system, screens)
   │  ChangeNotifier controllers: Settings, Hydration, Sleep
   │  Pure domain: ReminderPlanner, SleepSchedule, MinuteOfDay
   │  Repositories: offline-first local store → sync outbox
   ├── RhythmPlatform (MethodChannel "aquiset/platform")
   │      iOS: AlarmKit · UserNotifications · WidgetKit · ActivityKit · App Intents · WatchConnectivity
   │      Android: AlarmManager · Notifications/Live Updates · Glance · Shortcuts
   └── Sync (next slice): REST /v1 (services/api/openapi.yaml) → Supabase Postgres with RLS
```

Alarm-critical paths never touch the network, backend or AI.

## Decision records

**ADR-0001: Flutter for shared UI, native for platform features.**
Flutter renders our own glass consistently on both platforms; widgets, alarms, Live
Activities and intents are only available natively, so they live in Swift/Kotlin behind
one typed channel.

**ADR-0002: Own glass primitive instead of a Liquid Glass package.**
Flutter's Cupertino library still has no built-in Liquid Glass and the main community
renderer is pre-release. `GlassSurface` (blur + saturation + rim light) is small, ours,
works on Android, and has a solid fallback. Revisit when `package:cupertino` ships
native Liquid Glass.

**ADR-0003: ChangeNotifier + InheritedWidget, no state library yet.**
Three controllers and one scope keep the dependency surface small. Move to Riverpod if
the controller graph grows past ~8 or needs async families.

**ADR-0004: SharedPreferences for local data in the MVP.**
Small volumes (≈ 3,000 logs a year). Move to SQLite (drift) when multi-month history
screens land. Repository interface already isolates this.

**ADR-0005: Device-generated ids as idempotency keys.**
Every log gets a 128-bit id on the device (app, widget, Siri, watch). The server
enforces `unique (user_id, client_id)`, so retries and offline replays never duplicate.

**ADR-0006: Reminder rules are pure and tested.**
`ReminderPlanner` encodes blueprint section 05 (waking window, cooldown, snooze, quiet
hours, daily cap, no escalation, clinician plan switch) with unit tests; the controller
only schedules the single next nudge.

**ADR-0007: Honest alarm status.**
The UI always states what the device will actually do (AlarmKit, exact, inexact, or
notification-only) rather than promising delivery.

## Open decisions (owner)

- Supabase vs NestJS + Postgres for the sync service.
- Health-content reviewer and approved source library (cards show "review pending").
- Play policy route for exact alarms (see PLATFORM_FEATURES.md).
- Minimum OS versions: proposed iOS 17 (AlarmKit features on 26+) and Android 9 (API 28).
