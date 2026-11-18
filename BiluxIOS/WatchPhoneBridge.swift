import Foundation
import Combine
import WatchConnectivity
import UIKit

/// Synchronise des résumés vers la montre sans transférer les données médicales sensibles.
/// Les séances saisies sur la montre sont journalisées localement sur l'iPhone une seule fois.
@MainActor
final class WatchPhoneBridge: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchPhoneBridge()

    private var journal: BiluxStore?
    private var subscriptions = Set<AnyCancellable>()
    private var snapshot = WatchSnapshot.empty
    private var recoverySnapshotValid = false
    private var activated = false
    private var awaitingWorkouts: [[String: Any]] = []

    private override init() { super.init() }

    // V7.6: journal de confirmation minimal, distinct des bilans Santé et des XP.
    @Published private(set) var treatmentRecords = V76TreatmentRecord.load("bilux.v76.treatment.phone")
    func setTreatment(_ confirmed: Bool) {
        let now = Date()
        let day = V76TreatmentRecord.today(now)
        guard (treatmentRecords.first { $0.day == day }?.confirmed ?? false) != confirmed else { return }
        let row = V76TreatmentRecord(day: day, confirmed: confirmed, changedAt: now, revision: UUID())
        mergeTreatment(row)
    }
    func exportTreatment() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BILUX-Traitement-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(treatmentRecords).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    func importTreatment(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let raw = try Data(contentsOf: url)
        guard raw.count <= 2_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        let rows = try JSONDecoder().decode([V76TreatmentRecord].self, from: raw)
        guard rows.count <= 10_000, rows.allSatisfy({ $0.valid }) else { throw CocoaError(.fileReadCorruptFile) }
        mergeTreatmentRows(rows)
    }
    private func mergeTreatment(_ row: V76TreatmentRecord) {
        guard row.valid else { return }
        mergeTreatmentRows([row])
    }
    private func mergeTreatmentRows(_ rows: [V76TreatmentRecord]) {
        var merged = treatmentRecords
        V76TreatmentRecord.merge(rows, into: &merged)
        if merged != treatmentRecords {
            V76TreatmentRecord.save(merged, "bilux.v76.treatment.phone")
            treatmentRecords = merged
            v77Log("Confirmation quotidienne fusionnée")
        }
        sendSnapshot()
        // A direct message is opportunistic; application context remains the durable latest state.
        if WCSession.isSupported(), activated, WCSession.default.isReachable,
           let data = encodedSnapshot() {
            WCSession.default.sendMessage(["biluxSnapshot": data], replyHandler: nil, errorHandler: { _ in })
        }
    }
    private func encodedSnapshot() -> Data? {
        guard recoverySnapshotValid, journal?.safeSnapshotData != nil else { return nil }
        var enriched = snapshot
        // Ne jamais réhorodater un résumé vide ou obsolète comme s'il était neuf.
        // Limit plan snapshots to a modest payload; the full plan library remains on iPhone.
        let days = V76AvailablePlanDays()
        enriched.forgeDays = Array(days.prefix(20))
        enriched.forgeDayCount = days.count
        enriched.treatmentRecords = Array(treatmentRecords.prefix(366))
        enriched.v77TreatmentSummaryAt = Date()
        return try? JSONEncoder().encode(enriched)
    }
    private func receiveV76Event(_ message: [String: Any]) -> Bool {
        guard message["type"] as? String == "v76Treatment" else { return false }
        if let data = message["record"] as? Data, data.count <= 2048,
           let row = try? JSONDecoder().decode(V76TreatmentRecord.self, from: data) {
            mergeTreatment(row)
        }
        return true
    }


    func configure(journal: BiluxStore, health: HealthKitManager) {
        self.journal = journal
        subscriptions.removeAll()
        journal.$data.combineLatest(health.$today)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data, summary in
                self?.updateSnapshot(data: data, health: summary)
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: Notification.Name("bilux.v73.eternalforge.changed"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sendSnapshot() }
            .store(in: &subscriptions)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        journal.$recoveryReady.receive(on: DispatchQueue.main).sink { [weak self, weak health] ready in
            guard let self, ready, let health, let data = self.journal?.safeSnapshotData else { return }
            self.updateSnapshot(data: data, health: health.today)
            self.retryRecoveryWorkouts()
        }.store(in: &subscriptions)
        retryRecoveryWorkouts()
    }

    private func updateSnapshot(data _: BiluxData, health: DailyHealthSummary) {
        guard let data = journal?.safeSnapshotData else { recoverySnapshotValid = false; return }
        recoverySnapshotValid = true
        let xp = BILUXV55Progression.totalXP(data)
        let level = BILUXV55Progression.heroLevel(data)
        let rank = BILUXV55Progression.stageNames[BILUXV55Progression.stageIndex(data)]
        let now = Date()
        let questStatus = BILUXV55Progression.currentQuestProgress(data, now: now)
        let didWorkout = questStatus.todayWorkout
        let didEat = questStatus.todayMeal
        let didCheckin = questStatus.todayCheckin
        let appearance = journal.map { BILUXV60WatchAppearance($0) }
        let mastery = V63MasterySnapshot.evaluate(data)
        let masteryPaths: [WatchMasteryPath] = mastery.branches.map { branch in
            WatchMasteryPath(
                id: branch.id, title: branch.title, symbol: branch.icon,
                current: branch.current, target: branch.ultimateTarget,
                unlocked: branch.unlockedCount, total: branch.nodes.count,
                nextTitle: branch.next?.title, remaining: branch.next?.remaining,
                unit: branch.unit
            )
        }
        let latest = data.workouts.max(by: { $0.date < $1.date })
        let lastLabel = latest.map { "\($0.activity) · \($0.durationMinutes) min" }
        snapshot = WatchSnapshot(
            heroName: data.heroName, level: level, rank: rank,
            totalXP: xp, xpProgress: BILUXV55Progression.fraction(data),
            steps: health.steps, activeKcal: health.activeKcal,
            latestHeartRate: health.heartRateBPM, sleepHours: health.sleepHours,
            workoutMinutes: health.workoutMinutes, energyConsumed: health.consumedKcal,
            quests: [
                WatchQuest(id: "workout", title: "Consigner une séance", completed: didWorkout, reward: 45),
                WatchQuest(id: "nutrition", title: "Suivre l'alimentation", completed: didEat, reward: 6),
                WatchQuest(id: "checkin", title: "Noter son ressenti", completed: didCheckin, reward: 6)
            ], updatedAt: now,
            xpRemaining: BILUXV55Progression.remainingXP(data),
            weeklyWorkouts: questStatus.weeklyWorkouts,
            monthlyWorkouts: questStatus.monthlyWorkouts,
            quarterWorkouts: questStatus.quarterWorkouts,
            workoutCount: data.workouts.count,
            lastWorkoutLabel: lastLabel,
            equippedTitle: appearance?.title,
            equippedAura: appearance?.aura,
            masteryPaths: masteryPaths
        )
        sendSnapshot()
    }

    private func sendSnapshot() {
        guard WCSession.isSupported(), activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled,
              let payload = encodedSnapshot() else { return }
        // Dernier état uniquement : ne crée pas de file d'attente médicale.
        do {
            try WCSession.default.updateApplicationContext(["biluxSnapshot": payload])
            v77Log("Résumé RPG mis en file")
        } catch { v77Log("Échec de mise en file du résumé") }
    }

    // Reçu iPhone durable avant traitement. Le journal reste en protection complète.
    // L'inbox utilise la protection après premier déverrouillage pour les transferts de fond.
    private var recoveryInboxURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BiluxWatchRecoveryInbox.plist")
    }
    private func receiveWorkout(_ message: [String: Any]) {
        guard message["type"] as? String == "workoutCompleted",
              let key = message["id"] as? String, UUID(uuidString: key) != nil else { return }
        if !awaitingWorkouts.contains(where: { $0["id"] as? String == key }) { awaitingWorkouts.append(message) }
        retryRecoveryWorkouts()
    }
    func retryRecoveryWorkouts() {
        let file = recoveryInboxURL
        do {
            var pending: [[String: Any]] = []
            do {
                let raw = try Data(contentsOf: file)
                guard let rows = try PropertyListSerialization.propertyList(from: raw, options: [], format: nil) as? [[String: Any]] else { return }
                pending = rows
            } catch let e as NSError {
                guard e.domain == NSCocoaErrorDomain && e.code == NSFileReadNoSuchFileError else { return }
            }
            for message in awaitingWorkouts where !pending.contains(where: { ($0["id"] as? String) == (message["id"] as? String) }) {
                pending.append(message)
            }
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            func write(_ rows: [[String: Any]]) throws {
                let raw = try PropertyListSerialization.data(fromPropertyList: rows, format: .binary, options: 0)
                try raw.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            try write(pending)
            awaitingWorkouts.removeAll()
            guard let journal, journal.recoveryReady, UIApplication.shared.isProtectedDataAvailable else { return }
            var remaining: [[String: Any]] = []
            for message in pending {
                guard let key = message["id"] as? String, let id = UUID(uuidString: key) else { continue }
                receiveWorkoutNow(message)
                // Après sauvegarde effective uniquement : aucune perte silencieuse par acquittement prématuré.
                if journal.safeSnapshotData?.workouts.contains(where: { $0.id == id && !$0.notes.hasPrefix("Récupération V7.6.1 depuis Apple Santé") }) == true {
                    if WCSession.isSupported(), WCSession.default.activationState == .activated {
                        WCSession.default.transferUserInfo(["type": "v761WorkoutAck", "id": key])
                        v77Log("Séance stockée · acquittement mis en file")
                    }
                } else { remaining.append(message) }
            }
            try write(remaining)
        } catch {
            v77Log("Transfert séance en attente · erreur de stockage")
            // Le fichier précédemment écrit et/ou la file Watch restent disponibles pour un nouvel essai.
        }
    }

    private func receiveWorkoutNow(_ message: [String: Any]) {
        guard let journal, journal.recoveryReady else { return }
        guard (message["type"] as? String) == "workoutCompleted",
              let idString = message["id"] as? String,
              let id = UUID(uuidString: idString),
              let duration = message["durationMinutes"] as? Int,
              (1...240).contains(duration),
              let startedAt = message["startedAt"] as? Double else { return }
        let forge = (message["forgePayload"] as? Data).flatMap { raw -> V76ForgePayload? in
            guard raw.count <= 100_000, let parsed = try? JSONDecoder().decode(V76ForgePayload.self, from: raw), parsed.valid else { return nil }
            return parsed
        }
        let recoveredEntry = journal.data.workouts.first(where: { $0.id == id })
        // Ne jamais réécrire une séance déjà journalisée, sauf mise à niveau d'une
        // entrée minimale issue de la recherche Santé de cette version.
        if let old = recoveredEntry, !old.notes.hasPrefix("Récupération V7.6.1 depuis Apple Santé") {
            if let forge { V76LinkWatchWorkout(forge, workout: old) }
            return
        }
        guard abs(Date().timeIntervalSince1970 - startedAt) < 7 * 86_400 else { return }
        // Séance manuelle : pas d'écriture HealthKit et pas de doublon avec l'app Exercices.
        // BILUX V5.4 : catégorie validée, repli compatible avec les anciennes Watch.
        let allowedActivities: Set<String> = ["Musculation", "Marche", "Cardio", "Mobilité"]
        let requestedActivity = message["activity"] as? String
        let activity = requestedActivity.flatMap { allowedActivities.contains($0) ? $0 : nil } ?? "Séance Apple Watch"
        // V6.1 : une vraie séance Santé, identifiée par son UUID d'origine,
        // peut figurer dans La Forge sans être recréée dans Apple Santé.
        let isLive = (message["source"] as? String) == "healthkit"
        let note: String
        if isLive {
            let calories = (message["activeKcal"] as? Double).flatMap { $0.isFinite ? max(0, $0) : nil }
            let energyText = calories.map { " · \(Int($0.rounded())) kcal actives" } ?? ""
            note = "Nuclear Live : séance déjà sauvegardée dans Apple Santé\(energyText)."
        } else {
            note = "Chronométrée dans BILUX Watch (sans enregistrement HealthKit)"
        }
        var entry = WorkoutSession(
            id: id, date: Date(timeIntervalSince1970: startedAt),
            activity: activity, durationMinutes: duration,
            notes: note, exercises: []
        )
        if let forge, isLive {
            entry.exercises = forge.exercises.map { exercise in
                WorkoutExercise(name: exercise.name, sets: exercise.sets.map { set in
                    WorkoutSet(id: set.id, reps: set.reps, weight: set.weight)
                })
            }
        }
        if isLive {
            let count = max(0, min(25_000, message["sampleCount"] as? Int ?? 0))
            let mean = (message["averageBPM"] as? Int).flatMap { (35...240).contains($0) ? $0 : nil }
            let peak = (message["peakBPM"] as? Int).flatMap { (35...240).contains($0) ? $0 : nil }
            let calorie = (message["activeKcal"] as? Double).flatMap { $0.isFinite && (0...20_000).contains($0) ? $0 : nil }
            let raw = message["zoneSeconds"] as? [Int] ?? []
            let zones = raw.count == 5 && raw.allSatisfy({ (0...(duration * 60)).contains($0) }) && raw.reduce(0, +) <= duration * 60 + 60 ? raw : [0, 0, 0, 0, 0]
            let ref = max(120, min(220, message["referenceMaxBPM"] as? Int ?? 190))
            entry.liveReport = NuclearLiveReport(averageBPM: mean, peakBPM: peak,
                                                  activeKcal: calorie, zoneSeconds: zones,
                                                  referenceMaxBPM: ref, sampleCount: count)
        }
        if let old = recoveredEntry {
            if !old.exercises.isEmpty { entry.exercises = old.exercises }
            if let rpe = old.rpe { entry.rpe = rpe }
            journal.updateWorkout(entry)
        } else { journal.add(entry) }
        if let forge, isLive, journal.safeSnapshotData?.workouts.contains(where: { $0.id == entry.id }) == true {
            V76LinkWatchWorkout(forge, workout: entry)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            activated = state == .activated
            retryRecoveryWorkouts()
            sendSnapshot()
        }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in sendSnapshot() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if !receiveV76Event(userInfo) { receiveWorkout(userInfo) }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if message["type"] == nil { replyHandler([:]); return }
            let handled = receiveV76Event(message)
            if (handled || message["type"] as? String == "requestSnapshot"),
               let data = encodedSnapshot() {
                replyHandler(["biluxSnapshot": data])
            } else { replyHandler([:]) }
        }
    }
}
// V7.7 : journal technique borné. Aucune donnée médicale, aucun UUID de séance, aucun contenu de message.
@MainActor
private extension WatchPhoneBridge {
    func v77Log(_ event: String) {
        let key = "bilux.v77.syncDiagnostics"
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        let entry = stamp + " · " + event
        var rows = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard rows.first != entry else { return }
        rows.insert(entry, at: 0)
        UserDefaults.standard.set(Array(rows.prefix(40)), forKey: key)
    }
}
