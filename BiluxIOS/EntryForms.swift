import SwiftUI

struct DraftSet: Identifiable {
    var id: UUID = UUID()
    var reps: String = "10"
    var weight: String = ""
}
struct DraftExercise: Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var sets: [DraftSet] = [DraftSet()]
}

// Le même formulaire sert à créer ET à modifier une séance existante.
struct NewWorkoutScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var journal: BiluxStore

    private let editingSession: WorkoutSession?
    @State private var date: Date
    @State private var activity: String
    @State private var duration: String
    @State private var notes: String
    @State private var rpe: Int
    @State private var exercises: [DraftExercise]
    @State private var error: String?

    init(session: WorkoutSession? = nil) {
        editingSession = session
        _date = State(initialValue: session?.date ?? .now)
        _activity = State(initialValue: session?.activity ?? "Musculation")
        _duration = State(initialValue: String(session?.durationMinutes ?? 60))
        _notes = State(initialValue: session?.notes ?? "")
        _rpe = State(initialValue: session?.rpe ?? 0)
        let drafts = session?.exercises.map { exercise in
            DraftExercise(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.sets.map { set in
                    DraftSet(id: set.id, reps: String(set.reps), weight: String(set.weight))
                }
            )
        } ?? []
        _exercises = State(initialValue: drafts.isEmpty ? [DraftExercise()] : drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(editingSession == nil ? "Séance libre" : "Modifier la séance") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Activité (musculation, marche…)", text: $activity)
                    TextField("Durée (minutes)", text: $duration).keyboardType(.numberPad)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4)
                    Picker("Effort perçu", selection: $rpe) {
                        Text("Non renseigné").tag(0)
                        ForEach(1...10, id: \.self) { Text("\($0)/10").tag($0) }
                    }
                }
                ForEach($exercises) { $exercise in
                    Section("Exercice") {
                        Menu {
                            if journal.exerciseNames.isEmpty {
                                Text("Aucun exercice enregistré")
                            } else {
                                ForEach(journal.exerciseNames, id: \.self) { name in
                                    Button(name) { exercise.name = name }
                                }
                            }
                        } label: {
                            Label(
                                exercise.name.isEmpty ? "Choisir un exercice habituel" : "Exercices habituels : \(exercise.name)",
                                systemImage: "chevron.down.circle"
                            )
                        }

                        TextField("Ou saisir un nouvel exercice", text: $exercise.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { journal.registerExerciseName(exercise.name) }

                        Button {
                            let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else {
                                error = "Indique le nom de l'exercice à ajouter."; return
                            }
                            journal.registerExerciseName(name)
                        } label: {
                            Label("Ajouter aux exercices habituels", systemImage: "bookmark.fill")
                        }
                        .disabled(exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        ForEach($exercise.sets) { $set in
                            HStack {
                                TextField("Répétitions", text: $set.reps).keyboardType(.numberPad)
                                TextField("Charge en kg", text: $set.weight).keyboardType(.decimalPad)
                            }
                        }
                        Button { exercise.sets.append(DraftSet()) } label: {
                            Label("Ajouter une série", systemImage: "plus")
                        }
                        if exercise.sets.count > 1 {
                            Button("Retirer la dernière série") { exercise.sets.removeLast() }
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Button { exercises.append(DraftExercise()) } label: {
                    Label("Ajouter un exercice", systemImage: "plus.circle")
                }
            }
            .navigationTitle(editingSession == nil ? "Nouvelle séance" : "Modifier la séance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.fontWeight(.bold)
                }
            }
            .alert("Vérifie la saisie", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func parseDouble(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        let minutes = Int(duration) ?? -1
        guard !activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (0...1440).contains(minutes) else {
            error = "Indique une activité et une durée de 0 à 1 440 minutes."
            return
        }
        var logged: [WorkoutExercise] = []
        for exercise in exercises {
            let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { continue }
            var sets: [WorkoutSet] = []
            for entry in exercise.sets {
                guard let reps = Int(entry.reps), reps > 0, reps <= 1000,
                      let weight = parseDouble(entry.weight.isEmpty ? "0" : entry.weight),
                      weight.isFinite, weight >= 0, weight <= 5000 else {
                    error = "Vérifie les répétitions et la charge de \(name)."
                    return
                }
                sets.append(WorkoutSet(id: entry.id, reps: reps, weight: weight))
            }
            logged.append(WorkoutExercise(id: exercise.id, name: name, sets: sets))
        }
        let session = WorkoutSession(
            id: editingSession?.id ?? UUID(),
            date: date, activity: activity, durationMinutes: minutes,
            notes: notes, rpe: rpe == 0 ? nil : rpe, exercises: logged
        )
        if editingSession == nil {
            journal.add(session)
        } else {
            journal.updateWorkout(session)
        }
        dismiss()
    }
}

struct NewMealScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var journal: BiluxStore
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = "0"
    @State private var carbs = "0"
    @State private var fats = "0"
    @State private var water = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Repas ajouté manuellement") {
                    TextField("Nom du repas", text: $name)
                    TextField("Calories (kcal)", text: $kcal).keyboardType(.decimalPad)
                    TextField("Protéines (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Glucides (g)", text: $carbs).keyboardType(.decimalPad)
                    TextField("Lipides (g)", text: $fats).keyboardType(.decimalPad)
                    TextField("Eau (ml, facultatif)", text: $water).keyboardType(.decimalPad)
                }
                Section { Text("Si tu suis déjà tes repas dans MyFitnessPal, évite de les saisir à nouveau ici. Bilux lit les calories et macros depuis Santé lorsqu'elles sont disponibles.").font(.caption) }
            }
            .navigationTitle("Nouveau repas")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() } }
            }
            .alert("Vérifie la saisie", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func value(_ text: String) -> Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }
    private func save() {
        guard !name.isEmpty, let c = value(kcal), let p = value(protein), let g = value(carbs), let f = value(fats), [c,p,g,f].allSatisfy({ $0.isFinite && $0 >= 0 && $0 < 100000 }) else {
            error = "Renseigne le nom et des valeurs positives valides."; return
        }
        journal.add(ManualMeal(name: name, kcal: c, protein: p, carbs: g, fats: f, waterML: value(water)))
        dismiss()
    }
}

