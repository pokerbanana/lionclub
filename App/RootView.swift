import SwiftUI

struct RootView: View {
    enum Screen: String {
        case home, checks
    }

    // CI screenshots launch the app with `-demoTab checks` to open a given tab.
    @State private var screen = Screen(rawValue: UserDefaults.standard.string(forKey: "demoTab") ?? "") ?? .home

    var body: some View {
        TabView(selection: $screen) {
            HomeView()
                .tabItem { Label("Car", systemImage: "car.fill") }
                .tag(Screen.home)
            ChecksView()
                .tabItem { Label("Checks", systemImage: "checklist") }
                .tag(Screen.checks)
        }
    }
}
