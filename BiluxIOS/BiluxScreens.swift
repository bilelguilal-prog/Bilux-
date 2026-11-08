import SwiftUI
import UniformTypeIdentifiers

private enum Nuclear {
    static let background = Color(red: 0.055, green: 0.043, blue: 0.07)
    static let panel = Color(red: 0.115, green: 0.085, blue: 0.12)
    static let gold = Color(red: 1, green: 0.72, blue: 0.24)
    static let purple = Color(red: 0.65, green: 0.4, blue: 1)
    static let ink = Color(red: 0.95, green: 0.88, blue: 0.77)
}

struct MainTabs: View {
    @State private var selected: Int = 0
    var body: some View {
        TabView(selection: $selected) {
            HomeScreen().tabItem { Label("QG", systemImage: "house.fill") }.tag(0)
            SportScreen().tabItem { Label("Sport", systemImage: "dumbbell.fill") }.tag(1)
            NutritionScreen().tabItem { Label("Nutrition", systemImage: "fork.knife") }.tag(2)
            HealthScreen().tabItem { Label("Santé", systemImage: "heart.text.square.fill") }.tag(3)
            AscensionScreen().tabItem { Label("Avatar", systemImage: "bolt.shield.fill") }.tag(4)
        }
        .tint(Nuclear.gold)
        .background(Nuclear.background)
    }
}

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(colors: [Nuclear.background, Color(red:0.14,green:0.07,blue:0.17), Nuclear.background], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
    }
}

struct NuclearCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Nuclear.panel.opacity(0.91), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Nuclear.gold.opacity(0.40), lineWidth: 0.8))
    }
}

struct SectionCaption: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.heavy)).tracking(2).foregroundStyle(Nuclear.gold)
            .padding(.top, 5)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let icon: String
    var accent: Color = Nuclear.gold
    var body: some View {
        NuclearCard {
            Label(label.uppercased(), systemImage: icon)
                .font(.caption2.weight(.bold)).foregroundStyle(accent)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(value).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var journal: BiluxStore
    @EnvironmentObject private var health: HealthKitManager
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("BILUX").font(.system(size: 39, weight: .black, design: .serif)).tracking(4).foregroundStyle(.white)
                            Text("NUCLEAR ASCENSION").font(.system(size: 20, weight: .black, design: .serif)).tracking(2)
                                .foregroundStyle(Nuclear.gold)
                        }.padding(.top, 14)
                        Image("BiluxHero")
                            .resizable().scaledToFill().frame(height: 270).clipped()
                            .overlay(alignment: .bottom) {
                                LinearGradient(colors: [.clear, Nuclear.background], startPoint: .center, endPoint: .bottom)
                            }
                        HStack(spacing: 14) {
                            VStack { Text("NIV.").font(.caption2); Text("\(journal.heroLevel)").font(.system(size: 35, weight: .black, design: .rounded)) }
                                .foregroundStyle(Nuclear.gold)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("RANG · \(journal.rankName.uppercased())").font(.headline).foregroundStyle(Nuclear.ink)
                                ProgressView(value: journal.xpFraction).tint(Nuclear.gold)
                                Text("\(journal.totalXP) XP • \(100 - journal.totalXP % 100) avant le prochain niveau")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(12)
                    }
                    .background(Nuclear.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Nuclear.gold.opacity(0.8), lineWidth: 1))
                    SectionCaption(title: "Système de transformation")
                    HStack(spacing: 5) {
                        ForEach(Array(["SURVIVANT", "ÉVEIL", "RÉACTEUR", "NUCLÉAIRE", "ASCENSION"].enumerated()), id: \.offset) { index, title in
                            VStack(spacing: 6) {
                                Image(systemName: index <= formIndex ? "bolt.fill" : "lock.fill")
                                    .foregroundStyle(index <= formIndex ? Nuclear.gold : .gray)
                                Text(title).font(.system(size: 7, weight: .heavy)).minimumScaleFactor(0.6).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(index == formIndex ? Nuclear.gold.opacity(0.2) : Nuclear.panel, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(index == formIndex ? Nuclear.gold : .gray.opacity(0.2)))
                        }
                    }
                    SectionCaption(title: "Aujourd'hui · données réelles")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        StatTile(label: "Pas", value: count(health.today.steps), icon: "figure.walk")
                        StatTile(label: "Dépense active", value: unit(health.today.activeKcal, "kcal"), icon: "flame.fill")
                        StatTile(label: "Nutrition", value: unit(health.today.consumedKcal ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysCalories), "kcal"), icon: "fork.knife")
                        StatTile(label: "Sommeil", value: unit(health.today.sleepHours, "h", decimals: 1), icon: "moon.stars.fill", accent: Nuclear.purple)
                    }
                    if !health.hasRequested {
                        Button { Task { await health.connect() } } label: {
                            Label("CONNECTER APPLE SANTÉ", systemImage: "heart.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    } else {
                        Button { Task { await health.refresh() } } label: {
                            Label(health.loading ? "Synchronisation…" : "Actualiser les données Santé", systemImage: "arrow.clockwise")
                        }.disabled(health.loading).tint(Nuclear.gold)
                    }
                    SectionCaption(title: "Missions du jour")
                    NuclearCard {
                        quest("Consigner une séance", done: journal.data.workouts.contains { BiluxFormat.sameDay($0.date, .now) }, xp: "25 XP")
                        quest("Suivre l'alimentation", done: !journal.todaysMeals.isEmpty || health.today.consumedKcal != nil, xp: "8 XP")
                        quest("Noter ton ressenti", done: journal.data.checkins.contains { BiluxFormat.sameDay($0.date, .now) }, xp: "8 XP")
                    }
                    Text("L'XP récompense le suivi. Aucun malus pour le repos. Les données médicales ne déterminent jamais un score de santé.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
            }
            .navigationTitle("Centre de commandement").navigationBarTitleDisplayMode(.inline)
            .modifier(PageBackground())
            .task { if health.hasRequested { await health.refresh() } }
            .alert("BILUX", isPresented: Binding(get: { health.message != nil }, set: { if !$0 { health.message = nil } })) {
                Button("OK") { health.message = nil }
            } message: { Text(health.message ?? "") }
        }
    }
    private var formIndex: Int {
        switch journal.heroLevel { case 15...: return 4; case 10...: return 3; case 6...: return 2; case 3...: return 1; default: return 0 }
    }
    private func quest(_ label: String, done: Bool, xp: String) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.square.fill" : "square").foregroundStyle(Nuclear.gold)
            Text(label).font(.subheadline)
            Spacer(minLength: 8)
            Text(done ? "✓" : "+\(xp)").font(.caption.bold()).foregroundStyle(Nuclear.gold)
        }
    }
}

