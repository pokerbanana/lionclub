import Foundation

/// Peugeot sign-in settings for one country. They are the official MyPeugeot app's settings,
/// taken from the Home Assistant Stellantis integration (see NOTICE.md).
struct PeugeotConfig {
    enum LoadError: Error {
        case missingFile
        case unknownCountry(String)
    }

    let oauthURL: String
    let realm: String
    let scheme: String
    let locale: String
    let clientID: String
    let clientSecret: String
    let country: String

    var redirectURI: String { "\(scheme)://oauth2redirect/\(country.lowercased())" }

    /// Peugeot's own login page. After signing in, it sends the browser to `redirectURI` with a one-time code.
    var authorizeURL: URL {
        URL(string: "\(oauthURL)/am/oauth2/authorize?client_id=\(clientID)&response_type=code"
            + "&redirect_uri=\(redirectURI)&scope=openid%20profile%20email&locale=\(locale)")!
    }

    static func load(country: String, bundle: Bundle = .main) throws -> PeugeotConfig {
        guard let url = bundle.url(forResource: "peugeot_configs", withExtension: "json") else {
            throw LoadError.missingFile
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        let code = country.uppercased()
        guard let entry = file.MyPeugeot.configs[code] else {
            throw LoadError.unknownCountry(code)
        }
        return PeugeotConfig(
            oauthURL: file.MyPeugeot.oauth_url,
            realm: file.MyPeugeot.realm,
            scheme: file.MyPeugeot.scheme,
            locale: entry.locale,
            clientID: entry.client_id,
            clientSecret: entry.client_secret,
            country: code
        )
    }

    private struct File: Decodable {
        let MyPeugeot: Brand
    }

    private struct Brand: Decodable {
        let oauth_url: String
        let realm: String
        let scheme: String
        let configs: [String: Entry]
    }

    private struct Entry: Decodable {
        let client_id: String
        let client_secret: String
        let locale: String
    }
}
