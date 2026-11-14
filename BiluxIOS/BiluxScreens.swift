import SwiftUI
import UniformTypeIdentifiers

// BILUX V5.1 — nouveau langage visuel, sans modification du modèle de données.
private enum Nuclear {
    static let background = Color(red: 0.025, green: 0.027, blue: 0.046)
    static let panel = Color(red: 0.085, green: 0.078, blue: 0.119)
    static let gold = Color(red: 1.0, green: 0.77, blue: 0.33)
    static let paleGold = Color(red: 1.0, green: 0.91, blue: 0.64)
    static let purple = Color(red: 0.69, green: 0.40, blue: 1.0)
    static let ink = Color(red: 0.94, green: 0.93, blue: 0.95)
    static let muted = Color(red: 0.64, green: 0.63, blue: 0.73)
}

struct MainTabs: View {
    @State private var selected: Int = 0

    var body: some View {
        TabView(selection: $selected) {
            HomeScreen(selectedTab: $selected)
                .tabItem { Label("Accueil", systemImage: "house.fill") }.tag(0)
            SportScreen()
                .tabItem { Label("Sport", systemImage: "dumbbell.fill") }.tag(1)
            NutritionScreen()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }.tag(2)
            HealthScreen()
                .tabItem { Label("Santé", systemImage: "heart.text.square.fill") }.tag(3)
            AscensionScreen()
                .tabItem { Label("Ascension", systemImage: "crown.fill") }.tag(4)
        }
        .tint(Nuclear.gold)
        .background(Nuclear.background)
    }
}

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                Nuclear.background
                LinearGradient(
                    colors: [Nuclear.purple.opacity(0.17), .clear, Nuclear.gold.opacity(0.07), Nuclear.background],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [Nuclear.purple.opacity(0.14), .clear],
                               center: .topTrailing, startRadius: 15, endRadius: 310)
            }.ignoresSafeArea()
        }
    }
}

