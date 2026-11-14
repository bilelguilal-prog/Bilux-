import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchSnapshot = .empty
    @Published private(set) var connected = false
    @Published var feedback: String?
    private let cacheKey = "bilux.watch.snapshot"
    private let pendingKey = "bilux.watch.pending.workouts"

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let saved = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            snapshot = saved
        }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func refresh() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        if let payload = WCSession.default.receivedApplicationContext["biluxSnapshot"] as? Data { load(payload) }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["type": "requestSnapshot"], replyHandler: { reply in
                if let data = reply["biluxSnapshot"] as? Data {
                    Task { @MainActor in self.load(data) }
                }
            }, errorHandler: { _ in })
        }
        flushWorkouts()
    }

    func finishWorkout(start: Date, elapsedMinutes: Int) {
        guard elapsedMinutes >= 1 else {
            feedback = "Enregistre au moins une minute."
            return
        }
        let event: [String: Any] = [
            "type": "workoutCompleted", "id": UUID().uuidString,
            "durationMinutes": min(elapsedMinutes, 240),
            "startedAt": start.timeIntervalSince1970
        ]
        guard WCSession.isSupported() else {
            feedback = "Connexion Apple Watch indisponible."
            return
        }
        var queued = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
        queued.append(event)
        UserDefaults.standard.set(queued, forKey: pendingKey)
        flushWorkouts()
        feedback = "Séance enregistrée sur la montre. Transfert vers l'iPhone en attente ou en cours."
    }

    private func flushWorkouts() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
        for event in pending { WCSession.default.transferUserInfo(event) }
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    private func load(_ data: Data) {
        guard let value = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        snapshot = value
        UserDefaults.standard.set(data, forKey: cacheKey)
        connected = true
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            connected = state == .activated && session.isCompanionAppInstalled
            refresh()
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in refresh() }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let data = context["biluxSnapshot"] as? Data else { return }
        Task { @MainActor in load(data) }
    }
}
