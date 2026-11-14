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
        data.workouts[index] = session
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
    var totalXP: Int {
        let workoutXP = data.workouts.count * 25
        let mealDays = Set(data.meals.map { Calendar.current.startOfDay(for: $0.date) }).count * 8
        let checkinDays = Set(data.checkins.map { Calendar.current.startOfDay(for: $0.date) }).count * 8
        return workoutXP + mealDays + checkinDays
    }
    var heroLevel: Int { max(1, totalXP / 100 + 1) }
    var rankName: String {
        switch heroLevel {
        case 15...: return "Ascension"
        case 10...: return "Nucléaire"
        case 6...: return "Réacteur"
        case 3...: return "Éveil"
        default: return "Survivant"
        }
    }
    var xpFraction: Double { Double(totalXP % 100) / 100.0 }
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
            let currentWorkouts = Set(data.workouts.map(\.id))
            let currentMeals = Set(data.meals.map(\.id))
            let currentCheckins = Set(data.checkins.map(\.id))
            let currentLabs = Set(data.labs.map(\.id))
            data.workouts.append(contentsOf: result.workouts.filter { !currentWorkouts.contains($0.id) })
            data.meals.append(contentsOf: result.meals.filter { !currentMeals.contains($0.id) })
            data.checkins.append(contentsOf: result.checkins.filter { !currentCheckins.contains($0.id) })
            data.labs.append(contentsOf: result.labs.filter { !currentLabs.contains($0.id) })
            if data.caloriesGoal == nil { data.caloriesGoal = result.caloriesGoal }
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
