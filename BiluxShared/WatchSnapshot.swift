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

    static let empty = WatchSnapshot(
        heroName: "BILUX", level: 1, rank: "SURVIVANT", totalXP: 0,
        xpProgress: 0, steps: nil, activeKcal: nil, latestHeartRate: nil,
        sleepHours: nil, workoutMinutes: nil, energyConsumed: nil,
        quests: [], updatedAt: .distantPast
    )
}