private func count(_ x: Double?) -> String { x.map { BiluxFormat.number($0) } ?? "—" }
private func unit(_ x: Double?, _ suffix: String, decimals: Int = 0) -> String {
    guard let x else { return "—" }
    return "\(BiluxFormat.number(x, digits: decimals)) \(suffix)"
}

struct SportScreen: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var showNew = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    SectionCaption(title: "Journal de combat")
                    HStack {
                        StatTile(label: "Séances", value: "\(journal.data.workouts.count)", icon: "dumbbell.fill")
                        StatTile(label: "Volume total", value: unit(journal.data.workouts.reduce(0) { $0 + $1.volume }, "kg·rép"), icon: "chart.line.uptrend.xyaxis")
                    }
                    Button { showNew = true } label: { Label("NOUVELLE SÉANCE LIBRE", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    SectionCaption(title: "Historique")
                    if journal.data.workouts.isEmpty { NuclearCard { Text("Aucune séance. Enregistre ton premier entraînement libre.").foregroundStyle(.secondary) } }
                    ForEach(journal.data.workouts.sorted(by: { $0.date > $1.date })) { workout in
                        NuclearCard {
                            HStack {
                                Text(workout.activity).font(.headline)
                                Spacer()
                                Text(BiluxFormat.day(workout.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(workout.durationMinutes) min · \(workout.exercises.count) exercices · \(unit(workout.volume, "kg·rép"))")
                                .font(.caption).foregroundStyle(Nuclear.gold)
                            ForEach(workout.exercises) { exercise in
                                Text("• \(exercise.name) : \(exercise.sets.map { "\($0.reps)×\(BiluxFormat.number($0.weight, digits: 1))kg" }.joined(separator: " / "))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let rpe = workout.rpe { Text("Effort perçu : \(rpe)/10").font(.caption) }
                            if !workout.notes.isEmpty { Text(workout.notes).font(.caption) }
                            Button(role: .destructive) { journal.removeWorkout(workout.id) } label: {
                                Label("Supprimer", systemImage: "trash").font(.caption)
                            }
                        }
                    }
                }.padding(16)
            }
            .navigationTitle("Entraînement").modifier(PageBackground())
            .sheet(isPresented: $showNew) { NewWorkoutScreen() }
        }
    }
}

struct NutritionScreen: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var journal: BiluxStore
    @State private var showNew = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionCaption(title: "Carburant du réacteur")
                    NuclearCard {
                        HStack { Text("CONSOMMÉ AUJOURD'HUI").font(.caption.bold()).foregroundStyle(Nuclear.gold); Spacer(); Image(systemName: "fork.knife") }
                        Text(unit(health.today.consumedKcal ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysCalories), "kcal"))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                        Text(health.today.consumedKcal != nil ? health.today.nutritionSource : "Repas saisis dans Bilux")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
                        StatTile(label: "Protéines", value: unit(health.today.protein ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysMeals.reduce(0) { $0 + $1.protein }), "g", decimals: 1), icon: "p.circle")
                        StatTile(label: "Glucides", value: unit(health.today.carbs ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysMeals.reduce(0) { $0 + $1.carbs }), "g", decimals: 1), icon: "bolt")
                        StatTile(label: "Lipides", value: unit(health.today.fats ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysMeals.reduce(0) { $0 + $1.fats }), "g", decimals: 1), icon: "drop", accent: Nuclear.purple)
                        StatTile(label: "Poids", value: unit(health.today.weightKG, "kg", decimals: 1), icon: "scalemass")
                    }
                    NuclearCard {
                        Text("Synchronisation MyFitnessPal").font(.headline)
                        Text("Dans MyFitnessPal : Profil ou Plus → Réglages → Partage et confidentialité → Partage HealthKit. Autorise les nutriments à être envoyés à Apple Santé. Puis accorde l'accès à Bilux.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Les chiffres Santé et les repas ajoutés dans Bilux ne sont pas additionnés : cela évite de compter deux fois une même alimentation.")
                            .font(.caption).foregroundStyle(Nuclear.gold)
                    }
                    Button { showNew = true } label: { Label("AJOUTER UN REPAS DANS BILUX", systemImage: "plus.circle").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    SectionCaption(title: "Repas saisis dans Bilux")
                    ForEach(journal.data.meals.sorted(by: { $0.date > $1.date })) { meal in
                        NuclearCard {
                            HStack { Text(meal.name); Spacer(); Text("\(count(meal.kcal)) kcal").foregroundStyle(Nuclear.gold) }
                            Text(BiluxFormat.day(meal.date)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(16)
            }
            .navigationTitle("Nutrition").modifier(PageBackground())
            .sheet(isPresented: $showNew) { NewMealScreen() }
        }
    }
}

