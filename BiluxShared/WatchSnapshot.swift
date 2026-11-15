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

    static let empty = WatchSnapshot(
        heroName: "BILUX", level: 1, rank: "SURVIVANT", totalXP: 0,
        xpProgress: 0, steps: nil, activeKcal: nil, latestHeartRate: nil,
        sleepHours: nil, workoutMinutes: nil, energyConsumed: nil,
        quests: [], updatedAt: .distantPast
    )
}
