import SwiftUI
import AuthenticationServices
import LocalAuthentication
import WidgetKit

/// One-time checks that the free install works on this iPhone: shared storage for the widget,
/// Face ID, Peugeot's login page, Siri and Control Center, and the parking-spot automation.
struct ChecksView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var location = LocationAccess()

    @State private var widgetResult = ""
    @State private var faceIDResult = "Not tested yet"
    @State private var loginResult = "Not tested yet"
    @State private var lastPing = Ping.load()
    @State private var lastSpot = ParkingSpot.load()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Shared with widget", value: AppGroup.isShared ? "Yes" : "No")
                    if let id = AppGroup.id {
                        Text(id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Send a test value to the widget") { sendToWidget() }
                    if !widgetResult.isEmpty {
                        Text(widgetResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("1. Widget")
                } footer: {
                    Text("Add the LionClub widget to your Home Screen. After you tap the button, the time on the widget should change.")
                }

                Section("2. Face ID") {
                    Button("Test Face ID") {
                        Task { faceIDResult = await testFaceID() }
                    }
                    Text(faceIDResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Open Peugeot login (Croatia)") {
                        Task { loginResult = await testPeugeotLogin() }
                    }
                    Text(loginResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("3. Peugeot login")
                } footer: {
                    Text("Checks that Peugeot's login page opens and sends a code back to LionClub. The code isn't used or stored.")
                }

                Section {
                    LabeledContent("Last run", value: pingText)
                } header: {
                    Text("4. Siri and Control Center")
                } footer: {
                    Text("Say \"Test LionClub\" to Siri, or add the \"Test LionClub\" button to Control Center and tap it. Then come back here.")
                }

                Section {
                    LabeledContent("Location access", value: location.statusText)
                    Button("Allow while using the app") { location.requestWhenInUse() }
                    Button("Allow always (for parking)") { location.requestAlways() }
                    LabeledContent("Last parking spot", value: spotText)
                } header: {
                    Text("5. Parking spot")
                } footer: {
                    Text("In the Shortcuts app: Automation, New Automation, CarPlay (or Bluetooth), Disconnects, Run Immediately, then add \"Save Parking Spot\" from LionClub.")
                }
            }
            .navigationTitle("Checks")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reload() }
            }
        }
    }

    private var pingText: String {
        guard let ping = lastPing else { return "Never" }
        return "\(ping.source), \(ping.at.formatted(date: .abbreviated, time: .shortened))"
    }

    private var spotText: String {
        guard let spot = lastSpot else { return "None yet" }
        let when = spot.savedAt.formatted(date: .abbreviated, time: .shortened)
        return spot.latitude == nil ? "\(when), no location" : "\(when), with location"
    }

    private func reload() {
        lastPing = Ping.load()
        lastSpot = ParkingSpot.load()
    }

    private func sendToWidget() {
        var snapshot = CarSnapshot.load() ?? .demo
        snapshot.updatedAt = Date()
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
        widgetResult = "Sent at \(snapshot.updatedAt.formatted(date: .omitted, time: .standard))."
    }

    private func testFaceID() async -> String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return "Not available: \(error?.localizedDescription ?? "unknown reason")"
        }
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Check that Face ID works in LionClub")
            return "Works."
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    private func testPeugeotLogin() async -> String {
        do {
            let config = try PeugeotConfig.load(country: "HR")
            let callback = try await webAuthenticationSession.authenticate(
                using: config.authorizeURL,
                callbackURLScheme: config.scheme
            )
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if items.contains(where: { $0.name == "code" }) {
                return "Works: Peugeot sent a sign-in code back to LionClub."
            }
            return "Came back without a code."
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return "Cancelled."
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }
}