struct HealthScreen: View {
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var journal: BiluxStore
    @State private var showCheckin = false
    @State private var showLab = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SectionCaption(title: "Observations Santé / Apple Watch")
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 9) {
                        StatTile(label: "Fréquence cardiaque", value: unit(health.today.heartRateBPM, "bpm"), icon: "heart.fill", accent: .red)
                        StatTile(label: "Sommeil récent", value: unit(health.today.sleepHours, "h", decimals: 1), icon: "moon.stars", accent: Nuclear.purple)
                        StatTile(label: "Poids", value: unit(health.today.weightKG, "kg", decimals: 1), icon: "scalemass")
                        StatTile(label: "Activités Santé", value: unit(health.today.workoutMinutes, "min"), icon: "figure.run")
                    }
                    Button { Task { await health.connect() } } label: {
                        Label("GÉRER L'ACCÈS APPLE SANTÉ", systemImage: "heart.text.square")
                    }.buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    SectionCaption(title: "Journal post-thyroïdectomie")
                    NuclearCard {
                        Text("Consigne ton énergie, la fatigue, le sommeil et tes résultats TSH/T4L. Les valeurs restent des observations personnelles et ne servent pas à adapter ton traitement.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { showCheckin = true } label: { Label("AJOUTER UN BILAN", systemImage: "plus") }.tint(Nuclear.gold)
                        Button { showLab = true } label: { Label("NOTER UN RÉSULTAT TSH / T4L", systemImage: "cross.vial") }.tint(Nuclear.gold)
                    }
                    ForEach(journal.data.checkins.sorted(by: { $0.date > $1.date })) { item in
                        NuclearCard {
                            Text("\(BiluxFormat.day(item.date)) · Énergie \(item.energy)/10 · Fatigue \(item.fatigue)/10")
                            if let weight = item.weightKG { Text("Poids noté : \(BiluxFormat.number(weight, digits: 1)) kg").font(.caption).foregroundStyle(.secondary) }
                            if let treatment = item.medicationNote { Text("Traitement : \(treatment)").font(.caption).foregroundStyle(.secondary) }
                            if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    ForEach(journal.data.labs.sorted(by: { $0.date > $1.date })) { lab in
                        NuclearCard {
                            Text(BiluxFormat.day(lab.date)).font(.caption).foregroundStyle(.secondary)
                            Text("TSH : \(lab.tsh.map { BiluxFormat.number($0, digits: 2) } ?? "—") · T4L : \(lab.t4l.map { BiluxFormat.number($0, digits: 2) } ?? "—")")
                            if !lab.note.isEmpty { Text(lab.note).font(.caption) }
                        }
                    }
                    Text("Ce journal ne pose aucun diagnostic et ne détermine pas les doses de Levothyrox.").font(.caption).foregroundStyle(.secondary)
                }.padding(16)
            }
            .navigationTitle("Santé").modifier(PageBackground())
            .sheet(isPresented: $showCheckin) { NewCheckinScreen() }
            .sheet(isPresented: $showLab) { NewLabScreen() }
        }
    }
}

