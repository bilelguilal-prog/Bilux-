import Foundation

// Données locales du journal Bilux. Les informations de Santé restent dans HealthKit.
struct WorkoutSet: Codable, Identifiable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
}
struct WorkoutExercise: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: [WorkoutSet]
}
struct WorkoutSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = .now
    var activity: String
    var durationMinutes: Int
    var notes: String
    var rpe: Int? = nil
    var exercises: [WorkoutExercise]
    var volume: Double { exercises.reduce(0) { total, exercise in
        total + exercise.sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }}
}
struct ManualMeal: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = .now
    var name: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fats: Double
    var waterML: Double? = nil
}
struct Checkin: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = .now
    var energy: Int
    var fatigue: Int
    var sleepHours: Double?
    var note: String
    var weightKG: Double? = nil
    var medicationNote: String? = nil
}
struct ThyroidLab: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = .now
    var tsh: Double?
    var t4l: Double?
    var note: String
}
struct BiluxData: Codable {
    var version: Int = 4
    var workouts: [WorkoutSession] = []
    var meals: [ManualMeal] = []
    var checkins: [Checkin] = []
    var labs: [ThyroidLab] = []
    var caloriesGoal: Int? = nil
    var heroName: String = "BILUX"
}

enum BiluxFormat {
    static func number(_ x: Double, digits: Int = 0) -> String {
        x.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "fr_FR")))
    }
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "fr_FR")))
    }
    static func sameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
}
