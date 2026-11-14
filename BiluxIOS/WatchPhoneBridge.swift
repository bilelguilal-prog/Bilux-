import Foundation
import Combine
import WatchConnectivity

/// Synchronise des résumés vers la montre sans transférer les données médicales sensibles.
/// Les séances saisies sur la montre sont journalisées localement sur l'iPhone une seule fois.
@MainActor
final class WatchPhoneBridge: NSObject, WCSessionDelegate {
    static let shared = WatchPhoneBridge()

    private var journal: BiluxStore?
    private var subscriptions = Set<AnyCancellable>()
    private var snapshot = WatchSnapshot.empty
    private var activated = false
    private var awaitingWorkouts: [[String: Any]] = []

    private override init() { super.init() }

    func configure(journal: BiluxStore, health: HealthKitManager) {
        self.journal = journal
        subscriptions.removeAll()
        journal.$data.combineLatest(health.$today)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data, summary in
                self?.updateSnapshot(data: data, health: summary)
            }
            .store(in: &subscriptions)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        for pending in awaitingWorkouts { receiveWorkout(pending) }
        awaitingWorkouts.removeAll()
    }

    private func updateSnapshot(data: BiluxData, health: DailyHealthSummary) {
        let xp = BILUXV55Progression.totalXP(data)
        let level = BILUXV55Progression.heroLevel(data)
        let rank = BILUXV55Progression.stageNames[BILUXV55Progression.stageIndex(data)]
        let now = Date()
        let questStatus = BILUXV55Progression.currentQuestProgress(data, now: now)
        let didWorkout = questStatus.todayWorkout
        let didEat = questStatus.todayMeal
        let didCheckin = questStatus.todayCheckin
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
            ], updatedAt: now
        )
        sendSnapshot()
    }

    private func sendSnapshot() {
        guard WCSession.isSupported(), activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled,
              let payload = try? JSONEncoder().encode(snapshot) else { return }
        // Dernier état uniquement : ne crée pas de file d'attente médicale.
        try? WCSession.default.updateApplicationContext(["biluxSnapshot": payload])
    }

    private func receiveWorkout(_ message: [String: Any]) {
        guard let journal else { awaitingWorkouts.append(message); return }
        guard (message["type"] as? String) == "workoutCompleted",
              let idString = message["id"] as? String,
              let id = UUID(uuidString: idString),
              let duration = message["durationMinutes"] as? Int,
              (1...240).contains(duration),
              let startedAt = message["startedAt"] as? Double else { return }
        guard !journal.data.workouts.contains(where: { $0.id == id }) else { return }
        guard abs(Date().timeIntervalSince1970 - startedAt) < 7 * 86_400 else { return }
        // Séance manuelle : pas d'écriture HealthKit et pas de doublon avec l'app Exercices.
        // BILUX V5.4 : catégorie validée, repli compatible avec les anciennes Watch.
        let allowedActivities: Set<String> = ["Musculation", "Marche", "Cardio", "Mobilité"]
        let requestedActivity = message["activity"] as? String
        let activity = requestedActivity.flatMap { allowedActivities.contains($0) ? $0 : nil } ?? "Séance Apple Watch"
        journal.add(WorkoutSession(
            id: id, date: Date(timeIntervalSince1970: startedAt),
            activity: activity, durationMinutes: duration,
            notes: "Chronométrée dans BILUX Watch (sans enregistrement HealthKit)", exercises: []
        ))
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            activated = state == .activated
            sendSnapshot()
        }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in sendSnapshot() }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in receiveWorkout(userInfo) }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if message["type"] == nil { replyHandler([:]); return }
            if message["type"] as? String == "requestSnapshot",
               let data = try? JSONEncoder().encode(snapshot) {
                replyHandler(["biluxSnapshot": data])
            } else { replyHandler([:]) }
        }
    }
}
