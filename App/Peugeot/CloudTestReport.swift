import Foundation

/// What Peugeot's cloud knows about one car, and how fresh it is. Decides Plan A (connected app)
/// or Plan B (offline companion).
struct CloudTestReport: Identifiable {
    enum Verdict: Equatable {
        case live
        case stale(days: Int)
        case noDates
        case noStatus
    }

    let id = UUID()
    let carName: String
    let vinEnd: String
    let lines: [String]
    let verdict: Verdict

    var isLive: Bool { verdict == .live }

    var verdictText: String {
        switch verdict {
        case .live:
            return "LIVE: Peugeot's cloud gets data from your car, so the connected app (Plan A) will work."
        case .stale(let days):
            return "STALE: the newest data is \(days) days old. If you drove since then, Peugeot's cloud isn't getting updates (Plan B). If the car was parked the whole time, drive 15+ minutes and test again."
        case .noDates:
            return "UNCLEAR: data came back without dates. Drive the car, test again and check the numbers changed."
        case .noStatus:
            return "NO CLOUD DATA: Peugeot's servers have no status for this car, so it'll be the offline companion (Plan B)."
        }
    }

    /// Builds the summary from Peugeot's answers. A pure function, so it can be tested with sample data.
    static func make(
        vehicle: [String: Any],
        status: [String: Any]?,
        maintenance: [String: Any]?,
        remoteLink: Bool,
        now: Date = Date()
    ) -> CloudTestReport {
        let carName = [vehicle["brand"] as? String, vehicle["motorization"] as? String]
            .compactMap { $0 }
            .joined(separator: " ")
        let vin = vehicle["vin"] as? String ?? ""
        let vinEnd = String(vin.suffix(4))

        guard let status else {
            return CloudTestReport(
                carName: carName,
                vinEnd: vinEnd,
                lines: ["No status from Peugeot's cloud."],
                verdict: .noStatus
            )
        }

        var lines: [String] = []

        let energies = status["energies"] as? [[String: Any]] ?? []
        if let fuel = energies.first(where: { $0["type"] as? String == "Fuel" }), let level = number(fuel["level"]) {
            if let range = number(fuel["autonomy"]) {
                lines.append("Fuel: \(Int(level)) %, range \(Int(range)) km")
            } else {
                lines.append("Fuel: \(Int(level)) %")
            }
        } else {
            lines.append("Fuel level: not sent")
        }

        if let mileage = number((status["odometer"] as? [String: Any])?["mileage"]) {
            lines.append("Odometer: \(Int(mileage)) km")
        } else {
            lines.append("Odometer: not sent")
        }

        let doors = status["doorsState"] as? [String: Any]
        let lockedStates = doors?["lockedStates"] as? [String] ?? []
        if lockedStates.isEmpty {
            lines.append("Lock state: not sent")
        } else {
            let locked = lockedStates.contains { $0.contains("Locked") && !$0.contains("Unlocked") }
            lines.append("Locked: \(locked ? "yes" : "no")")
            let open = (doors?["opening"] as? [[String: Any]] ?? [])
                .filter { $0["state"] as? String == "Open" }
                .compactMap { $0["identifier"] as? String }
            if !open.isEmpty {
                lines.append("Open: \(open.joined(separator: ", "))")
            }
        }

        let geometry = (status["lastPosition"] as? [String: Any])?["geometry"] as? [String: Any]
        lines.append("Position sent by the car: \(geometry?["coordinates"] != nil ? "yes" : "no")")

        if let maintenance {
            let km = number(maintenance["mileageBeforeMaintenance"]).map { "\(Int($0)) km" } ?? "? km"
            let days = number(maintenance["daysBeforeMaintenance"]).map { "\(Int($0)) days" } ?? "? days"
            lines.append("Next service: in \(km) / \(days)")
        }

        lines.append("Remote-services link (needed for lock/unlock): \(remoteLink ? "yes" : "no")")

        let verdict: Verdict
        if let newest = timestamps(in: status).max() {
            lines.append("Newest data from the car: \(newest.formatted(date: .abbreviated, time: .shortened))")
            let days = Int(now.timeIntervalSince(newest) / 86_400)
            verdict = now.timeIntervalSince(newest) <= 2 * 86_400 ? .live : .stale(days: days)
        } else {
            verdict = .noDates
        }

        return CloudTestReport(carName: carName, vinEnd: vinEnd, lines: lines, verdict: verdict)
    }

    /// Every `updatedAt` / `createdAt` date in the answer, wherever it sits.
    static func timestamps(in value: Any) -> [Date] {
        if let dictionary = value as? [String: Any] {
            return dictionary.flatMap { key, child -> [Date] in
                if key == "updatedAt" || key == "createdAt", let text = child as? String, let date = parseDate(text) {
                    return [date]
                }
                return timestamps(in: child)
            }
        }
        if let array = value as? [Any] {
            return array.flatMap { timestamps(in: $0) }
        }
        return []
    }

    static func parseDate(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}