struct NuclearCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red:0.14,green:0.12,blue:0.19), Nuclear.panel],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(LinearGradient(colors: [Nuclear.gold.opacity(0.39),
                                                    Nuclear.purple.opacity(0.20), Color.white.opacity(0.04)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
            .shadow(color: Nuclear.purple.opacity(0.07), radius: 15, y: 5)
    }
}

struct SectionCaption: View {
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Nuclear.gold).frame(width: 3, height: 15)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.8).foregroundStyle(Nuclear.paleGold)
            Spacer(minLength: 0)
        }.padding(.top, 7)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let icon: String
    var accent: Color = Nuclear.gold

    var body: some View {
        NuclearCard {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(accent)
                .frame(height: 25, alignment: .leading)
            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Nuclear.muted).lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NuclearModuleTile: View {
    let title: String
    let detail: String
    let symbol: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(height: 37)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption2.bold())
                }.foregroundStyle(.white)
                Text(detail).font(.caption2).foregroundStyle(Nuclear.muted)
                    .multilineTextAlignment(.leading).lineLimit(2)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.21), Nuclear.panel],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(accent.opacity(0.46), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct HomeScreen: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var journal: BiluxStore
    @EnvironmentObject private var health: HealthKitManager
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 19) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("BILUX").font(.system(size: 37, weight: .black, design: .rounded))
                                .tracking(2).foregroundStyle(.white)
                            Text("N U C L E A R   A S C E N S I O N")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(Nuclear.gold)
                        }
                        Spacer()
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Nuclear.gold)
                            .padding(12)
                            .background(Nuclear.gold.opacity(0.10), in: Circle())
                    }
                    heroPanel
                    SectionCaption(title: "Ton centre de commandement")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        NuclearModuleTile(title: "Sport", detail: "Séances & performances", symbol: "dumbbell.fill", accent: Nuclear.gold) { selectedTab = 1 }
                        NuclearModuleTile(title: "Nutrition", detail: "Carburant du réacteur", symbol: "fork.knife", accent: Color(red:0.45,green:0.89,blue:0.61)) { selectedTab = 2 }
                        NuclearModuleTile(title: "Santé", detail: "Sommeil & Apple Santé", symbol: "heart.text.square.fill", accent: Nuclear.purple) { selectedTab = 3 }
                        NuclearModuleTile(title: "Ascension", detail: "Niveaux & missions", symbol: "crown.fill", accent: Nuclear.paleGold) { selectedTab = 4 }
                    }
                    SectionCaption(title: "Tes statistiques du jour")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                        StatTile(label: "Pas", value: count(health.today.steps), icon: "figure.walk")
                        StatTile(label: "Dépense active", value: unit(health.today.activeKcal, "kcal"), icon: "flame.fill")
                        StatTile(label: "Nutrition", value: unit(health.today.consumedKcal ?? (journal.todaysMeals.isEmpty ? nil : journal.todaysCalories), "kcal"), icon: "fork.knife", accent: .green)
                        StatTile(label: "Sommeil", value: unit(health.today.sleepHours, "h", decimals: 1), icon: "moon.stars.fill", accent: Nuclear.purple)
                    }
                    healthButton
                    SectionCaption(title: "Quêtes du jour")
                    NuclearCard {
                        HStack {
                            Image(systemName: "flag.checkered.2.crossed").foregroundStyle(Nuclear.gold)
                            Text("JOURNAL D'ASCENSION").font(.caption.bold()).tracking(1)
                            Spacer()
                            Text("+ XP").font(.caption2.bold()).foregroundStyle(Nuclear.gold)
                        }
                        quest("Consigner une séance", done: journal.data.workouts.contains { BiluxFormat.sameDay($0.date, .now) }, xp: "25 XP")
                        quest("Suivre l'alimentation", done: !journal.todaysMeals.isEmpty || health.today.consumedKcal != nil, xp: "8 XP")
                        quest("Noter ton ressenti", done: journal.data.checkins.contains { BiluxFormat.sameDay($0.date, .now) }, xp: "8 XP")
                    }
                    SectionCaption(title: "Les cinq transformations")
                    HStack(spacing: 5) {
                        ForEach(Array(["SURVIVANT", "ÉVEIL", "RÉACTEUR", "NUCLÉAIRE", "ASCENSION"].enumerated()), id: \.offset) { index, title in
                            VStack(spacing: 7) {
                                Image(systemName: index <= formIndex ? "bolt.fill" : "lock.fill")
                                    .font(.caption).foregroundStyle(index <= formIndex ? Nuclear.gold : Nuclear.muted)
                                Text(title).font(.system(size: 7, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.5)
                                    .foregroundStyle(index <= formIndex ? .white : Nuclear.muted)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(index == formIndex ? Nuclear.gold.opacity(0.19) : Nuclear.panel,
                                        in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(index == formIndex ? Nuclear.gold : Nuclear.purple.opacity(0.20)))
                        }
                    }
                    Text("Tes XP récompensent le suivi personnel, pas tes résultats médicaux. Le repos n'entraîne aucun malus.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                        .padding(.bottom, 10)
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 22)
            }
            .toolbar(.hidden, for: .navigationBar)
            .modifier(PageBackground())
            .task { if health.hasRequested { await health.refresh() } }
            .onAppear { pulse = true }
            .alert("BILUX", isPresented: Binding(get: { health.message != nil }, set: { if !$0 { health.message = nil } })) {
                Button("OK") { health.message = nil }
            } message: { Text(health.message ?? "") }
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Image("BiluxHero")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            LinearGradient(colors: [.clear, Nuclear.background.opacity(0.53), Nuclear.background],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().stroke(Nuclear.gold.opacity(0.4), lineWidth: 2).frame(width: 70, height: 70)
                        Circle().stroke(Nuclear.gold.opacity(0.65), lineWidth: 1)
                            .frame(width: 62, height: 62)
                            .scaleEffect(pulse ? 1.04 : 0.93)
                            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: pulse)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 27)).foregroundStyle(Nuclear.paleGold)
                    }
                    Spacer()
                    Text("RANG · \(journal.rankName.uppercased())")
                        .font(.caption2.bold()).tracking(0.7).foregroundStyle(Nuclear.paleGold)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Nuclear.background.opacity(0.77), in: Capsule())
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("NIVEAU").font(.caption.bold()).tracking(1.5).foregroundStyle(Nuclear.paleGold)
                    Text("\(journal.heroLevel)")
                        .font(.system(size: 39, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                ProgressView(value: journal.xpFraction).tint(Nuclear.gold)
                HStack {
                    Text("\(journal.totalXP) XP").font(.caption.bold()).foregroundStyle(Nuclear.paleGold)
                    Spacer()
                    Text("\(100 - journal.totalXP % 100) XP avant le prochain niveau")
                        .font(.caption2).foregroundStyle(.white.opacity(0.8))
                }
            }.padding(18)
        }
        .frame(height: 275)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(LinearGradient(colors: [Nuclear.paleGold, Nuclear.purple.opacity(0.7), Nuclear.gold.opacity(0.4)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4))
        .shadow(color: Nuclear.gold.opacity(0.17), radius: 18, y: 6)
    }

    @ViewBuilder private var healthButton: some View {
        if !health.hasRequested {
            Button { Task { await health.connect() } } label: {
                Label("CONNECTER APPLE SANTÉ", systemImage: "heart.fill").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Nuclear.gold)
        } else {
            Button { Task { await health.refresh() } } label: {
                Label(health.loading ? "Synchronisation…" : "Actualiser Apple Santé", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }.disabled(health.loading).buttonStyle(.bordered).tint(Nuclear.gold)
        }
    }

    private var formIndex: Int {
        switch journal.heroLevel { case 15...: return 4; case 10...: return 3; case 6...: return 2; case 3...: return 1; default: return 0 }
    }
    private func quest(_ label: String, done: Bool, xp: String) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Nuclear.gold)
            Text(label).font(.subheadline)
            Spacer(minLength: 8)
            Text(done ? "TERMINÉ" : "+\(xp)")
                .font(.caption2.bold()).foregroundStyle(done ? .green : Nuclear.gold)
        }.padding(.vertical, 3)
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
    @State private var editingWorkout: WorkoutSession?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Nuclear.gold.opacity(0.28), Nuclear.purple.opacity(0.20), Nuclear.panel],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("LA FORGE").font(.system(size: 27, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Chaque séance forge ton ascension")
                                    .font(.caption).foregroundStyle(Nuclear.paleGold)
                                Text("Tes exercices et séances restent modifiables")
                                    .font(.caption2).foregroundStyle(Nuclear.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 39, weight: .semibold))
                                .foregroundStyle(Nuclear.gold)
                        }.padding(18)
                    }
                    .frame(height: 115)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Nuclear.gold.opacity(0.48)))
                    SectionCaption(title: "Journal de combat")
                    HStack {
                        StatTile(label: "Séances", value: "\(journal.data.workouts.count)", icon: "dumbbell.fill")
                        StatTile(label: "Volume total", value: unit(journal.data.workouts.reduce(0) { $0 + $1.volume }, "kg·rép"), icon: "chart.line.uptrend.xyaxis")
                    }
                    Button { showNew = true } label: { Label("CRÉER UNE SÉANCE", systemImage: "plus.circle.fill").frame(maxWidth: .infinity) }
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
                            HStack(spacing: 16) {
                                Button { editingWorkout = workout } label: {
                                    Label("Modifier", systemImage: "pencil").font(.caption)
                                }
                                .tint(Nuclear.gold)
                                Button(role: .destructive) { journal.removeWorkout(workout.id) } label: {
                                    Label("Supprimer", systemImage: "trash").font(.caption)
                                }
                            }
                        }
                    }
                }.padding(16)
            }
            .navigationTitle("Entraînement").modifier(PageBackground())
            .sheet(isPresented: $showNew) { NewWorkoutScreen() }
            .sheet(item: $editingWorkout) { workout in NewWorkoutScreen(session: workout) }
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
                   
