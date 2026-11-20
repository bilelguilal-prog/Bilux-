import Foundation

// Contrat de synchronisation commun aux deux applications.
// On transmet uniquement un résumé nécessaire à la montre : ni TSH, ni notes médicales,
// ni historique nutritionnel détaillé, ni fichiers de sauvegarde.
struct WatchQuest: Codable, Identifiable {
    var id: String
    var title: String
    var completed: Bool
    var reward: Int
}

// Résumé compact, calculé exclusivement depuis le moteur V6.3 sur l'iPhone.
// Aucun dossier médical, aucune séance individuelle et aucune donnée HealthKit ajoutés.
struct WatchMasteryPath: Codable, Identifiable {
    var id: String
    var title: String
    var symbol: String
    var current: Int
    var target: Int
    var unlocked: Int
    var total: Int
    var nextTitle: String?
    var remaining: Int?
    var unit: String
}

struct WatchSnapshot: Codable {
    var heroName: String
    var level: Int
    var rank: String
    var totalXP: Int
    var xpProgress: Double
    var steps: Double?
    var activeKcal: Double?
    var latestHeartRate: Double?
    var sleepHours: Double?
    var workoutMinutes: Double?
    var energyConsumed: Double?
    var quests: [WatchQuest]
    var updatedAt: Date
    // V6.0 : nouveaux champs facultatifs pour lire aussi les anciens snapshots Watch 2.0.
    // Aucun renseignement médical supplémentaire n'est synchronisé.
    var xpRemaining: Int? = nil
    var weeklyWorkouts: Int? = nil
    var monthlyWorkouts: Int? = nil
    var quarterWorkouts: Int? = nil
    var workoutCount: Int? = nil
    var lastWorkoutLabel: String? = nil
    var equippedTitle: String? = nil
    var equippedAura: String? = nil
    // Optionnel pour relire sans migration les snapshots des anciennes versions.
    var masteryPaths: [WatchMasteryPath]? = nil
    var forgeDays: [V76PlanDay]? = nil
    var v78History: [V76Target]? = nil
    var v78Model: [V76Target]? = nil
    var v78Debrief: V78Debrief? = nil
    var forgeDayCount: Int? = nil
    var treatmentRecords: [V76TreatmentRecord]? = nil
    // Horodatage indépendant : ne jamais avancer la date du résumé RPG.
    var v77TreatmentSummaryAt: Date? = nil

    static let empty = WatchSnapshot(
        heroName: "BILUX", level: 1, rank: "SURVIVANT", totalXP: 0,
        xpProgress: 0, steps: nil, activeKcal: nil, latestHeartRate: nil,
        sleepHours: nil, workoutMinutes: nil, energyConsumed: nil,
        quests: [], updatedAt: .distantPast
    )
}
// MARK: - V7.6 Watch 5.0 (compatible with older snapshots)
struct V76TreatmentRecord: Codable, Equatable, Identifiable {
    let day: String
    let confirmed: Bool
    let changedAt: Date
    let revision: UUID
    var id: String { day }
    static func today(_ date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    var valid: Bool {
        day.count == 10 && day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil && changedAt.timeIntervalSince1970.isFinite
    }
    func supersedes(_ old: Self) -> Bool {
        if changedAt != old.changedAt { return changedAt > old.changedAt }
        // Deterministic tie; cancellation wins on identical timestamps.
        if confirmed != old.confirmed { return !confirmed }
        return revision.uuidString > old.revision.uuidString
    }
    static func merge(_ incoming: [Self], into records: inout [Self]) {
        var byDay: [String: Self] = [:]
        for entry in records + incoming where entry.valid {
            if let old = byDay[entry.day], !entry.supersedes(old) { continue }
            byDay[entry.day] = entry
        }
        records = byDay.values.sorted { $0.day > $1.day }
    }
    static func load(_ key: String) -> [Self] {
        guard let data = UserDefaults.standard.data(forKey: key), let rows = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        var normalized: [Self] = []
        merge(rows, into: &normalized)
        return normalized
    }
    static func save(_ rows: [Self], _ key: String) {
        if let data = try? JSONEncoder().encode(rows) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct V76Target: Codable, Identifiable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: Int
    let weight: Double
}
struct V76PlanDay: Codable, Identifiable {
    let planID: UUID
    let id: UUID
    let planName: String
    let title: String
    let exercises: [V76Target]
}
struct V76ActualSet: Codable, Identifiable {
    let id: UUID
    let reps: Int
    let weight: Double
}
struct V76ActualExercise: Codable, Identifiable {
    let id: UUID
    let name: String
    var sets: [V76ActualSet]
}
struct V76ForgePayload: Codable {
    let planID: UUID
    let dayID: UUID
    let exercises: [V76ActualExercise]
    var valid: Bool {
        !exercises.isEmpty && exercises.count <= 12 && Set(exercises.map(\.id)).count == exercises.count &&
        exercises.allSatisfy { exercise in
            !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && exercise.name.count <= 80 &&
            !exercise.sets.isEmpty && exercise.sets.count <= 12 && Set(exercise.sets.map(\.id)).count == exercise.sets.count &&
            exercise.sets.allSatisfy { (1...100).contains($0.reps) && $0.weight.isFinite && (0...1000).contains($0.weight) }
        }
    }
}

struct V78Debrief: Codable {
    let id: UUID
    let xp: Int
    let records: [String]
}

enum V78Reactor {
    static let freeID = UUID(uuidString: "81F0896A-14F6-4B76-B937-9AC125780078")!
    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
    static func day(_ targets: [V76Target] = []) -> V76PlanDay {
        V76PlanDay(planID: freeID, id: UUID(), planName: "Libre",
                   title: "Séance libre", exercises: targets)
    }
}