struct AscensionScreen: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var showingImporter = false
    @State private var exportFile: URL?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Image("BiluxHero").resizable().scaledToFill().frame(height: 250).clipped().clipShape(RoundedRectangle(cornerRadius: 15))
                    SectionCaption(title: "Ascension du héros")
                    NuclearCard {
                        Text("RANG \(journal.rankName.uppercased())").font(.title2.bold()).foregroundStyle(Nuclear.gold)
                        Text("Niveau \(journal.heroLevel) • \(journal.totalXP) XP")
                        ProgressView(value: journal.xpFraction).tint(Nuclear.gold)
                        Text("+25 XP par séance, +8 XP par jour avec repas Bilux, +8 XP par jour avec bilan Bilux. Le repos n'enlève aucun point.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    SectionCaption(title: "Continuité depuis la V3 web")
                    NuclearCard {
                        Text("Transférer l'historique V3").font(.headline)
                        Text("Depuis Bilux V3 dans Safari, va dans Avatar → Exporter JSON. Enregistre le fichier dans Fichiers. Puis importe-le ici.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { showingImporter = true } label: { Label("IMPORTER UNE SAUVEGARDE V3", systemImage: "square.and.arrow.down") }
                            .tint(Nuclear.gold)
                        Button {
                            exportFile = journal.exportJSON()
                        } label: { Label("PRÉPARER LA SAUVEGARDE V4", systemImage: "square.and.arrow.up") }
                            .tint(Nuclear.gold)
                        if let exportFile {
                            ShareLink(item: exportFile) { Label("PARTAGER LE FICHIER JSON", systemImage: "square.and.arrow.up.on.square") }.tint(Nuclear.gold)
                        }
                        Text("La sauvegarde contient des données personnelles et médicales. Conserve-la dans un emplacement protégé.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    SectionCaption(title: "Confidentialité")
                    Text("La version de développement ne transmet aucune donnée à un serveur. Les entrées manuelles restent dans l'espace de stockage privé de l'application iPhone. Les données Santé sont lues avec les permissions d'iOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
            }
            .navigationTitle("Avatar").modifier(PageBackground())
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url): journal.importJSON(url)
                case .failure(let error): journal.feedback = error.localizedDescription
                }
            }
            .alert("BILUX", isPresented: Binding(get: { journal.feedback != nil }, set: { if !$0 { journal.feedback = nil } })) {
                Button("OK") { journal.feedback = nil }
            } message: { Text(journal.feedback ?? "") }
        }
    }
}
