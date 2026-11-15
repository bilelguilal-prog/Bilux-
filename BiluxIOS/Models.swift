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
    // Optionnel : les JSON historiques restent décodables, sans migration d'XP.
    var liveReport: NuclearLiveReport? = nil
    var volume: Double { exercises.reduce(0) { total, exercise in
        total + exercise.sets.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }}
}
// BILUX V6.2 : observations de Nuclear Live, pas une mesure médicale ni une récompense RPG.
struct NuclearLiveReport: Codable, Equatable {
    var averageBPM: Int?
    var peakBPM: Int?
    var activeKcal: Double?
    var zoneSeconds: [Int]
    var referenceMaxBPM: Int
    var sampleCount: Int
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
    // Optional pour que les sauvegardes V4, dépourvues de ce champ, restent lisibles.
    var exerciseLibrary: [String]? = nil
    var longAscensionAnchor: LongAscensionAnchor? = nil
    // V5.9 : personnalisation purement cosmétique, conservée dans les exports JSON.
    var legacyLoadout: BILUXV59Loadout? = nil
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

// MARK: - BILUX V5.5 · THE LONG ASCENSION
// Les anciennes sauvegardes restent compatibles : champ optionnel, migration une seule fois.
struct LongAscensionAnchor: Codable {
    var startedAt: Date
    var baselineXP: Int
    var legacyLevel: Int
    var legacyStage: Int
}

// Moteur deterministe : les recompenses dependent des dates et des sessions enregistrees.
// Aucune quete n'est "reclamable" deux fois. Aucun bonus lie aux resultats medicaux.
enum BILUXV55Progression {
    static let maximumLevel = 100
    static let dailyWorkoutXP = 45
    static let dailyNutritionXP = 6
    static let dailyJournalXP = 6
    static let weeklyForgeXP = 70
    static let weeklyNutritionXP = 20
    static let weeklyJournalXP = 25
    static let monthlyBossXP = 140
    static let legendaryBossXP = 180
    static let stageLevels = [1, 11, 31, 56, 81]
    static let stageNames = ["SURVIVANT", "ÉVEIL", "RÉACTEUR", "NUCLÉAIRE", "ASCENSION"]

    static func legacyXP(_ data: BiluxData) -> Int {
        let calendar = Calendar.current
        return data.workouts.count * 25
            + Set(data.meals.map { calendar.startOfDay(for: $0.date) }).count * 8
            + Set(data.checkins.map { calendar.startOfDay(for: $0.date) }).count * 8
    }

    static func makeAnchor(_ data: BiluxData, now: Date = .now) -> LongAscensionAnchor {
        let xp = legacyXP(data)
        let oldLevel = max(1, xp / 100 + 1)
        let stage: Int
        switch oldLevel {
        case 15...: stage = 4
        case 10...: stage = 3
        case 6...: stage = 2
        case 3...: stage = 1
        default: stage = 0
        }
        return LongAscensionAnchor(startedAt: now, baselineXP: xp,
                                   legacyLevel: min(oldLevel, maximumLevel), legacyStage: stage)
    }

    // Progression lente et croissante : 100 XP environ par niveau au debut,
    // 169 XP environ vers la fin. Niveau 100 a 13 330 XP cumulés.
    static func threshold(for level: Int) -> Int {
        let n = max(0, min(level, maximumLevel) - 1)
        return 100 * n + (35 * n * n) / 100
    }

    static func level(for xp: Int, floor: Int = 1) -> Int {
        var low = 1
        var high = maximumLevel
        while low < high {
            let middle = (low + high + 1) / 2
            if threshold(for: middle) <= xp { low = middle }
            else { high = middle - 1 }
        }
        return max(low, min(max(1, floor), maximumLevel))
    }

    static func unlockedStage(level: Int, legacyFloor: Int = 0) -> Int {
        let current = stageLevels.lastIndex(where: { level >= $0 }) ?? 0
        return min(4, max(current, legacyFloor))
    }

    static func totalXP(_ data: BiluxData, now: Date = .now) -> Int {
        guard let anchor = data.longAscensionAnchor else { return legacyXP(data) }
        return anchor.baselineXP + earnedXP(data, since: anchor.startedAt, now: now)
    }

