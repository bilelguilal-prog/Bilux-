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
    @State private var v77PreviewURL: URL?
    @State private var v77PreviewText = ""
    @State private var v77Confirm = false
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
                    if !v77PreviewText.isEmpty { Text(v77PreviewText).font(.caption).foregroundStyle(.secondary) }
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
                            Button("Examiner : \(file.lastPathComponent.prefix(20))") { v77Inspect(file) }
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
            if case .success(let file) = result { v77Inspect(file) }
        }
        .confirmationDialog("Restaurer la sauvegarde examinée ?", isPresented: $v77Confirm, titleVisibility: .visible) {
            Button("Restaurer et fusionner", role: .destructive) {
                if let file = v77PreviewURL { journal.recoveryRestore(file) }
                v77PreviewURL = nil
            }
            Button("Annuler", role: .cancel) { v77PreviewURL = nil }
        } message: { Text(v77PreviewText) }
        .alert("Créer un journal neuf ?", isPresented: $newPrompt) {
            Button("Annuler", role: .cancel) {}
            Button("Je n’ai aucune donnée à restaurer", role: .destructive) { journal.finishRecovery(allowNew: true) }
        } message: { Text("Ne choisis pas cette option si ton historique a disparu.") }
    }

    private func v77Inspect(_ file: URL) {
        v77PreviewURL = nil
        do {
            let preview = try journal.v77Preview(file)
            v77PreviewText = "Copie sélectionnée : " + preview.text + ". Les entrées locales non présentes dans cette copie seront fusionnées par UUID ; l’ancrage RPG provient de la copie choisie."
            v77PreviewURL = file
            v77Confirm = true
        } catch { v77PreviewText = "Copie illisible ou vide. Aucune restauration effectuée." }
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
// V7.7 : aucune restauration depuis le QG sans passer le verrou Recovery.
@MainActor
struct V77GuardianCenter: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var selected: URL?
    @State private var summary: V77BackupSummary?
    @State private var message = ""
    @State private var openRecovery = false
    @State private var events: [String] = []
    @State private var limit = 20
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("NUCLEAR GUARDIAN", systemImage: "shield.lefthalf.filled").font(.title2.bold()).foregroundStyle(.yellow)
                Text("Le journal principal reste dans son stockage protégé. Les copies locales ne remplacent pas un export privé dans Fichiers.").font(.caption)
                GroupBox("Journal durable") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(journal.data.workouts.count) séances · niveau \(journal.heroLevel) · \(journal.totalXP) XP")
                        if let date = journal.v77LastSaved { Text("Dernière écriture du journal : " + date.formatted(date: .abbreviated, time: .shortened)) }
                        else { Text("Date de sauvegarde indisponible") }
                        Text("\(journal.recoveryBackups.count) copies locales").foregroundStyle(.secondary)
                        Button("Créer une copie protégée maintenant") {
                            do { let file = try journal.v77Checkpoint(); inspect(file); message = "Copie vérifiée, journal inchangé." }
                            catch { message = "Copie non créée. Journal inchangé : \(error.localizedDescription)" }
                        }.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(message).font(.caption).foregroundStyle(.yellow)
                Text("COPIES LOCALES").font(.headline)
                ForEach(Array(journal.recoveryBackups.prefix(limit)), id: \.self) { file in
                    Button { inspect(file) } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            VStack(alignment: .leading) {
                                let stamp = file.lastPathComponent.split(separator: "-").first.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0 / 1000) }
                                Text(stamp?.formatted(date: .abbreviated, time: .shortened) ?? file.lastPathComponent).font(.subheadline.bold())
                                Text("Aperçu sans restauration").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
                if journal.recoveryBackups.count > limit { Button("Voir davantage de copies") { limit += 20 } }
                if let selected, let summary {
                    GroupBox("Aperçu de la copie") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(summary.text).font(.callout)
                            Text("Aucun changement au journal. Le contenu de cette copie peut différer de l’état actuel.").font(.caption)
                            ShareLink(item: selected) { Label("Exporter la copie dans Fichiers", systemImage: "square.and.arrow.up") }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                Text("SYNCHRONISATION WATCH").font(.headline)
                Text("Événements techniques enregistrés depuis V7.7. Un résumé mis en file ne signifie pas qu'il a été reçu par la montre.").font(.caption).foregroundStyle(.secondary)
                if events.isEmpty { Text("Aucun événement journalisé.").font(.caption) }
                ForEach(Array(events.enumerated()), id: \.offset) { item in Text(item.element).font(.caption.monospaced()) }
                Button("Actualiser les diagnostics") { refresh() }.buttonStyle(.bordered)
                Divider()
                Button("Ouvrir le mode récupération", role: .destructive) { openRecovery = true }
                    .buttonStyle(.bordered)
                Text("Une copie protégée sera créée avant de suspendre les écritures. Ne choisis cette fonction que pour une véritable restauration.").font(.caption)
            }.padding()
        }.navigationTitle("Guardian")
        .onAppear { refresh() }
        .confirmationDialog("Suspendre les écritures et ouvrir Recovery ?", isPresented: $openRecovery, titleVisibility: .visible) {
            Button("Créer une copie et ouvrir Recovery", role: .destructive) {
                do { try journal.v77BeginRecovery() }
                catch { message = "Ouverture refusée : \(error.localizedDescription)." }
            }
            Button("Annuler", role: .cancel) {}
        }
    }
    private func inspect(_ file: URL) {
        selected = nil; summary = nil
        do { let result = try journal.v77Preview(file); selected = file; summary = result; message = "Copie lisible ; aucun changement au journal." }
        catch { message = "Copie illisible ou vide : elle est conservée, sans restauration." }
    }
    private func refresh() {
        journal.v77RefreshCopies()
        events = UserDefaults.standard.stringArray(forKey: "bilux.v77.syncDiagnostics") ?? []
    }
}
