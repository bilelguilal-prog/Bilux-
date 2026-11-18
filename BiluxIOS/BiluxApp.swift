import SwiftUI
import Combine
import UIKit
import HealthKit
import UniformTypeIdentifiers

@main
@MainActor
struct BiluxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var journal: BiluxStore
    @StateObject private var health: HealthKitManager

    init() {
        let store = BiluxStore()
        let healthManager = HealthKitManager()
        _journal = StateObject(wrappedValue: store)
        _health = StateObject(wrappedValue: healthManager)
        // Activation anticipée pour recevoir les séances envoyées par la montre.
        WatchPhoneBridge.shared.configure(journal: store, health: healthManager)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if journal.recoveryReady { MainTabs() }
                else { V761RecoveryScreen() }
            }
            .environmentObject(journal)
            .environmentObject(health)
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                journal.reloadRecovery()
                WatchPhoneBridge.shared.retryRecoveryWorkouts()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    journal.reloadRecovery()
                    WatchPhoneBridge.shared.retryRecoveryWorkouts()
                }
            }
        }
    }
}

// V7.6.1 : écran indépendant du QG ; aucune action du journal pendant la récupération.
@MainActor
private struct V761RecoveryScreen: View {
    @EnvironmentObject var journal: BiluxStore
    @State private var chooseFile = false
    @State private var newPrompt = false
    @State private var start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var candidates: [WorkoutSession] = []
    @State private var status = ""
    @State private var loading = false
    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("NUCLEAR RECOVERY", systemImage: "shield.lefthalf.filled")
                        .font(.title2.bold()).foregroundStyle(.yellow)
                    Text("Synchronisation RPG et écritures ordinaires suspendues jusqu’à la validation du journal.")
                        .font(.callout)
                    Text(journal.recoveryStatus).font(.callout).foregroundStyle(.yellow)
                    if journal.recoveryReadable {
                        Text("\(journal.data.workouts.count) séances · \(journal.data.meals.count) repas · \(journal.data.checkins.count) bilans · niveau \(journal.heroLevel)")
                            .font(.subheadline)
                    }
                    Button("Relire le journal existant") { journal.reloadRecovery() }
                    Button("Choisir une sauvegarde JSON privée") { chooseFile = true }
                        .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                    if !journal.recoveryBackups.isEmpty {
                        Text("Copies locales (les plus récentes en premier)").font(.headline)
                        ForEach(Array(journal.recoveryBackups.prefix(12)), id: \.self) { file in
                            Button("Restaurer : \(file.lastPathComponent.prefix(20))") { journal.recoveryRestore(file) }
                                .font(.caption)
                        }
                    }
                    if journal.recoveryReadable {
                        Divider()
                        Text("RÉCUPÉRER DEPUIS APPLE SANTÉ").font(.headline)
                        Text("Choisis uniquement les vraies séances Nuclear Live manquantes. Les séries et zones non conservées dans Santé ne seront pas inventées.").font(.caption)
                        DatePicker("Depuis", selection: $start, in: ...Date(), displayedComponents: .date)
                        Button(loading ? "Lecture…" : "Rechercher les séances BILUX") {
                            Task { await findHealthWorkouts() }
                        }.buttonStyle(.bordered).disabled(loading)
                        Text(status).font(.caption)
                        ForEach(candidates) { entry in
                            if !journal.data.workouts.contains(where: { $0.id == entry.id }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.activity + " · \(entry.durationMinutes) min").font(.headline)
                                    Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                    Text(entry.notes).font(.caption)
                                    Button("Récupérer cette séance") { journal.recoveryAddHealth(entry) }.buttonStyle(.bordered)
                                }
                            }
                        }
                        if !journal.data.workouts.isEmpty || !journal.data.meals.isEmpty || !journal.data.checkins.isEmpty || !journal.data.labs.isEmpty {
                            Button("Valider ce journal et reprendre BILUX") { journal.finishRecovery() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    if journal.recoveryCanCreateNew {
                        Button("Démarrer un journal vide (nouvelle installation uniquement)", role: .destructive) { newPrompt = true }
                            .font(.caption)
                    }
                    Text("Ne supprime pas l’app. Ne transmets jamais les JSON personnels à GitHub.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Récupération BILUX")
        }
        .fileImporter(isPresented: $chooseFile, allowedContentTypes: [.json]) { result in
            if case .success(let file) = result { journal.recoveryRestore(file) }
        }
        .alert("Créer un journal neuf ?", isPresented: $newPrompt) {
            Button("Annuler", role: .cancel) {}
            Button("Je n’ai aucune donnée à restaurer", role: .destructive) { journal.finishRecovery(allowNew: true) }
        } message: { Text("Ne choisis pas cette option si ton historique a disparu.") }
    }

    private func findHealthWorkouts() async {
        guard !loading, HKHealthStore.isHealthDataAvailable() else { return }
        loading = true; defer { loading = false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
            let day = Calendar.current.startOfDay(for: start)
            let predicate = HKQuery.predicateForSamples(withStart: day, end: Date(), options: .strictStartDate)
            let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                    limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKWorkout }) }
                }
                healthStore.execute(query)
            }
            let existing = Set(journal.data.workouts.map(\.id))
            candidates = workouts.compactMap { work -> WorkoutSession? in
                let bundle = work.sourceRevision.source.bundleIdentifier
                guard bundle == "com.bilux.nuclearascension" || bundle.hasPrefix("com.bilux.nuclearascension.") else { return nil }
                guard !existing.contains(work.uuid), work.duration.isFinite, work.duration >= 60,
                      work.duration / 60 <= Double(Int.max / 2) else { return nil }
                let activity: String
                switch work.workoutActivityType {
                case .traditionalStrengthTraining, .functionalStrengthTraining: activity = "Musculation"
                case .walking: activity = "Marche"
                case .flexibility: activity = "Mobilité"
                default: activity = "Cardio"
                }
                let kcal = work.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                let calories = kcal.flatMap { $0.isFinite && $0 >= 0 && $0 < 100_000 ? " · \(Int($0.rounded())) kcal actives" : nil } ?? ""
                return WorkoutSession(id: work.uuid, date: work.startDate, activity: activity,
                    durationMinutes: max(1, Int((work.duration / 60).rounded())),
                    notes: "Récupération V7.6.1 depuis Apple Santé\(calories).", exercises: [])
            }
            status = candidates.isEmpty ? "Aucune séance BILUX manquante visible. Vérifie les dates et l’accès en lecture à Santé." : "\(candidates.count) séance(s) à examiner. Aucun import automatique."
        } catch { status = "Lecture Santé impossible : \(error.localizedDescription)" }
    }
}
