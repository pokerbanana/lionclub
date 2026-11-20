import SwiftUI
import WidgetKit

/// The car screen. Until the Peugeot cloud test decides how the app gets real data, it shows a sample car.
struct HomeView: View {
    @State private var car = CarSnapshot.load() ?? .demo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if car.isDemo {
                        Label("Sample car. Your real data comes after the Peugeot cloud test.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    FuelGauge(percent: car.fuelPercent ?? 0)
                        .frame(width: 200, height: 200)
                        .padding(.vertical, 8)
                    HStack(spacing: 12) {
                        StatTile(title: "Range", value: car.rangeKm.map { "\(Int($0)) km" } ?? "-")
                        StatTile(title: "Odometer", value: car.odometerKm.map { "\(Int($0).formatted()) km" } ?? "-")
                    }
                    StatTile(title: "Doors", value: lockText, systemImage: car.locked == false ? "lock.open.fill" : "lock.fill")
                    Text("Updated \(car.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Peugeot 2008")
        }
        .onAppear {
            // Gives the widget something to show until real data exists.
            if CarSnapshot.load() == nil {
                CarSnapshot.demo.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
            car = CarSnapshot.load() ?? .demo
        }
    }

    private var lockText: String {
        switch car.locked {
        case .some(true): return "Locked"
        case .some(false): return "Unlocked"
        case .none: return "Unknown"
        }
    }
}

struct FuelGauge: View {
    let percent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: max(0, min(1, percent / 100)))
                .stroke(percent < 15 ? Color.red : Color.accentColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: "fuelpump.fill")
                    .font(.title2)
                Text("\(Int(percent)) %")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("fuel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(value)
                    .font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
