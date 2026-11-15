import SwiftUI

private enum ReactorTheme {
    static let gold = Color(red: 1, green: 0.72, blue: 0.24)
    static let purple = Color(red: 0.66, green: 0.36, blue: 0.98)
    static let panel = Color(red: 0.15, green: 0.095, blue: 0.16)
}

private struct ReactorCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(ReactorTheme.panel, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(ReactorTheme.gold.opacity(0.3)))
    }
}

struct LegacyWatchRootView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @EnvironmentObject private var health: WatchHealthReader

    var body: some View {
        TabView {
            commandPage
            healthPage
            questPage
            workoutPage
        }
        .tabViewStyle(.verticalPage)
        .background(
            LinearGradient(colors: [.black, ReactorTheme.purple.opacity(0.16), .black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .tint(ReactorTheme.gold)
        .task { bridge.refresh() }
    }

    private var commandPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 25)).foregroundStyle(ReactorTheme.gold)
                    .shadow(color: ReactorTheme.purple, radius: 10)
                Text("BILUX").font(.system(size: 22, weight: .black, design: .serif))
                    .tracking(2).foregroundStyle(ReactorTheme.gold)
                Text("NUCLEAR WATCH").font(.system(size: 9, weight: .black)).tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                ReactorCard {
                    Text("RANG · \(bridge.snapshot.rank)").font(.caption2.bold())
                        .foregroundStyle(ReactorTheme.gold).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(alignment: .firstTextBaseline) {
                        Text("NIV. \(bridge.snapshot.level)").font(.headline.bold())
                        Spacer(minLength: 2)
                        Text("\(bridge.snapshot.totalXP) XP").font(.caption2)
                    }
                    ProgressView(value: bridge.snapshot.xpProgress).tint(ReactorTheme.gold)
                }
                if bridge.snapshot.updatedAt == .distantPast {
                    Text("Ouvre BILUX sur l'iPhone pour la première synchronisation.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else {
                    Text("Synchronisé : \(bridge.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Button("Synchroniser", systemImage: "arrow.triangle.2.circlepath") { bridge.refresh() }
                    .font(.caption2)
            }.padding(.horizontal, 5)
        }.containerBackground(.clear, for: .tabView)
    }

    private var healthPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 7) {
                Text("DONNÉES RÉELLES").font(.caption2.bold()).foregroundStyle(ReactorTheme.gold)
                HStack(spacing: 6) {
                    metric("Pas", value: count(health.steps ?? bridge.snapshot.steps), symbol: "figure.walk")
                    metric("Kcal", value: count(health.activeKcal ?? bridge.snapshot.activeKcal), symbol: "flame")
                }
                HStack(spacing: 6) {
                    metric("Pouls", value: count(health.heartRateBPM ?? bridge.snapshot.latestHeartRate), symbol: "heart.fill")
                    metric("Sommeil", value: fractional(bridge.snapshot.sleepHours, "h"), symbol: "moon.stars")
                }
                Button(health.loading ? "Lecture…" : "Lire sur la montre", systemImage: "heart.text.square") {
                    Task { await health.authorizeAndRefresh() }
                }.disabled(health.loading).font(.caption2)
                if let msg = health.message {
                    Text(msg).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text("Dernière mesure cardiaque, pas de suivi continu.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 5)
        }.containerBackground(.clear, for: .tabView)
    }

    private func metric(_ label: String, value: String, symbol: String) -> some View {
        ReactorCard {
            Label(label, systemImage: symbol).font(.system(size: 10)).foregroundStyle(ReactorTheme.gold)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
        }
    }

    private var questPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("QUÊTES DU JOUR").font(.caption2.bold()).foregroundStyle(ReactorTheme.gold)
                if bridge.snapshot.quests.isEmpty {
                    Text("Synchronise l'iPhone pour voir tes quêtes.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(bridge.snapshot.quests) { quest in
                    ReactorCard {
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: quest.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(quest.completed ? .green : ReactorTheme.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(quest.title).font(.caption2.bold())
                                Text(quest.completed ? "Terminée" : "+\(quest.reward) XP")
                                    .font(.system(size: 10)).foregroundStyle(ReactorTheme.gold)
                            }
                        }
                    }
                }
                Text("Récompenses calculées sur l'iPhone.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 5)
        }.containerBackground(.clear, for: .tabView)
    }

    private var workoutPage: some View { WatchWorkoutView() }
    private func count(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Int(value.rounded()).formatted()
    }
    private func fractional(_ value: Double?, _ suffix: String) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(suffix)"
    }
}

