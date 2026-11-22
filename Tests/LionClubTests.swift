import XCTest
@testable import LionClub

final class PeugeotConfigTests: XCTestCase {
    func testCroatiaSettingsBuildPeugeotsLoginAddress() throws {
        let config = try PeugeotConfig.load(country: "HR")
        XCTAssertEqual(config.locale, "hr-HR")
        XCTAssertEqual(config.scheme, "mymap")
        XCTAssertEqual(config.redirectURI, "mymap://oauth2redirect/hr")
        XCTAssertTrue(config.authorizeURL.absoluteString.hasPrefix("https://idpcvs.peugeot.com/am/oauth2/authorize?client_id="))
        XCTAssertTrue(config.authorizeURL.absoluteString.contains("redirect_uri=mymap://oauth2redirect/hr"))
    }

    func testSerbiaIsNotAPeugeotSignInCountry() {
        XCTAssertThrowsError(try PeugeotConfig.load(country: "RS"))
    }
}

final class CloudTestReportTests: XCTestCase {
    private let vehicle: [String: Any] = ["id": "car-1", "vin": "VR3UHZKXZLT123456", "brand": "Peugeot", "motorization": "Thermic"]
    private let now = ISO8601DateFormatter().date(from: "2026-11-23T12:00:00Z")!

    /// A petrol car's status, shaped like Peugeot's answers (field names from LionFlow and Home Assistant).
    private func status(updated: String, lockedStates: [String] = ["Locked"], openDoor: String? = nil) throws -> [String: Any] {
        let opening = openDoor.map { "[{\"identifier\": \"\($0)\", \"state\": \"Open\"}]" } ?? "[{\"identifier\": \"Driver\", \"state\": \"Closed\"}]"
        let locked = lockedStates.map { "\"\($0)\"" }.joined(separator: ",")
        let json = """
        {
          "energies": [{"type": "Fuel", "level": 49, "autonomy": 310, "updatedAt": "\(updated)"}],
          "odometer": {"mileage": 48215.6, "createdAt": "\(updated)"},
          "doorsState": {"lockedStates": [\(locked)], "opening": \(opening)},
          "lastPosition": {"type": "Feature", "geometry": {"type": "Point", "coordinates": [20.46, 44.81, 117]},
                           "properties": {"updatedAt": "2026-11-23T08:10:00.000Z"}}
        }
        """
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testCarReportingToday() throws {
        let report = CloudTestReport.make(
            vehicle: vehicle,
            status: try status(updated: "2026-11-23T08:14:00Z"),
            maintenance: ["mileageBeforeMaintenance": 12000, "daysBeforeMaintenance": 210],
            remoteLink: false,
            now: now
        )
        XCTAssertEqual(report.carName, "Peugeot Thermic")
        XCTAssertEqual(report.vinEnd, "3456")
        XCTAssertEqual(report.verdict, .live)
        XCTAssertTrue(report.lines.contains("Fuel: 49 %, range 310 km"))
        XCTAssertTrue(report.lines.contains("Odometer: 48215 km"))
        XCTAssertTrue(report.lines.contains("Locked: yes"))
        XCTAssertTrue(report.lines.contains("Position sent by the car: yes"))
        XCTAssertTrue(report.lines.contains("Next service: in 12000 km / 210 days"))
        XCTAssertTrue(report.lines.contains("Remote-services link (needed for lock/unlock): no"))
    }

    func testCarSilentForTenDays() throws {
        let report = CloudTestReport.make(
            vehicle: vehicle,
            status: try status(updated: "2026-11-13T08:00:00Z").filter { $0.key != "lastPosition" },
            maintenance: nil,
            remoteLink: false,
            now: now
        )
        XCTAssertEqual(report.verdict, .stale(days: 10))
        XCTAssertTrue(report.lines.contains("Position sent by the car: no"))
    }

    func testUnlockedCarWithOpenDoor() throws {
        let report = CloudTestReport.make(
            vehicle: vehicle,
            status: try status(updated: "2026-11-23T08:14:00Z", lockedStates: ["Unlocked"], openDoor: "Driver"),
            maintenance: nil,
            remoteLink: true,
            now: now
        )
        XCTAssertTrue(report.lines.contains("Locked: no"))
        XCTAssertTrue(report.lines.contains("Open: Driver"))
        XCTAssertTrue(report.lines.contains("Remote-services link (needed for lock/unlock): yes"))
    }

    func testNoStatusFromCloud() {
        let report = CloudTestReport.make(vehicle: vehicle, status: nil, maintenance: nil, remoteLink: false, now: now)
        XCTAssertEqual(report.verdict, .noStatus)
        XCTAssertFalse(report.isLive)
    }

    func testDatesWithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(CloudTestReport.parseDate("2026-11-23T08:14:00Z"))
        XCTAssertNotNil(CloudTestReport.parseDate("2026-11-23T08:10:00.000Z"))
        XCTAssertNil(CloudTestReport.parseDate("yesterday"))
    }
}

final class StorageTests: XCTestCase {
    func testCarSnapshotSurvivesSaving() throws {
        let data = try JSONEncoder().encode(CarSnapshot.demo)
        XCTAssertEqual(try JSONDecoder().decode(CarSnapshot.self, from: data), CarSnapshot.demo)
    }
}
