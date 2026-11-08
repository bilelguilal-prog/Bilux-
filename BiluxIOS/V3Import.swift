import Foundation

// Convertit les exports de la PWA Bilux V3 (sessions/meals/checkins/labs).
// Les identifiants web sont des chaînes arbitraires ; on les stabilise en UUID localement.
enum V3Import {
    static func date(_ value: Any?) -> Date {
        let text = value as? String ?? ""
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd"
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone.current
        return format.date(from: text) ?? .now
    }
    static func number(_ x: Any?) -> Double {
        if let n = x as? NSNumber { return n.doubleValue }
        if let s = x as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return 0
    }
    static func optionalNumber(_ x: Any?) -> Double? {
        if x == nil || x is NSNull || (x as? String) == "" { return nil }
        return number(x)
    }
    static func array(_ x: Any?) -> [[String: Any]] { x as? [[String: Any]] ?? [] }
    static func text(_ x: Any?, fallback: String = "") -> String { x as? String ?? fallback }
    static func uuid(_ source: Any?) -> UUID {
        // Stable hash so reimporting the same V3 backup won't duplicate its records.
        let text = String(describing: source ?? UUID().uuidString)
        let bytes = Array(text.utf8)
        var first: UInt64 = 0xcbf29ce484222325
        var second: UInt64 = 0x84222325cbf29ce4
        for b in bytes { first = (first ^ UInt64(b)) &* 0x100000001b3; second = (second ^ UInt64(b)) &* 0x100000001b3 }
        let hex = String(format: "%016llx%016llx", first, second)
        let uuidText = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.suffix(12))"
        return UUID(uuidString: uuidText) ?? UUID()
    }
    static func parse(_ object: [String: Any]) throws -> BiluxData {
        if let version = object["version"] as? Int, version == 4,
           let bytes = try? JSONSerialization.data(withJSONObject: object),
           let restored = try? JSONDecoder().decode(BiluxData.self, from: bytes) { return restored }
        guard object["sessions"] is [[String: Any]] || object["meals"] is [[String: Any]] || object["checkins"] is [[String: Any]] || object["labs"] is [[String: Any]] else {
            throw ImportIssue.invalidFile
        }
        var result = BiluxData()
        for record in array(object["sessions"]) {
            let exercises: [WorkoutExercise] = array(record["exercises"]).compactMap { item in
                let name = text(item["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty { return nil }
                var sets: [WorkoutSet] = array(item["series"]).filter { ($0["done"] as? Bool) != false }.map {
                    WorkoutSet(reps: max(0, Int(number($0["reps"]))), weight: max(0, number($0["weight"])))
                }.filter { $0.reps > 0 }
                if sets.isEmpty {
                    let count = max(0, min(100, Int(number(item["sets"]))))
                    sets = (0..<count).map { _ in WorkoutSet(reps: max(0, Int(number(item["reps"]))), weight: max(0, number(item["weight"]))) }.filter { $0.reps > 0 }
                }
                return WorkoutExercise(name: name, sets: sets)
            }
            result.workouts.append(WorkoutSession(id: uuid(record["id"]), date: date(record["date"]), activity: text(record["activity"], fallback: "Musculation"), durationMinutes: max(0, Int(number(record["duration"]))), notes: text(record["notes"]), rpe: optionalNumber(record["rpe"]).map(Int.init), exercises: exercises))
        }
        for record in array(object["meals"]) {
            result.meals.append(ManualMeal(id: uuid(record["id"]), date: date(record["date"]), name: text(record["name"], fallback: text(record["type"], fallback: "Repas")), kcal: number(record["calories"]), protein: number(record["protein"]), carbs: number(record["carbs"]), fats: number(record["fat"]), waterML: optionalNumber(record["water"])))
        }
        for record in array(object["checkins"]) {
            result.checkins.append(Checkin(id: uuid(record["id"]), date: date(record["date"]), energy: Int(number(record["energy"])), fatigue: Int(number(record["fatigue"])), sleepHours: optionalNumber(record["sleep"]), note: text(record["symptoms"]), weightKG: optionalNumber(record["weight"]), medicationNote: text(record["medication"])))
        }
        for record in array(object["labs"]) {
            result.labs.append(ThyroidLab(id: uuid(record["id"]), date: date(record["date"]), tsh: optionalNumber(record["tsh"]), t4l: optionalNumber(record["ft4"]), note: text(record["notes"])))
        }
        if let profile = object["profile"] as? [String: Any] {
            if let calories = optionalNumber(profile["calorieGoal"]), calories > 0 { result.caloriesGoal = Int(calories) }
            let name = text(profile["alias"]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { result.heroName = name }
        }
        return result
    }
}
