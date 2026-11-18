import Foundation
import Combine
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchBridge: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchSnapshot = .empty
    @Published private(set) var connected = false
    @Published var feedback: String?
    private let cacheKey = "bilux.watch.snapshot"
    private let pendingKey = "bilux.watch.pending.workouts"


    @Published private(set) var treatmentRecords = V76TreatmentRecord.load("bilux.v76.treatment.watch")
    @Published private(set) var pendingTreatment = V76TreatmentRecord.load("bilux.v76.treatment.pending")

    func setTreatment(_ confirmed: Bool) {
        let now = Date(), day = V76TreatmentRecord.today()
        guard (treatmentRecords.first { $0.day == day }?.confirmed ?? false) != confirmed else { return }
        let row = V76TreatmentRecord(day: day, confirmed: confirmed, changedAt: now, revision: UUID())
        var local = treatmentRecords, pending = pendingTreatment
        V76TreatmentRecord.merge([row], into: &local)
        V76TreatmentRecord.merge([row], into: &pending)
        V76TreatmentRecord.save(local, "bilux.v76.treatment.watch")
        V76TreatmentRecord.save(pending, "bilux.v76.treatment.pending")
        treatmentRecords = local; pendingTreatment = pending
        v77PublishFace()
        flushTreatment()
        if WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isReachable,
           let encoded = try? JSONEncoder().encode(row) {
            WCSession.default.sendMessage(["type": "v76Treatment", "record": encoded], replyHandler: { reply in
                if let data = reply["biluxSnapshot"] as? Data { Task { @MainActor in self.load(data) } }
            }, errorHandler: { _ in })
        }
    }
    private func flushTreatment() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let session = WCSession.default
        for row in pendingTreatment {
            let id = row.revision.uuidString
            guard !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["revision"] as? String == id }),
                  let data = try? JSONEncoder().encode(row) else { continue }
            session.transferUserInfo(["type": "v76Treatment", "record": data, "revision": id])
        }
    }
    private func acceptTreatment(_ remote: [V76TreatmentRecord]) {
        var records = treatmentRecords
        V76TreatmentRecord.merge(remote, into: &records)
        let pending = pendingTreatment.filter { item in
            !remote.contains { $0.day == item.day && ($0 == item || $0.supersedes(item)) }
        }
        V76TreatmentRecord.save(records, "bilux.v76.treatment.watch")
        V76TreatmentRecord.save(pending, "bilux.v76.treatment.pending")
        treatmentRecords = records; pendingTreatment = pending
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard userInfo["type"] as? String == "v761WorkoutAck", let key = userInfo["id"] as? String else { return }
        Task { @MainActor in
            let pending = UserDefaults.standard.array(forKey: self.pendingKey) as? [[String: Any]] ?? []
            UserDefaults.standard.set(pending.filter { $0["id"] as? String != key }, forKey: self.pendingKey)
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message["biluxSnapshot"] as? Data { Task { @MainActor in self.load(data) } }
    }

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let saved = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            snapshot = saved
            v77PublishFace()
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
        flushTreatment()
    }

    func finishWorkout(start: Date, elapsedMinutes: Int, activity: String = "Séance Apple Watch") {
        guard elapsedMinutes >= 1 else {
            feedback = "Enregistre au moins une minute."
            return
        }
        let event: [String: Any] = [
            "type": "workoutCompleted", "id": UUID().uuidString,
            "durationMinutes": min(elapsedMinutes, 240), "activity": activity,
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

    // V6.1 : envoi idempotent après sauvegarde effective de HKWorkout.
    // UUID Apple Santé = UUID du journal BILUX ; WCSession peut rejouer le transfert.
    func finishLiveWorkout(start: Date, elapsedMinutes: Int, activity: String,
                           workoutID: UUID, activeKcal: Double?,
                           averageBPM: Int?, peakBPM: Int?,
                           zoneSeconds: [Int], referenceMaxBPM: Int,
                           sampleCount: Int, forgePayload: V76ForgePayload? = nil) {
        guard (1...240).contains(elapsedMinutes),
              WCSession.isSupported() else {
            feedback = "Séance Santé sauvegardée, mais transfert BILUX indisponible."
            return
        }
        var event: [String: Any] = [
            "type": "workoutCompleted", "id": workoutID.uuidString,
            "startedAt": start.timeIntervalSince1970,
            "durationMinutes": elapsedMinutes, "activity": activity,
            "source": "healthkit"
        ]
        if let activeKcal, activeKcal.isFinite {
            event["activeKcal"] = max(0, activeKcal)
        }
        if let averageBPM { event["averageBPM"] = averageBPM }
        if let peakBPM { event["peakBPM"] = peakBPM }
        event["zoneSeconds"] = zoneSeconds
        event["referenceMaxBPM"] = referenceMaxBPM
        event["sampleCount"] = sampleCount
        if let forgePayload, forgePayload.valid, let encoded = try? JSONEncoder().encode(forgePayload) {
            event["forgePayload"] = encoded
        }
        var queued = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
        if !queued.contains(where: { ($0["id"] as? String) == workoutID.uuidString }) {
            queued.append(event)
            UserDefaults.standard.set(queued, forKey: pendingKey)
        }
        flushWorkouts()
        feedback = "Nuclear Live sauvegardé. Transfert vers BILUX en cours."
    }

    private func flushWorkouts() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let pending = UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
        let session = WCSession.default
        for event in pending {
            guard let key = event["id"] as? String,
                  !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["id"] as? String == key }) else { continue }
            session.transferUserInfo(event)
        }
        // V7.6.1 : garder la copie Watch jusqu'à la confirmation de l'écriture iPhone.
    }

    private func load(_ data: Data) {
        guard let value = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        if let rows = value.treatmentRecords { acceptTreatment(rows) }
        // Never replace a newer cached plan/RPG snapshot with an older direct reply.
        // Treatment merges separately, even when the snapshot itself is older.
        guard value.updatedAt >= snapshot.updatedAt else { v77PublishFace(); return }
        snapshot = value
        v77PublishFace()
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
// V7.7: copie minimale destinée au cadran. Aucun journal, aucun XP écrit ici.
private struct V77FaceState: Codable, Equatable {
    let observedAt: Date
    let level: Int
    let fraction: Double
    let questsDone: Int
    let questsTotal: Int
    let guardiansDone: Int?
    let treatmentDay: String
    let treatmentConfirmed: Bool?
    let treatmentPending: Bool
    let treatmentObservedAt: Date?
}

@MainActor
private extension WatchBridge {
    func v77PublishFace() {
        guard snapshot.updatedAt != .distantPast,
              snapshot.updatedAt <= Date().addingTimeInterval(120),
              (1...100).contains(snapshot.level), snapshot.xpProgress.isFinite,
              let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bilux.nuclearascension.watchshared") else { return }
        let day = V76TreatmentRecord.today()
        let pending = pendingTreatment.contains { $0.day == day }
        // A previous local action is not equivalent to a confirmed iPhone receipt.
        let row = treatmentRecords.first { $0.day == day }
        let remote = snapshot.treatmentRecords?.first { $0.day == day }
        let same = row == remote
        let treatmentObservedAt = same && !pending && snapshot.treatmentRecords != nil ? snapshot.v77TreatmentSummaryAt : nil
        let value = V77FaceState(observedAt: snapshot.updatedAt, level: snapshot.level,
            fraction: min(1, max(0, snapshot.xpProgress)),
            questsDone: snapshot.quests.filter { $0.completed }.count,
            questsTotal: snapshot.quests.count,
            guardiansDone: snapshot.monthlyWorkouts.map { min(12, max(0, $0)) },
            treatmentDay: day, treatmentConfirmed: treatmentObservedAt != nil ? remote?.confirmed : nil,
            treatmentPending: pending || !same, treatmentObservedAt: treatmentObservedAt)
        let file = folder.appendingPathComponent("bilux-face-v77.json")
        do {
            let previous = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(V77FaceState.self, from: $0) }
            if previous == value { return }
            try JSONEncoder().encode(value).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            let key = "bilux.v77.lastFaceReload"
            let last = UserDefaults.standard.object(forKey: key) as? Date ?? .distantPast
            let changed = previous?.level != value.level || previous?.fraction != value.fraction ||
                previous?.questsDone != value.questsDone || previous?.questsTotal != value.questsTotal ||
                previous?.guardiansDone != value.guardiansDone || previous?.treatmentDay != value.treatmentDay ||
                previous?.treatmentConfirmed != value.treatmentConfirmed || previous?.treatmentPending != value.treatmentPending
            guard changed || Date().timeIntervalSince(last) >= 900 else { return }
            UserDefaults.standard.set(Date(), forKey: key)
            for kind in ["BILUXXPShortcut", "BILUXQuestShortcut", "BILUXGuardianV77", "BILUXTreatmentV77"] {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        } catch { /* Unavailable cache is never a journal error. */ }
    }
}
