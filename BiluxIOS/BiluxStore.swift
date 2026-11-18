import Foundation
import Combine
import UIKit

@MainActor
final class BiluxStore: ObservableObject {
    @Published var data: BiluxData = BiluxData()
    @Published var feedback: String?

    // V7.6.1 : l'absence de journal n'est jamais une autorisation d'écraser un fichier.
    @Published private(set) var recoveryReady = false
    @Published private(set) var recoveryStatus = "Journal en attente de lecture."
    @Published private(set) var recoveryReadable = false
    @Published private(set) var recoveryBackups: [URL] = []
    private let url: URL
    private let backupDirectory: URL
    private var committedRaw: Data?
    private var committedData: BiluxData?
    private var inspected = false
    private let approvalKey = "bilux.v761.storage.approved"

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = directory.appendingPathComponent("bilux-v4.json")
        backupDirectory = directory.appendingPathComponent("BiluxRecoveryHistory", isDirectory: true)
        reloadRecovery()
    }

    private func readExisting() throws -> Data? {
        // Ne pas utiliser fileExists : un refus de lecture ne doit pas devenir une absence.
        guard UIApplication.shared.isProtectedDataAvailable else { throw CocoaError(.fileReadNoPermission) }
        do { return try Data(contentsOf: url) }
        catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return nil }
            throw error
        }
    }

    private func refreshCopies() {
        recoveryBackups = ((try? FileManager.default.contentsOfDirectory(at: backupDirectory,
            includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func reloadRecovery() {
        guard !recoveryReady else { return }
        guard UIApplication.shared.isProtectedDataAvailable else {
            recoveryStatus = "Déverrouille l’iPhone pour lire le journal protégé."
            return
        }
        do {
            let raw = try readExisting()
            committedRaw = raw
            committedData = nil
            inspected = true
            recoveryReadable = false
            if let raw {
                do {
                    let loaded = try JSONDecoder().decode(BiluxData.self, from: raw)
                    guard loaded.version == 4 else { throw CocoaError(.fileReadCorruptFile) }
                    committedData = loaded
                    data = loaded
                    recoveryReadable = true
                    recoveryStatus = "Journal actuel : \(loaded.workouts.count) séances, \(loaded.meals.count) repas, \(loaded.checkins.count) bilans."
                    if UserDefaults.standard.bool(forKey: approvalKey) && loaded.longAscensionAnchor != nil && !Self.isEmpty(loaded) {
                        recoveryReady = true
                    } else { UserDefaults.standard.set(false, forKey: approvalKey) }
                } catch {
                    UserDefaults.standard.set(false, forKey: approvalKey)
                    recoveryStatus = "Journal illisible. Il est conservé intact ; restaure une copie JSON."
                }
            } else {
                UserDefaults.standard.set(false, forKey: approvalKey)
                recoveryStatus = "Aucun journal principal trouvé. Restaure une sauvegarde avant de reprendre."
            }
            refreshCopies()
        } catch {
            inspected = false
            recoveryReadable = false
            recoveryStatus = "Lecture bloquée : \(error.localizedDescription). Aucune écriture autorisée."
        }
    }

    private static func isEmpty(_ value: BiluxData) -> Bool {
        value.workouts.isEmpty && value.meals.isEmpty && value.checkins.isEmpty && value.labs.isEmpty
    }

    // Un instantané valable pour WCSession provient uniquement du dernier état écrit.
    var safeSnapshotData: BiluxData? { recoveryReady ? committedData : nil }

    // Conserve chaque ancienne version lisible (ou les octets bruts d'un fichier illisible).
    // Si cette sauvegarde échoue, aucune écriture du journal principal n'est tentée.
    private func persist(_ candidate: BiluxData) throws {
        guard inspected, UIApplication.shared.isProtectedDataAvailable else { throw CocoaError(.fileWriteNoPermission) }
        let previous = try readExisting()
        guard previous == committedRaw else { throw CocoaError(.fileWriteUnknown) }
        let encoded = try JSONEncoder().encode(candidate)
        _ = try JSONDecoder().decode(BiluxData.self, from: encoded)
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        if let previous, previous != encoded {
            let stamp = String(format: "%020.0f", Date().timeIntervalSince1970 * 1000)
            let name = "\(stamp)-\(UUID().uuidString).json"
            try previous.write(to: backupDirectory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        }
        if previous != encoded { try encoded.write(to: url, options: [.atomic, .completeFileProtection]) }
        committedRaw = encoded
        committedData = candidate
        data = candidate
        recoveryReadable = true
        refreshCopies()
    }

    @discardableResult
    func save() -> Bool {
        guard recoveryReady else {
            data = committedData ?? BiluxData()
            feedback = "Journal en récupération : écriture refusée."
            return false
        }
        do { try persist(data); return true }
        catch {
            data = committedData ?? BiluxData()
            feedback = "Écriture annulée, dernière version conservée : \(error.localizedDescription)"
            return false
        }
    }

    // Le JSON choisi est la base explicite de récupération. Les éventuels enregistrements
    // survivants sont fusionnés par UUID. Ni la date d'ancrage ni les XP ne sont inventés.
    func recoveryRestore(_ source: URL) {
        guard !recoveryReady else { return }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: source)
            var candidate = try JSONDecoder().decode(BiluxData.self, from: raw)
            guard candidate.version == 4, !Self.isEmpty(candidate) else { throw CocoaError(.fileReadCorruptFile) }
            if let current = committedData {
                candidate.workouts = Self.merged(candidate.workouts, current.workouts)
                candidate.meals = Self.merged(candidate.meals, current.meals)
                candidate.checkins = Self.merged(candidate.checkins, current.checkins)
                candidate.labs = Self.merged(candidate.labs, current.labs)
                candidate.exerciseLibrary = Array(Set((candidate.exerciseLibrary ?? []) + (current.exerciseLibrary ?? []))).sorted()
                if candidate.caloriesGoal == nil { candidate.caloriesGoal = current.caloriesGoal }
            }
            if candidate.longAscensionAnchor == nil { candidate.longAscensionAnchor = BILUXV55Progression.makeAnchor(candidate) }
            try persist(candidate)
            UserDefaults.standard.set(false, forKey: approvalKey)
            recoveryStatus = "Sauvegarde restaurée : \(candidate.workouts.count) séances, \(candidate.meals.count) repas, \(candidate.checkins.count) bilans. Niveau \(BILUXV55Progression.heroLevel(candidate))."
        } catch { recoveryStatus = "Restauration refusée : \(error.localizedDescription). Le journal précédent est conservé." }
    }

    private static func merged<T: Identifiable>(_ base: [T], _ additional: [T]) -> [T] {
        var ids = Set<T.ID>()
        return (base + additional).filter { ids.insert($0.id).inserted }
    }

    func recoveryAddHealth(_ entry: WorkoutSession) {
        guard !recoveryReady, var candidate = committedData else { return }
        guard !candidate.workouts.contains(where: { $0.id == entry.id }) else {
            recoveryStatus = "Cette séance est déjà dans BILUX."
            return
        }
        candidate.workouts.insert(entry, at: 0)
        do {
            try persist(candidate)
            recoveryStatus = "Séance Santé récupérée. Niveau \(BILUXV55Progression.heroLevel(candidate))."
        } catch { recoveryStatus = "Séance non importée : \(error.localizedDescription)" }
    }

    func finishRecovery(allowNew: Bool = false) {
        guard !recoveryReady, inspected else { return }
        // Un journal corrompu n'est jamais effacé pour en créer un neuf.
        guard var candidate = committedData ?? (allowNew && committedRaw == nil ? BiluxData() : nil) else { return }
        guard allowNew || !Self.isEmpty(candidate) else { return }
        if candidate.longAscensionAnchor == nil { candidate.longAscensionAnchor = BILUXV55Progression.makeAnchor(candidate) }
        do {
            try persist(candidate)
            UserDefaults.standard.set(true, forKey: approvalKey)
            recoveryReady = true
        } catch { recoveryStatus = "Reprise refusée : \(error.localizedDescription)" }
    }

    var recoveryCanCreateNew: Bool { inspected && (committedRaw == nil || committedData.map(Self.isEmpty) == true) }

    func add(_ session: WorkoutSession) {
        guard recoveryReady, !data.workouts.contains(where: { $0.id == session.id }) else { return }
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
            guard recoveryReady else { throw CocoaError(.fileWriteNoPermission) }
            let result: BiluxData
            if object["version"] as? Int == 4 {
                result = try JSONDecoder().decode(BiluxData.self, from: raw)
            } else { result = try V3Import.parse(object) }
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
            guard save() else { return }
            feedback = "Import terminé : \(result.workouts.count) séances, \(result.meals.count) repas, \(result.checkins.count) bilans et \(result.labs.count) résultats trouvés."
        } catch { feedback = "Import impossible : \(error.localizedDescription)" }
    }
    func exportJSON() -> URL? {
        do {
            guard recoveryReady else { throw CocoaError(.fileReadNoPermission) }
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("bilux-v4-sauvegarde-\(UUID().uuidString).json")
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
// MARK: - V7.7 Guardian — read-only inspection and explicit protected checkpoints.
struct V77BackupSummary {
    let sessions: Int
    let meals: Int
    let checkins: Int
    let labs: Int
    let level: Int
    let xp: Int
    var text: String { "\(sessions) séances · \(meals) repas · \(checkins) bilans · \(labs) analyses · niveau \(level) · \(xp) XP" }
}

@MainActor
extension BiluxStore {
    func v77RefreshCopies() { refreshCopies() }
    var v77LastSaved: Date? {
        guard recoveryReady, UIApplication.shared.isProtectedDataAvailable,
              committedRaw != nil, let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attributes[.modificationDate] as? Date
    }
    func v77Preview(_ source: URL) throws -> V77BackupSummary {
        guard UIApplication.shared.isProtectedDataAvailable else { throw CocoaError(.fileReadNoPermission) }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let raw = try Data(contentsOf: source)
        let value = try JSONDecoder().decode(BiluxData.self, from: raw)
        guard value.version == 4, !Self.isEmpty(value) else { throw CocoaError(.fileReadCorruptFile) }
        return V77BackupSummary(sessions: value.workouts.count, meals: value.meals.count,
            checkins: value.checkins.count, labs: value.labs.count,
            level: BILUXV55Progression.heroLevel(value), xp: BILUXV55Progression.totalXP(value))
    }
    @discardableResult
    func v77Checkpoint() throws -> URL {
        guard recoveryReady, let raw = committedRaw, try readExisting() == raw,
              let value = committedData, !Self.isEmpty(value) else { throw CocoaError(.fileReadNoPermission) }
        let fm = FileManager.default
        try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let stamp = String(format: "%020.0f", Date().timeIntervalSince1970 * 1000)
        let file = backupDirectory.appendingPathComponent("\(stamp)-\(UUID().uuidString).json")
        try raw.write(to: file, options: [.atomic, .completeFileProtection])
        guard try Data(contentsOf: file) == raw else { throw CocoaError(.fileWriteUnknown) }
        refreshCopies()
        return file
    }
    func v77BeginRecovery() throws {
        // The existing recovery gate takes over. Never reset the journal or the in-memory data.
        _ = try v77Checkpoint()
        UserDefaults.standard.set(false, forKey: approvalKey)
        recoveryStatus = "Récupération ouverte à ta demande. Une copie protégée du journal vient d’être créée."
        recoveryReady = false
    }
}
