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
        switch level {
        case 15...: return "crown.fill"
        case 10...: return "atom"
        case 6...: return "bolt.fill"
        case 3...: return "sparkles"
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
            V54WatchWorkoutView().tag(3)
        }
        .tabViewStyle(.verticalPage)
        .background {
            LinearGradient(colors: [V54ReactorTheme.background, V54ReactorTheme.purple.opacity(0.16), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .tint(V54ReactorTheme.gold)
        .task { bridge.refresh() }
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
                Text("NUCLEAR WATCH 2.0")
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
                        }
                        Spacer(minLength: 0)
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
                    selectedPage = 3
                } label: {
                    Label("LANCER LA FORGE", systemImage: "dumbbell.fill")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12, weight: .heavy))
                }
                .buttonStyle(.borderedProminent)
                .tint(V54ReactorTheme.gold)

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
    @State private var confirmAbandon = false
    @State private var localMessage: String?

    private var running: Bool { startTimestamp > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                V54ReactorTitle(text: "LA FORGE", symbol: "dumbbell.fill")
                if running {
                    V54ReactorCard(accent: V54ReactorTheme.gold) {
                        Label(activity.uppercased(), systemImage: "bolt.fill")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(V54ReactorTheme.gold)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = max(0, Int(context.date.timeIntervalSince1970 - startTimestamp))
                            Text(String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60))
                                .font(.system(size: 23, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Button {
                        let start = Date(timeIntervalSince1970: startTimestamp)
                        let minutes = Int(Date().timeIntervalSince(start) / 60)
                        if minutes < 1 {
                            localMessage = "Attends au moins une minute avant d'enregistrer."
                        } else {
                            bridge.finishWorkout(start: start, elapsedMinutes: minutes, activity: activity)
                            startTimestamp = 0
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
                            startTimestamp = 0
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
