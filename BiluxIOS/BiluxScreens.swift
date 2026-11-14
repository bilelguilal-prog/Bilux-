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

// V5.2 : presentation des transformations, derivee des XP existants.
// Aucune donnee supplementaire n'est ecrite dans la sauvegarde JSON.
private struct NuclearStage: Identifiable {
    let id: Int
    let name: String
    let minLevel: Int
    let subtitle: String
    let symbol: String
    let accent: Color

    static let all: [NuclearStage] = [
        .init(id: 0, name: "SURVIVANT", minLevel: 1, subtitle: "Le premier souffle", symbol: "shield.fill", accent: .gray),
        .init(id: 1, name: "ÉVEIL", minLevel: 3, subtitle: "L'étincelle intérieure", symbol: "sparkles", accent: Nuclear.gold),
        .init(id: 2, name: "RÉACTEUR", minLevel: 6, subtitle: "Le coeur s'embrase", symbol: "bolt.fill", accent: .orange),
        .init(id: 3, name: "NUCLÉAIRE", minLevel: 10, subtitle: "Le pouvoir rayonne", symbol: "atom", accent: Nuclear.purple),
        .init(id: 4, name: "ASCENSION", minLevel: 15, subtitle: "Au-delà des limites", symbol: "crown.fill", accent: Nuclear.paleGold)
    ]

    var artwork: String {
        switch id {
        case 0: return "BiluxFormSurvivant"
        case 1: return "BiluxHero" // Illustration V5.1 originale, conservee intacte.
        case 2: return "BiluxFormReacteur"
        case 3: return "BiluxFormNucleaire"
        default: return "BiluxFormAscension"
        }
    }

    static func current(level: Int) -> NuclearStage {
        all.last(where: { level >= $0.minLevel }) ?? all[0]
    }
}

private struct NuclearAward: Identifiable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let achieved: Bool
}

private enum NuclearProgress {
    static func awards(_ data: BiluxData, level: Int) -> [NuclearAward] {
        let allExercises = data.workouts.flatMap(\.exercises)
        let names = Set(allExercises.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }.filter { !$0.isEmpty })
        return [
            .init(id: "first", name: "PREMIER COMBAT", detail: "Enregistrer une séance", icon: "bolt.shield.fill", achieved: !data.workouts.isEmpty),
            .init(id: "five", name: "FORGERON", detail: "5 séances consignées", icon: "dumbbell.fill", achieved: data.workouts.count >= 5),
            .init(id: "ten", name: "INARRÊTABLE", detail: "10 séances consignées", icon: "flame.fill", achieved: data.workouts.count >= 10),
            .init(id: "explorer", name: "EXPLORATEUR", detail: "5 exercices différents", icon: "figure.strengthtraining.traditional", achieved: names.count >= 5),
            .init(id: "journal", name: "JOURNAL VIVANT", detail: "5 jours de suivi consignés", icon: "book.closed.fill", achieved: recordedDays(data) >= 5),
            .init(id: "ascend", name: "RÉVEIL DU RÉACTEUR", detail: "Atteindre le niveau 6", icon: "atom", achieved: level >= 6)
        ]
    }

    static func recordedDays(_ data: BiluxData) -> Int {
        let dates = data.workouts.map(\.date) + data.meals.map(\.date) + data.checkins.map(\.date)
        return Set(dates.map { Calendar.current.startOfDay(for: $0) }).count
    }

    static func uniqueExercises(_ data: BiluxData) -> Int {
        Set(data.workouts.flatMap(\.exercises).map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }.filter { !$0.isEmpty }).count
    }

    static func numberOfSets(_ data: BiluxData) -> Int {
        data.workouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } }
    }

    static func recordLoad(_ data: BiluxData) -> (name: String, weight: Double)? {
        data.workouts.flatMap(\.exercises)
            .flatMap { exercise in exercise.sets.map { (name: exercise.name, weight: $0.weight) } }
            .filter { $0.weight > 0 }
            .max(by: { $0.weight < $1.weight })
    }

    static func recordRepetitions(_ data: BiluxData) -> (name: String, reps: Int)? {
        data.workouts.flatMap(\.exercises)
            .flatMap { exercise in exercise.sets.map { (name: exercise.name, reps: $0.reps) } }
            .filter { $0.reps > 0 }
            .max(by: { $0.reps < $1.reps })
    }

    static func weeklyVolumes(_ data: BiluxData) -> [Double] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now) else { return Array(repeating: 0, count: 6) }
        return (0..<6).map { index in
            let offset = index - 5
            guard let start = calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek.start),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return 0 }
            return data.workouts.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.volume }
        }
    }
}