struct WatchWorkoutView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @AppStorage("bilux.watch.workout.start") private var startTimestamp: Double = 0
    private var running: Bool { startTimestamp > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("MODE COMBAT").font(.caption2.bold()).foregroundStyle(ReactorTheme.gold)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 25)).foregroundStyle(ReactorTheme.purple)
                if running {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, Int(context.date.timeIntervalSince1970 - startTimestamp))
                        Text(String(format: "%02d:%02d", elapsed / 60, elapsed % 60))
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ReactorTheme.gold)
                    }
                    Button("Terminer et consigner", systemImage: "checkmark.circle") {
                        let start = Date(timeIntervalSince1970: startTimestamp)
                        let minutes = Int(Date().timeIntervalSince(start) / 60)
                        startTimestamp = 0
                        bridge.finishWorkout(start: start, elapsedMinutes: minutes)
                    }.tint(ReactorTheme.gold)
                } else {
                    Text("Chronomètre de séance").font(.caption2).foregroundStyle(.secondary)
                    Button("Démarrer", systemImage: "play.fill") {
                        startTimestamp = Date().timeIntervalSince1970
                    }.tint(ReactorTheme.gold)
                }
                if let info = bridge.feedback {
                    Text(info).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text("Journal manuel : pas d'enregistrement dans Apple Santé.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.horizontal, 5)
        }.containerBackground(.clear, for: .tabView)
    }
}

// MARK: - BILUX V5.4 — Nouvel écran, ancien écran conservé ci-dessus

// BILUX V5.4 — Watch 2.0. Affichage derivé du snapshot iPhone,
// sans modification du calcul des XP ni des sauvegardes.
private enum V54ReactorTheme {
    static let background = Color(red: 0.035, green: 0.026, blue: 0.065)
    static let gold = Color(red: 1.00, green: 0.76, blue: 0.30)
    static let paleGold = Color(red: 1.00, green: 0.91, blue: 0.70)
    static let purple = Color(red: 0.70, green: 0.37, blue: 1.00)
    static let green = Color(red: 0.43, green: 0.89, blue: 0.59)
    static let panel = Color(red: 0.12, green: 0.085, blue: 0.18)
    static let secondary = Color.white.opacity(0.70)
}

private struct V54ReactorCard<Content: View>: View {
    var accent: Color = V54ReactorTheme.gold
    let content: Content

    init(accent: Color = V54ReactorTheme.gold, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(
                LinearGradient(colors: [accent.opacity(0.17), V54ReactorTheme.panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.38), lineWidth: 1)
            }
    }
}

