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
        VStack(alignment: .leading, spacing: 6) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(ReactorTheme.panel, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(ReactorTheme.gold.opacity(0.3)))
    }
}

struct WatchRootView: View {
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