// V5.3: vrais portraits par palier, sans effet sur les XP ni les donnees de sante.
private struct NuclearHeroAura: View {
    let level: Int
    let effectsEnabled: Bool
    let stageOverride: NuclearStage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var energized = false

    init(level: Int, effectsEnabled: Bool, stageOverride: NuclearStage? = nil) {
        self.level = level
        self.effectsEnabled = effectsEnabled
        self.stageOverride = stageOverride
    }

    private var stage: NuclearStage { stageOverride ?? NuclearStage.current(level: level) }
    private var lockedPreview: Bool { stageOverride != nil && stage.minLevel > level }
    private var animate: Bool { effectsEnabled && !reduceMotion && !lockedPreview }

    var body: some View {
        GeometryReader { container in
            ZStack {
                Image(stage.artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: container.size.width, height: container.size.height)
                    .saturation(lockedPreview ? 0.17 : 1)
                    .overlay {
                        LinearGradient(colors: [stage.accent.opacity(0.02), Nuclear.purple.opacity(0.08 + Double(stage.id) * 0.02), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                        .blendMode(.screen)
                    }
                    .clipped()
                RadialGradient(colors: [stage.accent.opacity(animate ? 0.26 : 0.12), .clear],
                               center: .center, startRadius: 20, endRadius: 260)
                    .blendMode(.screen)
                    .scaleEffect(energized && animate ? 1.15 : 0.92)
                Circle().trim(from: 0.03, to: 0.79)
                    .stroke(AngularGradient(colors: [.clear, stage.accent.opacity(0.86), Nuclear.purple, .clear], center: .center),
                            style: StrokeStyle(lineWidth: stage.id >= 3 ? 3.2 : 2.1, lineCap: .round))
                    .frame(width: min(container.size.width * 0.64, 235), height: min(container.size.width * 0.64, 235))
                    .rotationEffect(.degrees(energized && animate ? 24 : -12))
                    .opacity(lockedPreview ? 0.32 : 0.75)
                    .blendMode(.screen)
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: lockedPreview ? "lock.fill" : stage.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(stage.accent)
                            .padding(10)
                            .background(.black.opacity(0.68), in: Circle())
                        Spacer()
                        Text(lockedPreview ? "APERÇU · NIV. \(stage.minLevel)" : "RANG " + stage.name)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(stage.accent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.black.opacity(0.72), in: Capsule())
                    }
                    Spacer()
                }.padding(12)
            }
            .frame(width: container.size.width, height: container.size.height)
            .clipped()
        }
        .onAppear { energized = true }
        .animation(animate ? .easeInOut(duration: 3).repeatForever(autoreverses: true) : .none, value: energized)
        .accessibilityLabel("Avatar BILUX : " + stage.name + (lockedPreview ? ", verrouille" : ", debloque"))
    }
}

private struct NuclearSkillRow: View {
    let title: String
    let subtitle: String
    let value: Int
    let goal: Int
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(Nuclear.gold)
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                Spacer()
                Text("\(min(value, goal))/\(goal)").font(.caption.monospacedDigit()).foregroundStyle(Nuclear.paleGold)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Nuclear.purple.opacity(0.24))
                    Capsule().fill(LinearGradient(colors: [Nuclear.purple, Nuclear.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geometry.size.width * CGFloat(min(value, goal)) / CGFloat(max(goal, 1))))
                }
            }.frame(height: 7)
            Text(subtitle).font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }
}

// Chaque noeud est un jalon calcule depuis les vraies saisies. Aucun point n'est debite.
private struct NuclearMasteryNode: Identifiable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let threshold: Int
    let progress: Int
    var unlocked: Bool { progress >= threshold }
}

private struct NuclearMasteryPath: Identifiable {
    let id: String
    let icon: String
    let accent: Color
    let nodes: [NuclearMasteryNode]
}

