import Foundation

/// Talks to Peugeot's servers the same way the MyPeugeot app does. The flow follows LionFlow and
/// the Home Assistant Stellantis integration (see NOTICE.md). The token only lives in memory.
struct PeugeotClient {
    enum ClientError: LocalizedError {
        case http(Int, String)
        case unexpectedAnswer(String)

        var errorDescription: String? {
            switch self {
            case .http(let code, let step): return "\(step) failed (Peugeot answered HTTP \(code))."
            case .unexpectedAnswer(let step): return "\(step): Peugeot sent an unexpected answer."
            }
        }
    }

    static let apiBase = "https://api.groupe-psa.com"

    let config: PeugeotConfig
    let accessToken: String

    /// Trades the one-time code from Peugeot's login page for a token.
    static func signIn(config: PeugeotConfig, code: String) async throws -> PeugeotClient {
        let step = "Signing in"
        let address = "\(config.oauthURL)/am/oauth2/access_token?redirect_uri=\(config.redirectURI)"
            + "&grant_type=authorization_code&code=\(encode(code))"
        guard let url = URL(string: address) else { throw ClientError.unexpectedAnswer(step) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data()
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let basic = Data("\(config.clientID):\(config.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        let json = try await send(request, step: step)
        guard let token = (json as? [String: Any])?["access_token"] as? String else {
            throw ClientError.unexpectedAnswer(step)
        }
        return PeugeotClient(config: config, accessToken: token)
    }

    /// The cars on the account, as Peugeot describes them (id, vin, brand, motorization, links).
    func vehicles() async throws -> [[String: Any]] {
        let json = try await get("\(Self.apiBase)/connectedcar/v4/user/vehicles?\(query)", step: "Listing your cars")
        let embedded = (json as? [String: Any])?["_embedded"] as? [String: Any]
        return embedded?["vehicles"] as? [[String: Any]] ?? []
    }

    /// Everything Peugeot's cloud knows about the car right now.
    func status(vehicleID: String) async throws -> [String: Any] {
        let step = "Reading the car's status"
        let json = try await get("\(Self.apiBase)/connectedcar/v4/user/vehicles/\(vehicleID)/status?\(query)", step: step)
        guard let status = json as? [String: Any] else { throw ClientError.unexpectedAnswer(step) }
        return status
    }

    /// Next service (km and days to go), if Peugeot has it. Some cars answer 404 here.
    func maintenance(vehicle: [String: Any]) async -> [String: Any]? {
        var addresses: [String] = []
        let links = vehicle["_links"] as? [String: Any]
        if let href = (links?["maintenance"] as? [String: Any])?["href"] as? String {
            addresses.append(href)
        }
        if let id = vehicle["id"] as? String {
            addresses.append("\(Self.apiBase)/connectedcar/v4/user/vehicles/\(id)/maintenance")
        }
        for address in addresses {
            let separator = address.contains("?") ? "&" : "?"
            if let json = try? await get(address + separator + query, step: "Reading service data") as? [String: Any],
               json["mileageBeforeMaintenance"] != nil || json["daysBeforeMaintenance"] != nil {
                return json
            }
        }
        return nil
    }

    /// Whether Peugeot links a remote-services account to this login (needed for lock/unlock).
    func hasRemoteServicesLink() async -> Bool {
        guard var request = authorized("\(Self.apiBase)/applications/cvs/v4/mauv/car-associations?\(query)") else {
            return false
        }
        request.setValue("okhttp/4.8.0", forHTTPHeaderField: "User-Agent")
        request.setValue("1234", forHTTPHeaderField: "x-transaction-id")
        guard let list = try? await Self.send(request, step: "Checking remote services") as? [[String: Any]] else {
            return false
        }
        return list.contains { ($0["customer"] as? String)?.isEmpty == false }
    }

    // MARK: - Requests

    private var query: String { "client_id=\(config.clientID)&locale=\(config.locale)" }

    private func authorized(_ address: String) -> URLRequest? {
        guard let url = URL(string: address) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(config.realm, forHTTPHeaderField: "x-introspect-realm")
        request.setValue("application/hal+json", forHTTPHeaderField: "Accept")
        return request
    }

    private func get(_ address: String, step: String) async throws -> Any {
        guard let request = authorized(address) else { throw ClientError.unexpectedAnswer(step) }
        return try await Self.send(request, step: step)
    }

    private static func send(_ request: URLRequest, step: String) async throws -> Any {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ClientError.http(status, step) }
        if data.isEmpty { return [String: Any]() }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? text
    }
}