GeometryReader { geometry in
    Image("BiluxHero")
        .resizable()
        .scaledToFill()
        .frame(
            width: geometry.size.width,
            height: geometry.size.height
        )
        .clipped()
}
.frame(height: 250)
.clipShape(RoundedRectangle(cornerRadius: 15))
                    SectionCaption(title: "Ton ascension")
                    NuclearCard {
                        HStack(spacing: 17) {
                            ZStack {
                                Circle().stroke(Nuclear.purple.opacity(0.20), lineWidth: 8)
                                Circle().trim(from: 0, to: journal.xpFraction)
                                    .stroke(Nuclear.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                VStack(spacing: 3) {
                                    Image(systemName: "crown.fill").foregroundStyle(Nuclear.gold)
                                    Text("\(Int(journal.xpFraction * 100))%")
                                        .font(.title3.bold()).foregroundStyle(.white)
                                }
                            }.frame(width: 94, height: 94)
                            VStack(alignment: .leading, spacing: 7) {
                                Text("RANG \(journal.rankName.uppercased())")
                                    .font(.caption.bold()).tracking(1).foregroundStyle(Nuclear.gold)
                                Text("NIVEAU \(journal.heroLevel)")
                                    .font(.title2.bold()).foregroundStyle(.white)
                                Text("\(journal.totalXP) XP total")
                                    .font(.caption).foregroundStyle(Nuclear.muted)
                            }
                        }
                        Text("+25 XP par séance, +8 XP par jour de repas saisis et +8 XP par jour de bilan. Aucun malus de repos.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
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
            .navigationTitle("Ascension").modifier(PageBackground())
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
