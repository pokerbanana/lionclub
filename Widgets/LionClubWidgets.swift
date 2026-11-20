import AppIntents
import SwiftUI
import WidgetKit

@main
struct LionClubWidgets: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        TestControl()
    }
}

// MARK: - Home Screen and Lock Screen widget

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: CarSnapshot?
    let shared: Bool
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), snapshot: .demo, shared: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func current() -> StatusEntry {
        StatusEntry(date: Date(), snapshot: CarSnapshot.load(), shared: AppGroup.isShared)
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "io.github.pokerbanana.lionclub.status", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Car status")
        .description("Fuel, range and when it was updated.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        if !entry.shared {
            Text("Can't read LionClub's data")
                .font(.caption)
        } else if let car = entry.snapshot {
            switch family {
            case .accessoryCircular:
                Gauge(value: (car.fuelPercent ?? 0) / 100) {
                    Image(systemName: "fuelpump.fill")
                } currentValueLabel: {
                    Text("\(Int(car.fuelPercent ?? 0))")
                }
                .gaugeStyle(.accessoryCircular)
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text("\(Int(car.fuelPercent ?? 0)) % fuel")
                        .font(.headline)
                    Text(car.rangeKm.map { "\(Int($0)) km range" } ?? "Range unknown")
                    Text(car.updatedAt, style: .relative)
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "fuelpump.fill")
                        Spacer()
                        Button(intent: RecordPingIntent(source: "Widget")) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(Int(car.fuelPercent ?? 0)) %")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(car.rangeKm.map { "\(Int($0)) km" } ?? "-")
                        .font(.subheadline)
                    Spacer(minLength: 0)
                    Text(car.updatedAt.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Open LionClub once")
                .font(.caption)
        }
    }
}

// MARK: - Control Center button

struct TestControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "io.github.pokerbanana.lionclub.test") {
            ControlWidgetButton(action: RecordPingIntent(source: "Control Center")) {
                Label("Test LionClub", systemImage: "car.fill")
            }
        }
        .displayName("Test LionClub")
    }
}