private struct NuclearMasteryTree: View {
    let data: BiluxData
    @State private var selectedNode: NuclearMasteryNode?

    private var paths: [NuclearMasteryPath] {
        let sessions = data.workouts.count
        let sets = NuclearProgress.numberOfSets(data)
        let exercises = NuclearProgress.uniqueExercises(data)
        let days = NuclearProgress.recordedDays(data)
        return [
            .init(id: "DISCIPLINE", icon: "dumbbell.fill", accent: Nuclear.gold, nodes: [
                .init(id: "d1", name: "Premier pas", detail: "Enregistrer une premiere seance.", icon: "figure.walk", threshold: 1, progress: sessions),
                .init(id: "d2", name: "Forge", detail: "Atteindre 5 seances consignees.", icon: "dumbbell.fill", threshold: 5, progress: sessions),
                .init(id: "d3", name: "Tenacite", detail: "Atteindre 10 seances, sans exigence de regularite quotidienne.", icon: "shield.fill", threshold: 10, progress: sessions)
            ]),
            .init(id: "PUISSANCE", icon: "bolt.fill", accent: .orange, nodes: [
                .init(id: "p1", name: "Etincelle", detail: "Enregistrer 10 series.", icon: "bolt.fill", threshold: 10, progress: sets),
                .init(id: "p2", name: "Charge", detail: "Enregistrer 50 series, avec ou sans poids.", icon: "flame.fill", threshold: 50, progress: sets),
                .init(id: "p3", name: "Reveil", detail: "Enregistrer 100 series.", icon: "atom", threshold: 100, progress: sets)
            ]),
            .init(id: "EXPLORATION", icon: "safari.fill", accent: .cyan, nodes: [
                .init(id: "e1", name: "Curieux", detail: "Essayer 2 exercices differents.", icon: "sparkles", threshold: 2, progress: exercises),
                .init(id: "e2", name: "Eclaireur", detail: "Essayer 5 exercices differents.", icon: "safari.fill", threshold: 5, progress: exercises),
                .init(id: "e3", name: "Voyageur", detail: "Essayer 20 exercices differents.", icon: "globe.europe.africa.fill", threshold: 20, progress: exercises)
            ]),
            .init(id: "CHRONIQUES", icon: "book.closed.fill", accent: Nuclear.purple, nodes: [
                .init(id: "c1", name: "Memoire", detail: "Consigner 2 jours de suivi.", icon: "book.fill", threshold: 2, progress: days),
                .init(id: "c2", name: "Journal", detail: "Consigner 5 jours de suivi.", icon: "calendar", threshold: 5, progress: days),
                .init(id: "c3", name: "Chroniqueur", detail: "Consigner 14 jours, non consecutifs.", icon: "checkmark.seal.fill", threshold: 14, progress: days)
            ])
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            ForEach(paths) { path in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: path.icon).foregroundStyle(path.accent)
                        Text(path.id).font(.caption.bold()).tracking(1).foregroundStyle(.white)
                        Spacer()
                        Text("\(path.nodes.filter(\.unlocked).count)/3")
                            .font(.caption.monospacedDigit()).foregroundStyle(Nuclear.paleGold)
                    }
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(0..<path.nodes.count, id: \.self) { index in
                            let node = path.nodes[index]
                            Button { selectedNode = node } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: node.unlocked ? node.icon : "lock.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(height: 25)
                                        .foregroundStyle(node.unlocked ? path.accent : Nuclear.muted)
                                    Text(node.name).font(.system(size: 9, weight: .bold))
                                        .lineLimit(1).minimumScaleFactor(0.65)
                                        .foregroundStyle(node.unlocked ? .white : Nuclear.muted)
                                    Text("\(min(node.progress, node.threshold))/\(node.threshold)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Nuclear.muted)
                                }
                                .frame(maxWidth: .infinity).frame(height: 84)
                                .background(node.unlocked ? path.accent.opacity(0.16) : Nuclear.background.opacity(0.62),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(node.unlocked ? path.accent.opacity(0.8) : Nuclear.muted.opacity(0.30), lineWidth: 1))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(node.name) : \(node.unlocked ? "debloque" : "verrouille") ; \(node.progress) sur \(node.threshold)")
                            if index < path.nodes.count - 1 {
                                Rectangle().fill(path.nodes[index + 1].unlocked ? path.accent : Nuclear.muted.opacity(0.25))
                                    .frame(width: 12, height: 2)
                            }
                        }
                    }
                }
            }
            Text("Touchez un noeud pour ses conditions. Ces recompenses sont symboliques : aucun bonus de force ou de sante n'est cree.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
        .sheet(item: $selectedNode) { node in
            NavigationStack {
                ZStack {
                    Nuclear.background.ignoresSafeArea()
                    VStack(spacing: 17) {
                        Image(systemName: node.unlocked ? node.icon : "lock.fill")
                            .font(.system(size: 58)).foregroundStyle(Nuclear.gold)
                            .padding(20)
                            .background(Nuclear.panel, in: Circle())
                        Text(node.name.uppercased()).font(.title2.bold()).foregroundStyle(.white)
                        Text(node.detail).multilineTextAlignment(.center).foregroundStyle(Nuclear.muted)
                        Text("\(min(node.progress, node.threshold)) / \(node.threshold)")
                            .font(.title3.monospacedDigit().bold()).foregroundStyle(Nuclear.gold)
                        Text(node.unlocked ? "TROPHEE DE MAITRISE ACQUIS" : "NOEUD A DEBLOQUER")
                            .font(.caption.bold()).foregroundStyle(.white)
                        Spacer()
                    }.padding(24).padding(.top, 24)
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { selectedNode = nil } } }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct NuclearLevelUp: View {
    let level: Int
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var stage: NuclearStage { NuclearStage.current(level: level) }
    private var newForm: Bool { stage.minLevel == level }

    var body: some View {
        ZStack {
            Nuclear.background.ignoresSafeArea()
            GeometryReader { size in
                Image(stage.artwork).resizable().scaledToFill()
                    .frame(width: size.size.width, height: size.size.height)
                    .clipped().ignoresSafeArea()
            }
            LinearGradient(colors: [Nuclear.background.opacity(0.35), Nuclear.background.opacity(0.55), Nuclear.background],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            RadialGradient(colors: [stage.accent.opacity(revealed ? 0.35 : 0.12), .clear],
                           center: .center, startRadius: 20, endRadius: 320).ignoresSafeArea()
            VStack(spacing: 17) {
                Spacer()
                Image(systemName: stage.symbol)
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(stage.accent)
                    .shadow(color: stage.accent.opacity(0.7), radius: 17)
                    .scaleEffect(revealed ? 1 : 0.65)
                Text(newForm ? "TRANSFORMATION DÉBLOQUÉE" : "NIVEAU SUPÉRIEUR")
                    .font(.system(size: 12, weight: .black)).tracking(2)
                    .foregroundStyle(Nuclear.paleGold)
                Text("\(level)")
                    .font(.system(size: 102, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Nuclear.gold.opacity(0.7), radius: 17)
                Text("RANG " + stage.name)
                    .font(.title2.bold()).foregroundStyle(stage.accent)
                Text(newForm ? "Une nouvelle apparence est disponible dans Ascension." : "Une étape de plus dans ton ascension personnelle.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white)
                Button(action: onDismiss) {
                    Text("CONTINUER L'ASCENSION")
                        .font(.headline.bold()).frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                .padding(.top, 24)
                Spacer().frame(height: 45)
            }.padding(27)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.66)) { revealed = true }
        }
    }
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
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bilux.lastCelebratedLevel") private var lastCelebratedLevel = 0
    @AppStorage("bilux.equippedTransformationID") private var equippedTransformationID = -1
    @State private var showLevelUp = false

    private var homeStage: NuclearStage {
        NuclearStage.all.first(where: { $0.id == equippedTransformationID && $0.minLevel <= journal.heroLevel })
            ?? NuclearStage.current(level: journal.heroLevel)
    }

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
            .onAppear { pulse = true; checkForLevelUp() }
            .onChange(of: journal.heroLevel) { _, _ in checkForLevelUp() }
            .fullScreenCover(isPresented: $showLevelUp) {
                NuclearLevelUp(level: journal.heroLevel) {
                    lastCelebratedLevel = max(lastCelebratedLevel, journal.heroLevel)
                    showLevelUp = false
                }
            }
            .alert("BILUX", isPresented: Binding(get: { health.message != nil }, set: { if !$0 { health.message = nil } })) {
                Button("OK") { health.message = nil }
            } message: { Text(health.message ?? "") }
        }
    }

    private func checkForLevelUp() {
        let level = journal.heroLevel
        if lastCelebratedLevel == 0 {
            // La premiere ouverture apres mise a jour ne declenche pas une fausse recompense.
            lastCelebratedLevel = level
        } else if level > lastCelebratedLevel {
            showLevelUp = true
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                NuclearHeroAura(level: journal.heroLevel, effectsEnabled: effectsEnabled, stageOverride: homeStage)
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
                            .animation((effectsEnabled && !reduceMotion) ? .easeInOut(duration: 2.5).repeatForever(autoreverses: true) : .none, value: pulse)
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
                    SectionCaption(title: "Records de la forge")
                    NuclearCard {
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(Nuclear.gold)
                            Text("TES MEILLEURES MARQUES").font(.caption.bold()).tracking(1)
                        }
                        if let record = NuclearProgress.recordLoad(journal.data) {
                            HStack {
                                Text("Charge maximale").foregroundStyle(Nuclear.muted)
                                Spacer()
                                Text(unit(record.weight, "kg", decimals: 1)).foregroundStyle(Nuclear.gold).bold()
                            }.font(.subheadline)
                            Text(record.name).font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                        if let record = NuclearProgress.recordRepetitions(journal.data) {
                            HStack {
                                Text("Répétitions sur une série").foregroundStyle(Nuclear.muted)
                                Spacer()
                                Text("\(record.reps) reps").foregroundStyle(Nuclear.gold).bold()
                            }.font(.subheadline)
                            Text(record.name).font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                        if let best = journal.data.workouts.max(by: { $0.volume < $1.volume }), best.volume > 0 {
                            HStack {
                                Text("Volume sur une séance").foregroundStyle(Nuclear.muted)
                                Spacer()
                                Text(unit(best.volume, "kg·rép")).foregroundStyle(Nuclear.gold).bold()
                            }.font(.subheadline)
                        }
                        if journal.data.workouts.isEmpty {
                            Text("Tes records apparaîtront après ta première séance.")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                        }
                        Text("Records calculés uniquement sur les séries saisies dans BILUX. Aucun maximum théorique estimé.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                    }
                    SectionCaption(title: "Volume hebdomadaire")
                    NuclearCard {
                        let volumes = NuclearProgress.weeklyVolumes(journal.data)
                        let maxVolume = max(volumes.max() ?? 0, 1)
                        HStack(alignment: .bottom, spacing: 11) {
                            ForEach(0..<volumes.count, id: \.self) { index in
                                VStack(spacing: 6) {
                                    Text(volumes[index] > 0 ? BiluxFormat.number(volumes[index]) : "—")
                                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(Nuclear.paleGold)
                                        .lineLimit(1).minimumScaleFactor(0.5)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(LinearGradient(colors: [Nuclear.gold, Nuclear.purple], startPoint: .top, endPoint: .bottom))
                                        .frame(height: max(4, 78 * CGFloat(volumes[index] / maxVolume)))
                                        .frame(maxHeight: 80, alignment: .bottom)
                                    Text(index == 5 ? "Cette sem." : "S-\(5-index)")
                                        .font(.system(size: 8)).foregroundStyle(Nuclear.muted)
                                        .lineLimit(1).minimumScaleFactor(0.6)
                                }.frame(maxWidth: .infinity, alignment: .bottom)
                            }
                        }.frame(height: 118, alignment: .bottom)
                        Text("Volume = charge × répétitions ; les activités sans charge restent à zéro.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
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
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @AppStorage("bilux.equippedTransformationID") private var equippedTransformationID = -1
    @State private var selectedStage = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    GeometryReader { geometry in
                        NuclearHeroAura(level: journal.heroLevel, effectsEnabled: effectsEnabled, stageOverride: NuclearStage.all[selectedStage])
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(height: 275)
                    .clipShape(RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(Nuclear.gold.opacity(0.55), lineWidth: 1))
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
                    SectionCaption(title: "Les cinq transformations")
                    Text("Chaque rang a désormais un portrait différent. Une forme déverrouillée peut être équipée ; les rangs futurs restent en aperçu.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(NuclearStage.all) { stage in
                                let unlocked = journal.heroLevel >= stage.minLevel
                                Button { selectedStage = stage.id } label: {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Image(systemName: unlocked ? stage.symbol : "lock.fill")
                                            .font(.title3).foregroundStyle(unlocked ? stage.accent : Nuclear.muted)
                                        Text(stage.name).font(.caption.bold()).foregroundStyle(.white)
                                        Text(unlocked ? "DÉBLOQUÉ" : "NIV. \(stage.minLevel)")
                                            .font(.system(size: 9, weight: .bold)).foregroundStyle(unlocked ? Nuclear.gold : Nuclear.muted)
                                    }
                                    .padding(13).frame(width: 132, height: 110, alignment: .leading)
                                    .background(selectedStage == stage.id ? stage.accent.opacity(0.22) : Nuclear.panel,
                                                in: RoundedRectangle(cornerRadius: 15))
                                    .overlay(RoundedRectangle(cornerRadius: 15)
                                        .stroke(selectedStage == stage.id ? stage.accent : Nuclear.purple.opacity(0.3)))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.vertical, 4)
                    }
                    NuclearCard {
                        let stage = NuclearStage.all[selectedStage]
                        HStack {
                            Text(stage.name).font(.headline).foregroundStyle(Nuclear.paleGold)
                            Spacer()
                            Image(systemName: stage.symbol).foregroundStyle(stage.accent)
                        }
                        Text(stage.subtitle).foregroundStyle(.white)
                        Text(journal.heroLevel >= stage.minLevel
                             ? "Transformation acquise · niveau \(stage.minLevel)"
                             : "Encore verrouillée · disponible au niveau \(stage.minLevel)")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                        if journal.heroLevel >= stage.minLevel {
                            Button {
                                equippedTransformationID = stage.id
                            } label: {
                                Label(equippedTransformationID == stage.id || (equippedTransformationID == -1 && NuclearStage.current(level: journal.heroLevel).id == stage.id)
                                      ? "FORME ACTIVE" : "ÉQUIPER CETTE FORME",
                                      systemImage: "bolt.shield.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(stage.accent)
                            .disabled(equippedTransformationID == stage.id)
                        } else {
                            Label("Déblocage automatique au niveau \(stage.minLevel)", systemImage: "lock.fill")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                        }
                    }
                    SectionCaption(title: "Arbre de maîtrise")
                    NuclearCard {
                        NuclearMasteryTree(data: journal.data)
                    }
                    SectionCaption(title: "Trophées du réacteur")
                    let awards = NuclearProgress.awards(journal.data, level: journal.heroLevel)
                    Text("\(awards.filter(\.achieved).count) / \(awards.count) débloqués")
                        .font(.caption).foregroundStyle(Nuclear.paleGold)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(awards) { award in
                            NuclearCard {
                                Image(systemName: award.achieved ? award.icon : "lock.fill")
                                    .font(.title2).foregroundStyle(award.achieved ? Nuclear.gold : Nuclear.muted)
                                Text(award.name).font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                                    .lineLimit(2).minimumScaleFactor(0.7)
                                Text(award.detail).font(.caption2).foregroundStyle(Nuclear.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(award.achieved ? "ACQUIS" : "À DÉBLOQUER")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(award.achieved ? Nuclear.gold : Nuclear.muted)
                            }.opacity(award.achieved ? 1 : 0.75)
                        }
                    }
                    SectionCaption(title: "Effets visuels")
                    NuclearCard {
                        Toggle("Animations nucléaires", isOn: $effectsEnabled).tint(Nuclear.gold)
                        Text("Désactive les effets animés pour économiser la batterie. Le réglage de réduction des animations d'iOS est respecté.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
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
            .onAppear {
                let unlocked = NuclearStage.all.first(where: { $0.id == equippedTransformationID && $0.minLevel <= journal.heroLevel })
                selectedStage = (unlocked ?? NuclearStage.current(level: journal.heroLevel)).id
            }
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
