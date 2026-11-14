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
        let xp = data.workouts.count * 25
            + Set(data.meals.map { Calendar.current.startOfDay(for: $0.date) }).count * 8
            + Set(data.checkins.map { Calendar.current.startOfDay(for: $0.date) }).count * 8
        let level = max(1, xp / 100 + 1)
        let rank: String
        switch level {
        case 15...: rank = "ASCENSION"
        case 10...: rank = "NUCLÉAIRE"
        case 6...: rank = "RÉACTEUR"
        case 3...: rank = "ÉVEIL"
        default: rank = "SURVIVANT"
        }
        let now = Date()
        let didWorkout = data.workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: now) }
        let didEat = data.meals.contains { Calendar.current.isDate($0.date, inSameDayAs: now) } || health.consumedKcal != nil
        let didCheckin = data.checkins.contains { Calendar.current.isDate($0.date, inSameDayAs: now) }
        snapshot = WatchSnapshot(
            heroName: data.heroName, level: level, rank: rank,
            totalXP: xp, xpProgress: Double(xp % 100) / 100,
            steps: health.steps, activeKcal: health.activeKcal,
            latestHeartRate: health.heartRateBPM, sleepHours: health.sleepHours,
            workoutMinutes: health.workoutMinutes, energyConsumed: health.consumedKcal,
            quests: [
                WatchQuest(id: "workout", title: "Consigner une séance", completed: didWorkout, reward: 25),
                WatchQuest(id: "nutrition", title: "Suivre l'alimentation", completed: didEat, reward: 8),
                WatchQuest(id: "checkin", title: "Noter son ressenti", completed: didCheckin, reward: 8)
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
        journal.add(WorkoutSession(
            id: id, date: Date(timeIntervalSince1970: startedAt),
            activity: "Séance Apple Watch", durationMinutes: duration,
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