    static func heroLevel(_ data: BiluxData) -> Int {
        let floor = data.longAscensionAnchor?.legacyLevel ?? 1
        return level(for: totalXP(data), floor: floor)
    }

    static func stageIndex(_ data: BiluxData) -> Int {
        unlockedStage(level: heroLevel(data), legacyFloor: data.longAscensionAnchor?.legacyStage ?? 0)
    }

    static func fraction(_ data: BiluxData) -> Double {
        let level = heroLevel(data)
        if level >= maximumLevel { return 1 }
        let start = threshold(for: level)
        let end = threshold(for: level + 1)
        return Double(max(0, min(end - start, totalXP(data) - start))) / Double(max(1, end - start))
    }

    static func remainingXP(_ data: BiluxData) -> Int {
        let level = heroLevel(data)
        return level >= maximumLevel ? 0 : max(0, threshold(for: level + 1) - totalXP(data))
    }

    private static func startOfWeek(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func startOfMonth(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
    private static func startOfQuarter(_ date: Date, _ calendar: Calendar) -> Date {
        // Trimestres civils : janvier, avril, juillet, octobre.
        let month = calendar.component(.month, from: date)
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        let year = calendar.component(.year, from: date)
        return calendar.date(from: DateComponents(year: year, month: quarterMonth, day: 1)) ?? calendar.startOfDay(for: date)
    }

    private static func limitedByWeek(_ days: Set<Date>, maxDays: Int, calendar: Calendar) -> [Date] {
        let grouped = Dictionary(grouping: days, by: { startOfWeek($0, calendar) })
        return grouped.values.flatMap { $0.sorted().prefix(maxDays) }
    }

    // Une seance d'au moins 10 minutes compte. Une seule par jour,
    // au maximum 5 jours par semaine (pas d'incitation aux doubles séances).
    static func qualifyingWorkoutDays(_ data: BiluxData, since: Date, now: Date = .now) -> Set<Date> {
        let calendar = Calendar.current
        return Set(data.workouts.filter {
            $0.date >= since && $0.date <= now && $0.durationMinutes >= 10
        }.map { calendar.startOfDay(for: $0.date) })
    }

    private static func journalDays(_ data: BiluxData, since: Date, now: Date, meals: Bool) -> Set<Date> {
        let calendar = Calendar.current
        let dates = meals ? data.meals.map(\.date) : data.checkins.map(\.date)
        return Set(dates.filter { $0 >= since && $0 <= now }
            .map { calendar.startOfDay(for: $0) })
    }

    static func earnedXP(_ data: BiluxData, since: Date, now: Date = .now) -> Int {
        let cal = Calendar.current
        let workouts = limitedByWeek(qualifyingWorkoutDays(data, since: since, now: now), maxDays: 5, calendar: cal)
        let nutrition = limitedByWeek(journalDays(data, since: since, now: now, meals: true), maxDays: 5, calendar: cal)
        let journal = limitedByWeek(journalDays(data, since: since, now: now, meals: false), maxDays: 5, calendar: cal)
        let workoutWeeks = Dictionary(grouping: workouts, by: { startOfWeek($0, cal) })
        let nutritionWeeks = Dictionary(grouping: nutrition, by: { startOfWeek($0, cal) })
        let journalWeeks = Dictionary(grouping: journal, by: { startOfWeek($0, cal) })
        let workoutMonths = Dictionary(grouping: workouts, by: { startOfMonth($0, cal) })
        let workoutQuarters = Dictionary(grouping: workouts, by: { startOfQuarter($0, cal) })

        let weeklyForge = workoutWeeks.values.filter { $0.count >= 3 }.count * weeklyForgeXP
        let weeklyNutrition = nutritionWeeks.values.filter { $0.count >= 4 }.count * weeklyNutritionXP
        let weeklyJournal = journalWeeks.values.filter { $0.count >= 3 }.count * weeklyJournalXP
        let monthlyBoss = workoutMonths.values.filter { $0.count >= 12 }.count * monthlyBossXP
        let legendaryBoss = workoutQuarters.values.filter { $0.count >= 30 }.count * legendaryBossXP
        return workouts.count * dailyWorkoutXP
            + nutrition.count * dailyNutritionXP
            + journal.count * dailyJournalXP
            + weeklyForge + weeklyNutrition + weeklyJournal + monthlyBoss + legendaryBoss
    }

    static func countThisWeek(_ dates: Set<Date>, now: Date = .now) -> Int {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return dates.filter { interval.contains($0) }.count
    }

    static func countThisMonth(_ dates: Set<Date>, now: Date = .now) -> Int {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: now) else { return 0 }
        return dates.filter { interval.contains($0) }.count
    }

    static func countThisQuarter(_ dates: Set<Date>, now: Date = .now) -> Int {
        let cal = Calendar.current
        let start = startOfQuarter(now, cal)
        guard let end = cal.date(byAdding: .month, value: 3, to: start) else { return 0 }
        return dates.filter { $0 >= start && $0 < end }.count
    }

    static func currentQuestProgress(_ data: BiluxData, now: Date = .now) -> (todayWorkout: Bool, todayMeal: Bool, todayCheckin: Bool, weeklyWorkouts: Int, weeklyMeals: Int, weeklyCheckins: Int, monthlyWorkouts: Int, quarterWorkouts: Int) {
        let since = data.longAscensionAnchor?.startedAt ?? now
        let cal = Calendar.current
        // V5.6 : le tableau de quêtes suit les MÊMES journées plafonnées
        // que earnedXP. Une 6e journée ne peut pas afficher une victoire
        // si elle n'a pas généré les XP de boss.
        let workouts = Set(limitedByWeek(qualifyingWorkoutDays(data, since: since, now: now), maxDays: 5, calendar: cal))
        let meals = Set(limitedByWeek(journalDays(data, since: since, now: now, meals: true), maxDays: 5, calendar: cal))
        let checkins = Set(limitedByWeek(journalDays(data, since: since, now: now, meals: false), maxDays: 5, calendar: cal))
        let today = cal.startOfDay(for: now)
        return (workouts.contains(today), meals.contains(today), checkins.contains(today),
                countThisWeek(workouts, now: now), countThisWeek(meals, now: now),
                countThisWeek(checkins, now: now), countThisMonth(workouts, now: now),
                countThisQuarter(workouts, now: now))
    }
}

// MARK: - BILUX V5.9 · Nuclear Legacy
// Optionnel dans BiluxData : les sauvegardes des versions précédentes décodent
// toujours sans erreur. Aucun impact sur les XP ou les données Apple Santé.
struct BILUXV59Loadout: Codable {
    var titleID: String = "initiate"
    var auraID: String = "core"
    var crestID: String = "core"
}

// MARK: - BILUX V6.3 · NUCLEAR MASTERY
// Cosmetic-only milestones computed from existing workouts. This never writes XP or extra sessions.
// Values describe JOURNAL ACTIVITY, never an objective assessment of physical capability.
struct V63MasteryNode: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let current: Int
    let goal: Int

