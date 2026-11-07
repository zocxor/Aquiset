// Runner target only: App Shortcuts must live in the app bundle.
// Gives Siri, Spotlight, the Shortcuts app and the Action button ready-made
// phrases with no setup by the person.

import AppIntents

struct AquisetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDrinkIntent(),
            phrases: [
                "Log a glass in \(.applicationName)",
                "Log water in \(.applicationName)",
                "Add a drink to \(.applicationName)",
            ],
            shortTitle: "Log a drink",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: StartWindDownIntent(),
            phrases: [
                "Start wind-down in \(.applicationName)",
                "Time to wind down with \(.applicationName)",
            ],
            shortTitle: "Wind down",
            systemImageName: "moon.stars.fill"
        )
    }
}
