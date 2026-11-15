import Foundation
import Combine

@MainActor
final class BiluxStore: ObservableObject {
    @Published var data: BiluxData = BiluxData()
    @Published var feedback: String?

    private let url: URL
    init() {
        let fm = FileManager.default
        let directory = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        url = directory.appendingPathComponent("bilux-v4.json")
        if let file = try? Data(contentsOf: url), let recovered = try? JSONDecoder().decode(BiluxData.self, from: file) {
            data = recovered
        }
        // V5.5: la premiere migration fige les XP deja gagnes et les formes acquises.
        if data.longAscensionAnchor == nil {
            data.longAscensionAnchor = BILUXV55Progression.makeAnchor(data)
            save()
        }
    }
    func save() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: [.atomic, .completeFileProtection])
        } catch { feedback = "Impossible d'enregistrer le journal : \(error.localizedDescription)" }
    }
    func add(_ session: WorkoutSession) {
        data.workouts.insert(session, at: 0)
        for exercise in session.exercises { registerExerciseName(exercise.name, saveImmediately: false) }
        save()
    }
    func add(_ meal: ManualMeal) { data.meals.insert(meal, at: 0); save() }
    func add(_ checkin: Checkin) { data.checkins.insert(checkin, at: 0); save() }
    func add(_ lab: ThyroidLab) { data.labs.insert(lab, at: 0); save() }
    func removeWorkout(_ id: UUID) { data.workouts.removeAll { $0.id == id }; save() }
    // Actualise la séance en conservant son identifiant et donc ses XP existants.
    func updateWorkout(_ session: WorkoutSession) {
        guard let index = data.workouts.firstIndex(where: { $0.id == session.id }) else {
            feedback = "Cette séance n'existe plus dans le journal."
            return
        }
        var updated = session
        if updated.liveReport == nil {
            updated.liveReport = data.workouts[index].liveReport
        }
        data.workouts[index] = updated
        for exercise in session.exercises { registerExerciseName(exercise.name, saveImmediately: false) }
        save()
    }

    // Catalogue cumulatif : les noms déjà utilisés restent disponibles, même si
    // l'utilisateur modifie ensuite une séance ou supprime une ancienne entrée.
    var exerciseNames: [String] {
        var names: [String] = []
        let existing = (data.exerciseLibrary ?? []) + data.workouts.flatMap { $0.exercises.map(\.name) }
        for value in existing {
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if !names.contains(where: { Self.sameExerciseName($0, name) }) { names.append(name) }
        }
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func sameExerciseName(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR")) == .orderedSame
    }

    func registerExerciseName(_ raw: String, saveImmediately: Bool = true) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !exerciseNames.contains(where: { Self.sameExerciseName($0, name) }) else { return }
        if data.exerciseLibrary == nil { data.exerciseLibrary = [] }
        data.exerciseLibrary?.append(name)
        if saveImmediately { save() }
    }
    // V5.9 : choix cosmétiques sauvegardés avec le journal, sans XP offert.
    func equipLegacyTitle(_ id: String) {
        var loadout = data.legacyLoadout ?? BILUXV59Loadout()
        loadout.titleID = id
        data.legacyLoadout = loadout
        save()
    }
    func equipLegacyAura(_ id: String) {
        var loadout = data.legacyLoadout ?? BILUXV59Loadout()
        loadout.auraID = id
        data.legacyLoadout = loadout
        save()
    }
    func equipLegacyCrest(_ id: String) {
        var loadout = data.legacyLoadout ?? BILUXV59Loadout()
        loadout.crestID = id
        data.legacyLoadout = loadout
        save()
    }

    var totalXP: Int { BILUXV55Progression.totalXP(data) }
    var heroLevel: Int { BILUXV55Progression.heroLevel(data) }
    var unlockedStageIndex: Int { BILUXV55Progression.stageIndex(data) }
    var rankName: String { BILUXV55Progression.stageNames[unlockedStageIndex].capitalized }
    var xpFraction: Double { BILUXV55Progression.fraction(data) }
    var xpToNextLevel: Int { BILUXV55Progression.remainingXP(data) }
    var questsToday: (workout: Bool, meal: Bool, checkin: Bool) {
        let value = BILUXV55Progression.currentQuestProgress(data)
        return (value.todayWorkout, value.todayMeal, value.todayCheckin)
    }
    var todaysMeals: [ManualMeal] { data.meals.filter { BiluxFormat.sameDay($0.date, .now) } }
    var todaysCalories: Double { todaysMeals.reduce(0) { $0 + $1.kcal } }

    // La V3 web utilise localStorage. L'import du JSON est donc volontaire, jamais automatique.
    func importJSON(_ fileURL: URL) {
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: fileURL)
            guard let object = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
                throw ImportIssue.invalidFile
            }
            let result = try V3Import.parse(object)
            let emptyBeforeImport = data.workouts.isEmpty && data.meals.isEmpty && data.checkins.isEmpty && data.labs.isEmpty
            let currentWorkouts = Set(data.workouts.map(\.id))
            let currentMeals = Set(data.meals.map(\.id))
            let currentCheckins = Set(data.checkins.map(\.id))
            let currentLabs = Set(data.labs.map(\.id))
            data.workouts.append(contentsOf: result.workouts.filter { !currentWorkouts.contains($0.id) })
            data.meals.append(contentsOf: result.meals.filter { !currentMeals.contains($0.id) })
            data.checkins.append(contentsOf: result.checkins.filter { !currentCheckins.contains($0.id) })
            data.labs.append(contentsOf: result.labs.filter { !currentLabs.contains($0.id) })
            if data.caloriesGoal == nil { data.caloriesGoal = result.caloriesGoal }
            // Restauration complète du point de départ XP depuis une sauvegarde BILUX.
            // Ne pas réécrire la progression d'un journal déjà actif.
            if emptyBeforeImport {
                data.longAscensionAnchor = result.longAscensionAnchor
                    ?? BILUXV55Progression.makeAnchor(data)
                // Restaurer aussi les titres, auras et emblèmes depuis un export V5.9.
                data.legacyLoadout = result.legacyLoadout
            }
            save()
            feedback = "Import terminé : \(result.workouts.count) séances, \(result.meals.count) repas, \(result.checkins.count) bilans et \(result.labs.count) résultats trouvés."
        } catch { feedback = "Import impossible : \(error.localizedDescription)" }
    }
    func exportJSON() -> URL? {
        do {
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("bilux-v4-sauvegarde.json")
            let payload = try JSONEncoder().encode(data)
            try payload.write(to: file, options: [.atomic, .completeFileProtection])
            return file
        } catch { feedback = "Export impossible : \(error.localizedDescription)"; return nil }
    }
}

enum ImportIssue: LocalizedError {
    case invalidFile
    var errorDescription: String? { "Ce fichier n'est pas une sauvegarde JSON Bilux reconnue." }
}
