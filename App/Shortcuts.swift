import AppIntents

/// Siri phrases. The app name must be part of each phrase.
struct LionClubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordPingIntent(),
            phrases: [
                "Test \(.applicationName)",
                "Check \(.applicationName)",
            ],
            shortTitle: "Test LionClub",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SaveParkingSpotIntent(),
            phrases: [
                "Save my parking spot in \(.applicationName)",
                "Remember where I parked with \(.applicationName)",
            ],
            shortTitle: "Save Parking Spot",
            systemImageName: "parkingsign.circle"
        )
    }
}
