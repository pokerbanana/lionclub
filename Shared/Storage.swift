import Foundation

/// Storage shared by the app and its widgets.
///
/// Sideloading tools can rename the App Group when they re-sign the app with a free Apple ID,
/// so the real name is looked up at runtime: first the names AltStore/SideStore write into
/// Info.plist (`ALTAppGroups`), then the one in project.yml.
enum AppGroup {
    static let defaultID = "group.io.github.pokerbanana.lionclub"

    /// The App Group this install can use, or nil if it has none (then the widget can't see app data).
    static let id: String? = {
        candidates().first { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
    }()

    static var isShared: Bool { id != nil }

    static var defaults: UserDefaults {
        if let id, let shared = UserDefaults(suiteName: id) {
            return shared
        }
        return .standard
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func candidates() -> [String] {
        var names: [String] = []
        for bundle in [Bundle.main, hostAppBundle].compactMap({ $0 }) {
            if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
                names.append(contentsOf: groups)
            }
        }
        names.append(defaultID)
        return names
    }

    /// Inside the widget extension, the app bundle is two folders up (LionClub.app/PlugIns/X.appex).
    private static var hostAppBundle: Bundle? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "appex" else { return nil }
        return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    }
}

/// What the widgets show: the last car status the app saved.
struct CarSnapshot: Codable, Equatable {
    var fuelPercent: Double?
    var rangeKm: Double?
    var odometerKm: Double?
    var locked: Bool?
    var updatedAt: Date
    var isDemo: Bool

    static let demo = CarSnapshot(
        fuelPercent: 62,
        rangeKm: 540,
        odometerKm: 48_215,
        locked: true,
        updatedAt: Date(),
        isDemo: true
    )

    private static let key = "carSnapshot"

    static func load() -> CarSnapshot? { AppGroup.load(CarSnapshot.self, key: key) }
    func save() { AppGroup.save(self, key: Self.key) }
}

/// The last time a Siri phrase, Shortcut, Control Center button or widget button ran.
struct Ping: Codable, Equatable {
    var source: String
    var at: Date

    private static let key = "lastPing"

    static func load() -> Ping? { AppGroup.load(Ping.self, key: key) }
    func save() { AppGroup.save(self, key: Self.key) }
}

/// Where the car was left, from the iPhone's location when the parking action ran.
struct ParkingSpot: Codable, Equatable {
    var latitude: Double?
    var longitude: Double?
    var savedAt: Date

    private static let key = "parkingSpot"

    static func load() -> ParkingSpot? { AppGroup.load(ParkingSpot.self, key: key) }
    func save() { AppGroup.save(self, key: Self.key) }
}