struct NewCheckinScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var journal: BiluxStore
    @State private var energy = 5
    @State private var fatigue = 5
    @State private var sleep = ""
    @State private var weight = ""
    @State private var medication = "Non renseigné"
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Ressenti du jour") {
                    Stepper("Énergie : \(energy)/10", value: $energy, in: 1...10)
                    Stepper("Fatigue : \(fatigue)/10", value: $fatigue, in: 1...10)
                    TextField("Sommeil (heures, facultatif)", text: $sleep).keyboardType(.decimalPad)
                    TextField("Poids (kg, facultatif)", text: $weight).keyboardType(.decimalPad)
                    Picker("Prise du traitement (journal)", selection: $medication) {
                        ForEach(["Non renseigné", "Prise confirmée", "Prise incertaine", "Non prise"], id: \.self) { Text($0) }
                    }
                    TextField("Observations", text: $note, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle("Bilan personnel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { journal.add(Checkin(energy: energy, fatigue: fatigue, sleepHours: Double(sleep.replacingOccurrences(of: ",", with: ".")), note: note, weightKG: Double(weight.replacingOccurrences(of: ",", with: ".")), medicationNote: medication)); dismiss() } }
            }
        }
    }
}

struct NewLabScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var journal: BiluxStore
    @State private var date = Date()
    @State private var tsh = ""
    @State private var t4l = ""
    @State private var note = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Résultat médical à noter") {
                    DatePicker("Date du prélèvement", selection: $date, displayedComponents: .date)
                    TextField("TSH (indiquer l'unité dans les notes)", text: $tsh).keyboardType(.decimalPad)
                    TextField("T4L (indiquer l'unité dans les notes)", text: $t4l).keyboardType(.decimalPad)
                    TextField("Unités, laboratoire, observations", text: $note, axis: .vertical).lineLimit(2...4)
                }
                Section { Text("Ce journal ne détermine ni la signification clinique d'un résultat ni la dose de Levothyrox.").font(.caption) }
            }
            .navigationTitle("TSH / T4L")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() } }
            }
            .alert("Vérifie la saisie", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        }
    }
    private func parse(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
    private func save() {
        if (!tsh.isEmpty && parse(tsh) == nil) || (!t4l.isEmpty && parse(t4l) == nil) || (tsh.isEmpty && t4l.isEmpty) {
            error = "Renseigne au moins un résultat numérique valide."; return
        }
        journal.add(ThyroidLab(date: date, tsh: parse(tsh), t4l: parse(t4l), note: note))
        dismiss()
    }
}