private struct V54ReactorTitle: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(V54ReactorTheme.gold)
            Text(text).foregroundStyle(V54ReactorTheme.paleGold)
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .tracking(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct V54ReactorXPRing: View {
    let progress: Double
    let level: Int
    let rank: String

    private var normalized: Double { min(1, max(0, progress.isFinite ? progress : 0)) }
    private var symbol: String {
        switch rank.uppercased() {
        case "ASCENSION": return "crown.fill"
        case "NUCLÉAIRE": return "atom"
        case "RÉACTEUR": return "bolt.fill"
        case "ÉVEIL": return "sparkles"
        default: return "shield.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(V54ReactorTheme.purple.opacity(0.25), lineWidth: 8)
            Circle()
                .trim(from: 0, to: normalized)
                .stroke(AngularGradient(colors: [V54ReactorTheme.purple, V54ReactorTheme.gold, V54ReactorTheme.paleGold],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(V54ReactorTheme.gold)
                Text("\(Int((normalized * 100).rounded()))%")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
        }
        .frame(width: 83, height: 83)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rang \(rank), niveau \(level), progression \(Int((normalized * 100).rounded())) pour cent")
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @EnvironmentObject private var health: WatchHealthReader
    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            commandPage.tag(0)
            healthPage.tag(1)
            questPage.tag(2)
            ascensionPage.tag(3)
            V54WatchWorkoutView().tag(4)
            V61LiveWorkoutView().tag(5)
        }
        .tabViewStyle(.verticalPage)
        .background {
            LinearGradient(colors: [V54ReactorTheme.background, V54ReactorTheme.purple.opacity(0.16), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .tint(V54ReactorTheme.gold)
        .task { bridge.refresh() }
        // V6.1.1 : un appui sur le widget ouvre la page, sans lancer HKWorkoutSession.
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "biluxwatch",
                  url.host?.lowercased() == "live" else { return }
            selectedPage = 5
            bridge.refresh()
        }
    }

    private var commandPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(V54ReactorTheme.gold)
                    Text("BILUX")
                        .tracking(2)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("REBIRTH · WATCH 3.0")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(V54ReactorTheme.gold)

                V54ReactorCard {
                    HStack(spacing: 11) {
                        V54ReactorXPRing(progress: bridge.snapshot.xpProgress,
                                      level: bridge.snapshot.level,
                                      rank: bridge.snapshot.rank)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(bridge.snapshot.rank.uppercased())
                                .foregroundStyle(V54ReactorTheme.gold)
                                .font(.system(size: 11, weight: .black))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("NIV. \(bridge.snapshot.level)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("\(bridge.snapshot.totalXP) XP")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(V54ReactorTheme.secondary)
                            if let remaining = bridge.snapshot.xpRemaining {
                                Text("Encore \(remaining) XP")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(V54ReactorTheme.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                if let title = bridge.snapshot.equippedTitle, !title.isEmpty {
                    V54ReactorCard(accent: V54ReactorTheme.purple) {
                        Label(title, systemImage: "crown.fill")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(V54ReactorTheme.paleGold)
                            .lineLimit(2).minimumScaleFactor(0.7)
                        if let aura = bridge.snapshot.equippedAura {
                            Label(aura, systemImage: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(V54ReactorTheme.purple)
                        }
                    }
                }
                if bridge.snapshot.updatedAt == .distantPast {
                    Text("Ouvre BILUX sur l'iPhone pour synchroniser les données.")
                        .font(.system(size: 10)).multilineTextAlignment(.center)
                        .foregroundStyle(V54ReactorTheme.secondary)
                } else {
                    Label("MAJ \(bridge.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                        .foregroundStyle(V54ReactorTheme.secondary)
                }
                Button {
                    selectedPage = 4
                } label: {
                    Label("LANCER LA FORGE", systemImage: "dumbbell.fill")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12, weight: .heavy))
                }
                .buttonStyle(.borderedProminent)
                .tint(V54ReactorTheme.gold)

                Button {
                    selectedPage = 5
                } label: {
                    Label("NUCLEAR LIVE", systemImage: "heart.fill")
                        .font(.caption2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(V54ReactorTheme.purple)

                Button {
                    selectedPage = 3
                } label: {
                    Label("LES GARDIENS", systemImage: "shield.fill")
                        .font(.caption2.bold())
                }
                .buttonStyle(.bordered)
                .tint(V54ReactorTheme.purple)

                Button {
                    bridge.refresh()
                } label: {
                    Label("Synchroniser", systemImage: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }

    private var healthPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                V54ReactorTitle(text: "TON RÉACTEUR", symbol: "heart.text.square.fill")
                HStack(spacing: 6) {
                    metric("PAS", value: whole(health.steps ?? bridge.snapshot.steps), symbol: "figure.walk", accent: V54ReactorTheme.green)
                    metric("KCAL", value: whole(health.activeKcal ?? bridge.snapshot.activeKcal), symbol: "flame.fill", accent: V54ReactorTheme.gold)
                }
                HStack(spacing: 6) {
                    metric("POULS", value: whole(health.heartRateBPM ?? bridge.snapshot.latestHeartRate), symbol: "heart.fill", accent: .pink)
                    metric("SOMMEIL", value: decimal(bridge.snapshot.sleepHours, suffix: "h"), symbol: "moon.stars.fill", accent: V54ReactorTheme.purple)
                }
                Button {
                    Task { await health.authorizeAndRefresh() }
                } label: {
                    Label(health.loading ? "Lecture en cours…" : "Actualiser Santé",
                          systemImage: "heart.text.square")
                        .font(.caption2)
                }
                .disabled(health.loading)
                .buttonStyle(.borderedProminent)
                .tint(V54ReactorTheme.purple)

                if let msg = health.message {
                    Text(msg).font(.system(size: 10)).foregroundStyle(V54ReactorTheme.secondary)
                }
                Text("Lecture facultative. La fréquence cardiaque affichée est la dernière mesure disponible.")
                    .font(.system(size: 9)).foregroundStyle(V54ReactorTheme.secondary)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }

    private func metric(_ name: String, value: String, symbol: String, accent: Color) -> some View {
        V54ReactorCard(accent: accent) {
            Label(name, systemImage: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accent)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    private var questPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                V54ReactorTitle(text: "MISSIONS DU JOUR", symbol: "shield.lefthalf.filled")
                if bridge.snapshot.quests.isEmpty {
                    V54ReactorCard {
                        Text("Aucune mission synchronisée.")
                            .font(.caption2)
                            .foregroundStyle(V54ReactorTheme.secondary)
                    }
                } else {
                    let done = bridge.snapshot.quests.filter(\.completed).count
                    V54ReactorCard(accent: V54ReactorTheme.green) {
                        Text("\(done) / \(bridge.snapshot.quests.count) OBJECTIFS")
                            .font(.system(size: 13, weight: .heavy))
                        ProgressView(value: Double(done), total: Double(max(1, bridge.snapshot.quests.count)))
                            .tint(V54ReactorTheme.green)
                    }
                    ForEach(bridge.snapshot.quests) { quest in
                        V54ReactorCard(accent: quest.completed ? V54ReactorTheme.green : V54ReactorTheme.gold) {
                            HStack(alignment: .center, spacing: 7) {
                                Image(systemName: quest.completed ? "checkmark.seal.fill" : "circle.dotted")
                                    .foregroundStyle(quest.completed ? V54ReactorTheme.green : V54ReactorTheme.gold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(quest.title).font(.system(size: 12, weight: .semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(quest.completed ? "ACCOMPLIE" : "RÉCOMPENSE +\(quest.reward) XP")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(quest.completed ? V54ReactorTheme.green : V54ReactorTheme.gold)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                Text("Les objectifs et XP sont calculés sur l'iPhone.")
                    .font(.system(size: 9)).foregroundStyle(V54ReactorTheme.secondary)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }

    // ASCENSION : données du même calcul de jours éligibles que l'iPhone.
    private var ascensionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                V54ReactorTitle(text: "L'ASCENSION", symbol: "crown.fill")
                V54ReactorCard(accent: V54ReactorTheme.gold) {
                    Text("LA FORGE HEBDOMADAIRE")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(V54ReactorTheme.paleGold)
                    if let days = bridge.snapshot.weeklyWorkouts {
                        HStack {
                            Text("\(days) / 3 journées")
                                .font(.system(size: 14, weight: .heavy))
                            Spacer()
                            Text(days >= 3 ? "ACCOMPLI" : "EN COURS")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(V54ReactorTheme.gold)
                        }
                        ProgressView(value: Double(min(3, max(0, days))), total: 3)
                            .tint(V54ReactorTheme.gold)
                    } else {
                        Text("Synchronise l'iPhone pour voir tes missions.")
                            .font(.caption2).foregroundStyle(V54ReactorTheme.secondary)
                    }
                }
                guardianCard(name: "GARDIEN DU RÉACTEUR", icon: "shield.fill",
                             done: bridge.snapshot.monthlyWorkouts, goal: 12,
                             accent: V54ReactorTheme.purple, span: "Mensuel")
                guardianCard(name: "SOUVERAIN DU NÉANT", icon: "crown.fill",
                             done: bridge.snapshot.quarterWorkouts, goal: 30,
                             accent: V54ReactorTheme.gold, span: "Trimestriel")
                if let count = bridge.snapshot.workoutCount {
                    V54ReactorCard {
                        Label("\(count) séances consignées", systemImage: "dumbbell.fill")
                            .font(.caption2.bold()).foregroundStyle(V54ReactorTheme.paleGold)
                        if let recent = bridge.snapshot.lastWorkoutLabel {
                            Text("Dernière : \(recent)")
                                .font(.system(size: 10))
                                .foregroundStyle(V54ReactorTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("Les PV changent avec tes séances éligibles : 1 jour par date, au plus 5 par semaine. Aucun malus de repos.")
                    .font(.system(size: 9))
                    .foregroundStyle(V54ReactorTheme.secondary)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }

    private func guardianCard(name: String, icon: String, done: Int?, goal: Int,
                              accent: Color, span: String) -> some View {
        V54ReactorCard(accent: accent) {
            Label(name, systemImage: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
            if let done {
                let capped = min(goal, max(0, done))
                let hp = max(0, Int((100.0 * Double(goal - capped) / Double(goal)).rounded()))
                HStack {
                    Text("\(capped) / \(goal) jours")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("\(hp)% PV")
                        .font(.system(size: 11, weight: .heavy))
                }
                ProgressView(value: Double(capped), total: Double(goal)).tint(accent)
                Text(capped >= goal ? "VICTOIRE" : "\(span) · phase \(min(4, Int(Double(capped) / Double(goal) * 4) + 1))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(V54ReactorTheme.secondary)
            } else {
                Text("Données en attente de l'iPhone")
                    .font(.caption2).foregroundStyle(V54ReactorTheme.secondary)
            }
        }
    }

    private func whole(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return Int(value.rounded()).formatted()
    }

    private func decimal(_ value: Double?, suffix: String) -> String {
        guard let value, value.isFinite else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(suffix)"
    }
}

private enum V54CombatMode: String, CaseIterable, Identifiable {
    case musculation = "Musculation"
    case marche = "Marche"
    case cardio = "Cardio"
    case mobilite = "Mobilité"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .musculation: return "dumbbell.fill"
        case .marche: return "figure.walk"
        case .cardio: return "heart.fill"
        case .mobilite: return "figure.cooldown"
        }
    }
}

struct V54WatchWorkoutView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @AppStorage("bilux.watch.workout.start") private var startTimestamp: Double = 0
    @AppStorage("bilux.watch.workout.activity") private var activity = V54CombatMode.musculation.rawValue
    @AppStorage("bilux.watch.workout.pausedAt") private var pausedAt: Double = 0
    @AppStorage("bilux.watch.workout.pauseSeconds") private var pauseSeconds: Double = 0
    @State private var confirmAbandon = false
    @State private var localMessage: String?

    private var running: Bool { startTimestamp > 0 }
    private var paused: Bool { running && pausedAt > 0 }

    private func elapsedSeconds(now: Date) -> Int {
        let stop = paused ? pausedAt : now.timeIntervalSince1970
        return max(0, Int(stop - startTimestamp - pauseSeconds))
    }
    private func resetTimer() {
        startTimestamp = 0
        pausedAt = 0
        pauseSeconds = 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                V54ReactorTitle(text: "LA FORGE · WATCH 3.0", symbol: "dumbbell.fill")
                if running {
                    V54ReactorCard(accent: V54ReactorTheme.gold) {
                        Label(activity.uppercased(), systemImage: "bolt.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(V54ReactorTheme.gold)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = elapsedSeconds(now: context.date)
                            Text(String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60))
                                .font(.system(size: 23, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button {
                        if paused {
                            pauseSeconds += max(0, Date().timeIntervalSince1970 - pausedAt)
                            pausedAt = 0
                        } else {
                            pausedAt = Date().timeIntervalSince1970
                        }
                    } label: {
                        Label(paused ? "REPRENDRE" : "PAUSE", systemImage: paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .buttonStyle(.bordered)
                    .tint(V54ReactorTheme.purple)

                    Button {
                        let start = Date(timeIntervalSince1970: startTimestamp)
                        let minutes = elapsedSeconds(now: .now) / 60
                        if minutes < 1 {
                            localMessage = "Attends au moins une minute avant d'enregistrer."
                        } else {
                            bridge.finishWorkout(start: start, elapsedMinutes: minutes, activity: activity)
                            resetTimer()
                            localMessage = "Séance transférée ou mise en attente."
                        }
                    } label: {
                        Label("TERMINER ET CONSIGNER", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(V54ReactorTheme.gold)

                    Button(role: .destructive) { confirmAbandon = true } label: {
                        Label("Abandonner", systemImage: "xmark.circle").font(.caption2)
                    }
                    .confirmationDialog("Abandonner cette séance sans l'enregistrer ?", isPresented: $confirmAbandon) {
                        Button("Abandonner la séance", role: .destructive) {
                            resetTimer()
                            localMessage = nil
                        }
                    }
                } else {
                    Text("CHOISIS TON COMBAT")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(V54ReactorTheme.secondary)
                    ForEach(V54CombatMode.allCases) { mode in
                        Button {
                            activity = mode.rawValue
                            localMessage = nil
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: mode.symbol)
                                    .frame(width: 20)
                                    .foregroundStyle(activity == mode.rawValue ? V54ReactorTheme.gold : V54ReactorTheme.secondary)
                                Text(mode.rawValue).font(.system(size: 12, weight: .semibold))
                                Spacer(minLength: 0)
                                if activity == mode.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(V54ReactorTheme.green)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(activity == mode.rawValue ? V54ReactorTheme.gold : V54ReactorTheme.purple)
                    }
                    Button {
                        pauseSeconds = 0
                        pausedAt = 0
                        startTimestamp = Date().timeIntervalSince1970
                        localMessage = nil
                    } label: {
                        Label("DÉMARRER", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(V54ReactorTheme.gold)
                }
                if let message = localMessage ?? bridge.feedback {
                    Text(message)
                        .font(.system(size: 10))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(V54ReactorTheme.secondary)
                }
                Text("Séance chronométrée manuellement. Pas d'écriture dans Apple Santé.")
                    .font(.system(size: 9))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(V54ReactorTheme.secondary)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }
}

// MARK: - BILUX V6.1 · NUCLEAR LIVE
// Une vraie séance HealthKit distincte de la Forge manuelle.
// La session reste gérée par un singleton même si l'utilisateur change de page.
import HealthKit
import Combine
import WatchKit

// Zones visuelles indicatives calculées en % de FC max choisie sur la montre.
// Ne prescrivent ni seuil médical ni intensité d'entraînement.
private enum V62CardiacZone {
    static func index(_ bpm: Double, maxBPM: Int) -> Int {
        let fraction = bpm / Double(max(120, min(220, maxBPM)))
        switch fraction {
        case ..<0.60: return 1
        case ..<0.70: return 2
        case ..<0.80: return 3
        case ..<0.90: return 4
        default: return 5
        }
    }
}


private enum V61LiveMode: String, CaseIterable, Identifiable {
    case strength = "Musculation"
    case walking = "Marche"
    case cardio = "Cardio"
    case mobility = "Mobilité"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .walking: return "figure.walk"
        case .cardio: return "heart.fill"
        case .mobility: return "figure.cooldown"
        }
    }
    var healthType: HKWorkoutActivityType {
        switch self {
        case .strength: return .traditionalStrengthTraining
        case .walking: return .walking
        case .cardio: return .mixedCardio
        case .mobility: return .flexibility
        }
    }
}

@MainActor
private final class V61NuclearLive: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = V61NuclearLive()

    enum Phase: Equatable {
        case idle, requesting, starting, running, paused, finishing, saved, failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var bpm: Double?
    @Published private(set) var activeKcal: Double?
    @Published private(set) var activityName = "Musculation"
    @Published private(set) var message: String?
    @Published private(set) var cardiacZone: Int?
    @Published private(set) var zoneSeconds: [Int] = [0, 0, 0, 0, 0]
    @Published private(set) var averageBPM: Int?
    @Published private(set) var peakBPM: Int?
    @Published private(set) var maxReferenceBPM = 190
    private var sumBPM: Double = 0
    private var heartSamples = 0
    private var lastHeartAt: Date?
    private var lastZone: Int?
    private var hapticEnabled = false
    private var lastHapticAt: Date?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private weak var bridge: WatchBridge?
    private var begunAt: Date?
    private var pausedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var finishDuration: Int = 0
    private var didFinish = false
    private var closingCollection = false

    var inProgress: Bool { phase == .requesting || phase == .starting || phase == .running || phase == .paused || phase == .finishing }

    func elapsed(at date: Date = .now) -> Int {
        guard let begunAt else { return 0 }
        let end = pausedAt ?? date
        return max(0, Int(end.timeIntervalSince(begunAt) - pausedTotal))
    }

    func start(mode: V61LiveMode, bridge: WatchBridge,
               referenceMaxBPM: Int, enableHaptics: Bool) async {
        guard !inProgress else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            phase = .failed
            message = "Apple Santé est indisponible sur cette montre."
            return
        }
        self.bridge = bridge
        phase = .requesting
        message = "Autorisation Apple Santé…"
        do {
            let read: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            ]
            let share: Set<HKSampleType> = [HKObjectType.workoutType()]
            try await store.requestAuthorization(toShare: share, read: read)
            // La demande d'autorisation ne garantit pas l'accès ; les mesures peuvent rester absentes.
            let config = HKWorkoutConfiguration()
            config.activityType = mode.healthType
            config.locationType = .unknown
            let activeSession = try HKWorkoutSession(healthStore: store, configuration: config)
            let activeBuilder = activeSession.associatedWorkoutBuilder()
            activeBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            activeSession.delegate = self
            activeBuilder.delegate = self
            session = activeSession
            builder = activeBuilder
            activityName = mode.rawValue
            bpm = nil
            activeKcal = nil
            maxReferenceBPM = max(120, min(220, referenceMaxBPM))
            hapticEnabled = enableHaptics
            cardiacZone = nil
            zoneSeconds = [0, 0, 0, 0, 0]
            sumBPM = 0
            heartSamples = 0
            averageBPM = nil
            peakBPM = nil
            lastHeartAt = nil
            lastZone = nil
            lastHapticAt = nil
            pausedAt = nil
            pausedTotal = 0
            didFinish = false
            closingCollection = false
            let now = Date()
            begunAt = now
            phase = .starting
            message = "Activation des capteurs…"
            activeSession.startActivity(with: now)
            activeBuilder.beginCollection(withStart: now) { [weak self] success, error in
                Task { @MainActor in
                    guard let self, self.phase == .starting else { return }
                    if success {
                        self.phase = .running
                        self.message = nil
                    } else {
                        self.fail(error?.localizedDescription ?? "Impossible de démarrer la collecte Santé.")
                    }
                }
            }
        } catch {
            fail("Démarrage refusé : \(error.localizedDescription)")
        }
    }

    func pauseOrResume() {
        switch phase {
        case .running:
            pausedAt = Date()
            lastHeartAt = nil // Ne jamais comptabiliser de durée dans les zones pendant la pause.
            session?.pause()
            phase = .paused
        case .paused:
            if let pausedAt { pausedTotal += max(0, Date().timeIntervalSince(pausedAt)) }
            pausedAt = nil
            lastHeartAt = nil
            session?.resume()
            phase = .running
        default: break
        }
    }

    func finish() {
        guard phase == .running || phase == .paused, !didFinish else { return }
        let seconds = elapsed()
        guard seconds >= 60 else {
            message = "Une minute effective minimum pour consigner dans BILUX. Tu peux aussi annuler."
            return
        }
        guard session != nil, builder != nil else { return }
        didFinish = true
        finishDuration = seconds
        phase = .finishing
        message = "Enregistrement dans Apple Santé…"
        // Selon Apple : arrêt de l'activité -> état .stopped -> fin de collecte -> sauvegarde.
        session?.stopActivity(with: Date())
    }

    private func finishStoppedSession(at end: Date) {
        guard phase == .finishing, !closingCollection, let builder else { return }
        closingCollection = true
        builder.endCollection(withEnd: end) { [weak self] success, error in
            guard let self else { return }
            guard success else {
                Task { @MainActor in self.fail("Enregistrement incomplet : \(error?.localizedDescription ?? "collecte interrompue")") }
                return
            }
            builder.finishWorkout { [weak self] workout, error in
                Task { @MainActor in
                    guard let self else { return }
                    guard let workout else {
                        self.fail("Sauvegarde Santé impossible : \(error?.localizedDescription ?? "erreur inconnue")")
                        return
                    }
                    // L'UUID HealthKit identifie aussi l'entrée BILUX : la WatchConnectivity
                    // peut retransmettre sans créer un second entraînement dans le journal.
                    self.session?.end()
                    let minutes = self.finishDuration / 60
                    self.bridge?.finishLiveWorkout(
                        start: workout.startDate, elapsedMinutes: minutes,
                        activity: self.activityName, workoutID: workout.uuid,
                        activeKcal: self.activeKcal,
                        averageBPM: self.averageBPM, peakBPM: self.peakBPM,
                        zoneSeconds: self.zoneSeconds,
                        referenceMaxBPM: self.maxReferenceBPM,
                        sampleCount: self.heartSamples
                    )
                    self.clearReferences()
                    self.phase = .saved
                    self.message = "Séance dans Apple Santé ✓ · Transfert BILUX lancé."
                }
            }
        }
    }

    func cancel() {
        guard inProgress, phase != .finishing else { return }
        session?.end()
        builder?.discardWorkout()
        clearReferences()
        phase = .idle
        message = "Séance annulée : rien envoyé au journal BILUX."
    }

    private func clearReferences() {
        session?.delegate = nil
        builder?.delegate = nil
        session = nil
        builder = nil
        begunAt = nil
        pausedAt = nil
        pausedTotal = 0
        didFinish = false
        closingCollection = false
        finishDuration = 0
    }

    private func fail(_ text: String) {
        session?.end()
        // L'erreur n'autorise jamais une seconde sauvegarde implicite.
        builder?.discardWorkout()
        clearReferences()
        phase = .failed
        message = text
    }

    private func updateMetrics(heartUpdated: Bool) {
        guard let builder else { return }
        if heartUpdated,
           let heartType = HKObjectType.quantityType(forIdentifier: .heartRate),
           let quantity = builder.statistics(for: heartType)?.mostRecentQuantity() {
            let rate = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            if rate.isFinite && (35...240).contains(rate), phase == .running {
                let now = Date()
                let nextZone = V62CardiacZone.index(rate, maxBPM: maxReferenceBPM)
                if let lastHeartAt, let lastZone, (1...5).contains(lastZone) {
                    let gap = now.timeIntervalSince(lastHeartAt)
                    // Ne pas inventer des durées pendant les trous de capteur (>15 s).
                    if gap > 0 && gap <= 15 { zoneSeconds[lastZone - 1] += Int(gap.rounded()) }
                }
                let old = cardiacZone
                cardiacZone = nextZone
                if hapticEnabled, let old, old != nextZone,
                   now.timeIntervalSince(lastHapticAt ?? .distantPast) >= 30 {
                    WKInterfaceDevice.current().play(.click)
                    lastHapticAt = now
                }
                lastHeartAt = now
                lastZone = nextZone
                bpm = rate
                heartSamples += 1
                sumBPM += rate
                averageBPM = Int((sumBPM / Double(heartSamples)).rounded())
                peakBPM = max(peakBPM ?? 0, Int(rate.rounded()))
            }
        }
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
           let quantity = builder.statistics(for: energyType)?.sumQuantity() {
            let energy = quantity.doubleValue(for: .kilocalorie())
            if energy.isFinite && energy >= 0 { activeKcal = energy }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .stopped {
            Task { @MainActor in self.finishStoppedSession(at: date) }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            if self.phase != .finishing && self.inProgress { self.fail("Séance interrompue : \(error.localizedDescription)") }
        }
    }
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                     didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Les calories peuvent changer sans nouvel échantillon cardiaque : ne pas
        // compter de durée en zone si seul le flux énergétique a été actualisé.
        let heartUpdated = collectedTypes.contains { sample in
            sample.identifier == HKQuantityTypeIdentifier.heartRate.rawValue
        }
        Task { @MainActor in self.updateMetrics(heartUpdated: heartUpdated) }
    }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

@MainActor
private struct V61LiveWorkoutView: View {
    @EnvironmentObject private var bridge: WatchBridge
    @StateObject private var live = V61NuclearLive.shared
    @State private var selectedMode: V61LiveMode = .strength
    @State private var confirmCancel = false
    @AppStorage("bilux.watch.live.maxReferenceBPM") private var maxReferenceBPM = 190
    @AppStorage("bilux.watch.live.zoneHaptics") private var zoneHaptics = false

    private func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                V54ReactorTitle(text: "NUCLEAR COMMAND · V6.2", symbol: "heart.fill")
                if !live.inProgress {
                    V54ReactorCard(accent: V54ReactorTheme.purple) {
                        Label("CAPTEURS EN DIRECT", systemImage: "waveform.path.ecg")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(V54ReactorTheme.paleGold)
                        Text("La Watch mesure le pouls et les calories. La séance sera aussi enregistrée dans Apple Santé.")
                            .font(.system(size: 10)).foregroundStyle(V54ReactorTheme.secondary)
                    }
                    V54ReactorCard(accent: V54ReactorTheme.purple) {
                        Stepper(value: $maxReferenceBPM, in: 120...220, step: 5) {
                            Text("FC max de référence : \(maxReferenceBPM) bpm")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(V54ReactorTheme.paleGold)
                        }
                        Toggle("Vibration au changement de zone", isOn: $zoneHaptics)
                            .font(.system(size: 10))
                        Text("Zones indicatives selon ce repère, sans prescription d'intensité.")
                            .font(.system(size: 9)).foregroundStyle(V54ReactorTheme.secondary)
                    }
                    ForEach(V61LiveMode.allCases) { mode in
                        Button { selectedMode = mode } label: {
                            HStack {
                                Label(mode.rawValue, systemImage: mode.symbol)
                                Spacer(minLength: 2)
                                if selectedMode == mode { Image(systemName: "checkmark.circle.fill") }
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedMode == mode ? V54ReactorTheme.gold : V54ReactorTheme.purple)
                    }
                    Button {
                        Task {
                            await live.start(mode: selectedMode, bridge: bridge,
                                             referenceMaxBPM: maxReferenceBPM,
                                             enableHaptics: zoneHaptics)
                        }
                    } label: {
                        Label("DÉMARRER LIVE", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .heavy))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(V54ReactorTheme.gold)
                } else {
                    V54ReactorCard(accent: V54ReactorTheme.gold) {
                        Text(live.activityName.uppercased())
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(V54ReactorTheme.gold)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(clock(live.elapsed(at: context.date)))
                                .font(.system(size: 23, weight: .black, design: .rounded))
                                .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("BPM", systemImage: "heart.fill")
                                    .font(.system(size: 10)).foregroundStyle(V54ReactorTheme.purple)
                                Text(live.bpm.map { String(Int($0.rounded())) } ?? "—")
                                    .font(.title3.bold()).monospacedDigit()
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 2) {
                                Label("KCAL", systemImage: "flame.fill")
                                    .font(.system(size: 10)).foregroundStyle(V54ReactorTheme.gold)
                                Text(live.activeKcal.map { String(Int($0.rounded())) } ?? "—")
                                    .font(.title3.bold()).monospacedDigit()
                            }
                        }
                    }
                    V54ReactorCard(accent: V54ReactorTheme.purple) {
                        HStack {
                            Label("ZONES CARDIAQUES", systemImage: "waveform.path.ecg")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(V54ReactorTheme.paleGold)
                            Spacer(minLength: 1)
                            Text(live.cardiacZone.map { "Z\($0)" } ?? "—")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(V54ReactorTheme.gold)
                        }
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { z in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(live.cardiacZone == z ? V54ReactorTheme.gold : V54ReactorTheme.purple.opacity(0.25))
                                    .frame(height: live.cardiacZone == z ? 12 : 6)
                            }
                        }
                        Text("Basées sur \(live.maxReferenceBPM) bpm · repères indicatifs")
                            .font(.system(size: 9)).foregroundStyle(V54ReactorTheme.secondary)
                    }
                    if live.phase == .paused {
                        Label("SÉANCE EN PAUSE", systemImage: "pause.circle.fill")
                            .font(.caption2.bold()).foregroundStyle(V54ReactorTheme.purple)
                    }
                    if live.phase == .running || live.phase == .paused {
                        Button { live.pauseOrResume() } label: {
                            Label(live.phase == .paused ? "REPRENDRE" : "PAUSE",
                                  systemImage: live.phase == .paused ? "play.fill" : "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).tint(V54ReactorTheme.purple)
                        Button { live.finish() } label: {
                            Label("TERMINER ET SAUVER", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(V54ReactorTheme.gold)
                        Button(role: .destructive) { confirmCancel = true } label: {
                            Label("Annuler sans sauvegarder", systemImage: "xmark.circle")
                                .font(.system(size: 10))
                        }
                        .confirmationDialog("Annuler la séance HealthKit sans l'enregistrer ?", isPresented: $confirmCancel) {
                            Button("Annuler la séance", role: .destructive) { live.cancel() }
                        }
                    }
                }
                if let message = live.message {
                    Text(message).font(.system(size: 10))
                        .foregroundStyle(V54ReactorTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Une séance HealthKit terminée = un enregistrement dans Apple Santé et une entrée dans BILUX. La Forge manuelle reste disponible séparément.")
                    .font(.system(size: 9)).foregroundStyle(V54ReactorTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
        .containerBackground(.clear, for: .tabView)
    }
}