    var achieved: Bool { current >= goal }
    var progress: Double { min(1.0, Double(max(0, current)) / Double(max(1, goal))) }
    var remaining: Int { max(0, goal - current) }
}

struct V63MasteryBranch: Identifiable {
    let id: String
    let title: String
    let icon: String
    let subtitle: String
    let current: Int
    let ultimateTarget: Int
    let unit: String
    let nodes: [V63MasteryNode]

    var levelPercent: Int {
        min(100, Int((Double(max(0, current)) / Double(max(1, ultimateTarget)) * 100.0).rounded()))
    }
    var unlockedCount: Int { nodes.filter(\.achieved).count }
    var next: V63MasteryNode? { nodes.first(where: { !$0.achieved }) }
}

struct V63MasterySnapshot {
    let sessionCount: Int
    let strengthSessions: Int
    let totalMinutes: Int
    let trainedWeeks: Int
    let uniqueExerciseCount: Int

    // No daily streaks: rest is never punished. Weeks are cumulative and never reset.
    static func evaluate(_ data: BiluxData, now: Date = .now, calendar: Calendar = .current) -> V63MasterySnapshot {
        let valid = data.workouts.filter { $0.date <= now && $0.durationMinutes >= 1 }
        let strength = valid.filter { workout in
            let name = workout.activity.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            return name.contains("musculation") || name.contains("strength") || name.contains("force") || name.contains("poids")
        }.count
        // Clamp each session to avoid corrupted/imported durations generating implausible stats.
        let minutes = valid.reduce(0) { $0 + min(1440, max(0, $1.durationMinutes)) }
        let eligibleWeeks: Set<Date> = Set(valid.filter { $0.durationMinutes >= 10 }.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start
        })
        let names: Set<String> = Set(valid.flatMap(\.exercises).map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        }.filter { !$0.isEmpty })
        return .init(sessionCount: valid.count, strengthSessions: strength, totalMinutes: minutes,
                     trainedWeeks: eligibleWeeks.count, uniqueExerciseCount: names.count)
    }

    var branches: [V63MasteryBranch] {
        [
            .init(id: "force", title: "FORCE", icon: "bolt.shield.fill",
                  subtitle: "Séances de musculation consignées", current: strengthSessions, ultimateTarget: 60,
                  unit: "séances de force", nodes: [
                    .init(id: "force1", title: "ÉTINCELLE DU TITAN", detail: "Consigner 4 séances de musculation.", icon: "bolt.fill", current: strengthSessions, goal: 4),
                    .init(id: "force2", title: "ARMURE DU RÉACTEUR", detail: "Consigner 20 séances de musculation.", icon: "shield.fill", current: strengthSessions, goal: 20),
                    .init(id: "force3", title: "FORGE LÉGENDAIRE", detail: "Consigner 60 séances de musculation.", icon: "crown.fill", current: strengthSessions, goal: 60)
                  ]),
            .init(id: "endurance", title: "ENDURANCE", icon: "flame.fill",
                  subtitle: "Minutes d'entraînement consignées", current: totalMinutes, ultimateTarget: 6000,
                  unit: "minutes enregistrées", nodes: [
                    .init(id: "endurance1", title: "SOUFFLE DU SURVIVANT", detail: "Cumuler 360 minutes d'entraînement.", icon: "wind", current: totalMinutes, goal: 360),
                    .init(id: "endurance2", title: "RÉACTEUR CONSTANT", detail: "Cumuler 1 800 minutes d'entraînement.", icon: "flame.fill", current: totalMinutes, goal: 1800),
                    .init(id: "endurance3", title: "FLAMME ÉTERNELLE", detail: "Cumuler 6 000 minutes d'entraînement.", icon: "sun.max.fill", current: totalMinutes, goal: 6000)
                  ]),
            .init(id: "regularity", title: "RÉGULARITÉ", icon: "calendar.badge.checkmark",
                  subtitle: "Semaines distinctes avec une séance d'au moins 10 min", current: trainedWeeks,
                  ultimateTarget: 24, unit: "semaines actives", nodes: [
                    .init(id: "regularity1", title: "PREMIER SERMENT", detail: "Enregistrer une activité sur 2 semaines différentes.", icon: "checkmark.seal.fill", current: trainedWeeks, goal: 2),
                    .init(id: "regularity2", title: "DISCIPLINE DU NOYAU", detail: "Enregistrer une activité sur 8 semaines différentes.", icon: "shield.lefthalf.filled", current: trainedWeeks, goal: 8),
                    .init(id: "regularity3", title: "VOIE DU VÉTÉRAN", detail: "Enregistrer une activité sur 24 semaines différentes.", icon: "star.fill", current: trainedWeeks, goal: 24)
                  ]),
            .init(id: "mastery", title: "MAÎTRISE", icon: "sparkles",
                  subtitle: "Exercices distincts consignés", current: uniqueExerciseCount, ultimateTarget: 30,
                  unit: "exercices différents", nodes: [
                    .init(id: "mastery1", title: "APPRENTI DU CODEX", detail: "Consigner 4 exercices différents.", icon: "book.fill", current: uniqueExerciseCount, goal: 4),
                    .init(id: "mastery2", title: "ARCHITECTE NUCLÉAIRE", detail: "Consigner 12 exercices différents.", icon: "atom", current: uniqueExerciseCount, goal: 12),
                    .init(id: "mastery3", title: "MAÎTRE DE L'HÉRITAGE", detail: "Consigner 30 exercices différents.", icon: "crown.fill", current: uniqueExerciseCount, goal: 30)
                  ])
        ]
    }
    var unlockedTotal: Int { branches.reduce(0) { $0 + $1.unlockedCount } }
}
