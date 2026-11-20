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

final class StorageTests: XCTestCase {
    func testCarSnapshotSurvivesSaving() throws {
        let data = try JSONEncoder().encode(CarSnapshot.demo)
        XCTAssertEqual(try JSONDecoder().decode(CarSnapshot.self, from: data), CarSnapshot.demo)
    }
}
