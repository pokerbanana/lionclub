import AppIntents
import CoreLocation
import WidgetKit

/// Records that LionClub ran. Used to check Siri, Shortcuts, Control Center and the widget button.
struct RecordPingIntent: AppIntent {
    static let title: LocalizedStringResource = "Test LionClub"

    @Parameter(title: "Source")
    var source: String?

    init() {}

    init(source: String) {
        self.source = source
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        Ping(source: source ?? "Siri or Shortcuts", at: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "LionClub works.")
    }
}

/// Saves where the car is parked. Meant for a Shortcuts automation that runs when the iPhone
/// disconnects from the car's CarPlay or Bluetooth.
struct SaveParkingSpotIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Parking Spot"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let coordinate = await currentCoordinate()
        ParkingSpot(latitude: coordinate?.latitude, longitude: coordinate?.longitude, savedAt: Date()).save()
        WidgetCenter.shared.reloadAllTimelines()
        if coordinate == nil {
            return .result(dialog: "Saved the time, but your location wasn't available.")
        }
        return .result(dialog: "Parking spot saved.")
    }
}

/// Best effort: the iPhone's current position, or nil without permission or after `timeout` seconds.
func currentCoordinate(timeout: Double = 10) async -> CLLocationCoordinate2D? {
    let status = CLLocationManager().authorizationStatus
    guard status == .authorizedAlways || status == .authorizedWhenInUse else { return nil }
    return await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
        group.addTask {
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location {
                        return location.coordinate
                    }
                }
            } catch {}
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}
