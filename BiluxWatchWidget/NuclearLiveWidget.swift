import SwiftUI
import WidgetKit

// V6.1.1: complication / Smart Stack SHORTCUT only.
// No HealthKit session is started from a glanceable widget.
// A deliberate tap opens the Nuclear Live screen in BILUX Watch.
private struct NuclearLiveEntry: TimelineEntry {
    let date: Date
}

private struct NuclearLiveProvider: TimelineProvider {
    func placeholder(in context: Context) -> NuclearLiveEntry {
        NuclearLiveEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (NuclearLiveEntry) -> Void) {
        completion(NuclearLiveEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NuclearLiveEntry>) -> Void) {
        completion(Timeline(entries: [NuclearLiveEntry(date: .now)], policy: .never))
    }
}

private enum LiveWidgetTheme {
    static let gold = Color(red: 1.0, green: 0.77, blue: 0.32)
    static let purple = Color(red: 0.72, green: 0.37, blue: 1.0)
}

private struct NuclearLiveWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NuclearLiveEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    Circle()
                        .stroke(LiveWidgetTheme.purple.opacity(0.9), lineWidth: 3)
                    VStack(spacing: 1) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .black))
                        Text("LIVE")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(LiveWidgetTheme.gold)
                }
                .padding(2)
                .accessibilityLabel("BILUX Nuclear Live, ouvrir l'entraînement")

            case .accessoryRectangular:
                HStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(LiveWidgetTheme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BILUX")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(LiveWidgetTheme.gold)
                        Text("NUCLEAR LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                        Text("Ouvrir la séance")
                            .font(.system(size: 9, weight: .medium))
                            .opacity(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityLabel("BILUX Nuclear Live, ouvrir l'entraînement")

            case .accessoryInline:
                Label("BILUX Live", systemImage: "bolt.fill")
                    .accessibilityLabel("BILUX Nuclear Live")

            default:
                Label("Nuclear Live", systemImage: "bolt.fill")
            }
        }
        .widgetURL(URL(string: "biluxwatch://live"))
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.035, blue: 0.10)
        }
    }
}

struct NuclearLiveWatchComplication: Widget {
    private let kind = "BILUXNuclearLive"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NuclearLiveProvider()) { entry in
            NuclearLiveWidgetView(entry: entry)
        }
        .configurationDisplayName("BILUX · Nuclear Live")
        .description("Ouvre Nuclear Live depuis le cadran ou la pile intelligente.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// V7.7 — données minimales, lecture seule, pas de commande de traitement.
private struct V77FaceState: Codable {
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
private struct V77Entry: TimelineEntry {
    let date: Date
    let state: V77FaceState?
}
private struct V77Provider: TimelineProvider {
    private func read() -> V77FaceState? {
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bilux.nuclearascension.watchshared"),
              let raw = try? Data(contentsOf: folder.appendingPathComponent("bilux-face-v77.json")), raw.count <= 8192,
              let value = try? JSONDecoder().decode(V77FaceState.self, from: raw),
              value.observedAt != .distantPast, value.observedAt <= Date().addingTimeInterval(120),
              (1...100).contains(value.level), value.fraction.isFinite,
              value.questsTotal >= 0, value.questsDone >= 0, value.questsDone <= value.questsTotal else { return nil }
        return value
    }
    func placeholder(in context: Context) -> V77Entry { V77Entry(date: .now, state: nil) }
    func getSnapshot(in context: Context, completion: @escaping (V77Entry) -> Void) {
        completion(V77Entry(date: .now, state: context.isPreview ? nil : read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<V77Entry>) -> Void) {
        let now = Date(), state = read(), calendar = Calendar.current
        var dates: Set<Date> = [now]
        if let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) { dates.insert(next) }
        if let state {
            let expiry = state.observedAt.addingTimeInterval(4 * 3600)
            if expiry > now { dates.insert(expiry) }
            if let med = state.treatmentObservedAt {
                let end = med.addingTimeInterval(3600)
                if end > now { dates.insert(end) }
            }
        }
        completion(Timeline(entries: dates.sorted().map { V77Entry(date: $0, state: state) }, policy: .after(now.addingTimeInterval(1800))))
    }
}
private enum V77Kind: Equatable { case xp, quests, guardian, treatment }
private struct V77FaceView: View {
    @Environment(\.widgetFamily) private var family
    let entry: V77Entry
    let kind: V77Kind
    private var now: Date { max(entry.date, Date()) }
    private var fresh: Bool {
        guard let s = entry.state else { return false }
        return now.timeIntervalSince(s.observedAt) < 4 * 3600 && Calendar.current.isDate(now, inSameDayAs: s.observedAt)
    }
    private var today: String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }
    private var label: String {
        switch kind { case .xp: return "XP"; case .quests: return "QUÊTES"; case .guardian: return "BOSS"; case .treatment: return "PRISE" }
    }
    private var faceLabel: String {
        guard kind == .treatment, let day = entry.state?.treatmentDay, day.count == 10 else { return label }
        return String(day.suffix(2)) + "/" + String(day.dropFirst(5).prefix(2))
    }
    private var route: String {
        switch kind { case .xp: return "xp"; case .quests: return "quests"; case .guardian: return "guardians"; case .treatment: return "profile" }
    }
    private var symbol: String {
        switch kind { case .xp: return "crown.fill"; case .quests: return "checkmark.seal.fill"; case .guardian: return "shield.fill"; case .treatment: return "pill.fill" }
    }
    private var status: (String, String, Double?) {
        guard let s = entry.state else { return ("—", "Ouvrir BILUX", nil) }
        if kind == .treatment {
            guard s.treatmentDay == today, !s.treatmentPending, let stamp = s.treatmentObservedAt,
                  now.timeIntervalSince(stamp) >= -120, now.timeIntervalSince(stamp) < 3600, Calendar.current.isDate(now, inSameDayAs: stamp), let confirmed = s.treatmentConfirmed else {
                return ("?", s.treatmentDay == today && s.treatmentPending ? "Synchro en attente" : "Vérifier dans BILUX", nil)
            }
            return confirmed ? ("✓", "Confirmée · résumé " + stamp.formatted(date: .omitted, time: .shortened), nil) : ("?", "Non confirmée · vérifier", nil)
        }
        guard fresh else { return ("—", "Résumé à actualiser", nil) }
        switch kind {
        case .xp: return ("N\(s.level)", "\(Int(min(1,max(0,s.fraction))*100)) % du niveau", s.fraction)
        case .quests: return ("\(s.questsDone)/\(s.questsTotal)", "Missions du jour", s.questsTotal > 0 ? Double(s.questsDone)/Double(s.questsTotal) : nil)
        case .guardian:
            guard let done = s.guardiansDone else { return ("—", "Gardien · à synchroniser", nil) }
            let remaining = 12 - min(12,max(0,done))
            return ("\(remaining)/12", "Gardien · jours restants", Double(remaining)/12)
        case .treatment: return ("?", "Vérifier dans BILUX", nil)
        }
    }
    var body: some View {
        let display = status
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    Circle().stroke(LiveWidgetTheme.purple.opacity(0.25), lineWidth: 3)
                    if let p = display.2 { Circle().trim(from: 0, to: CGFloat(min(1,max(0,p)))).stroke(LiveWidgetTheme.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90)) }
                    VStack(spacing: 0) {
                        Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                        Text(display.0).font(.system(size: 13, weight: .black, design: .rounded)).minimumScaleFactor(0.65)
                        Text(faceLabel).font(.system(size: 7, weight: .bold))
                    }.foregroundStyle(LiveWidgetTheme.gold)
                }.padding(2)
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 19, weight: .bold)).foregroundStyle(LiveWidgetTheme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(label) · \(display.0)" + (kind == .treatment ? " · " + faceLabel : "")).font(.system(size: 12, weight: .black))
                        Text(display.1).font(.system(size: 10)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline: Label("\(label) \(display.0)" + (kind == .treatment ? " " + faceLabel : ""), systemImage: symbol)
            default: Label("\(label) \(display.0)", systemImage: symbol)
            }
        }
        .privacySensitive(kind == .treatment)
        .widgetURL(URL(string: "biluxwatch://\(route)"))
        .containerBackground(for: .widget) { Color(red: 0.06, green: 0.035, blue: 0.10) }
        .accessibilityLabel("\(label), \(display.0), \(display.1)")
    }
}
struct BILUXXPComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXXPShortcut", provider: V77Provider()) { V77FaceView(entry: $0, kind: .xp) }
            .configurationDisplayName("BILUX · XP / Profil").description("Dernier niveau synchronisé.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
struct BILUXQuestsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXQuestShortcut", provider: V77Provider()) { V77FaceView(entry: $0, kind: .quests) }
            .configurationDisplayName("BILUX · Quêtes").description("Dernières missions synchronisées.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
struct V77GuardianComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXGuardianV77", provider: V77Provider()) { V77FaceView(entry: $0, kind: .guardian) }
            .configurationDisplayName("BILUX · Gardien").description("Jours restants pour le Gardien du Réacteur, selon le dernier résumé.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
struct V77TreatmentComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXTreatmentV77", provider: V77Provider()) { V77FaceView(entry: $0, kind: .treatment) }
            .configurationDisplayName("BILUX · Confirmation").description("Dernière confirmation synchronisée. Ouvrir BILUX pour vérifier ; ne jamais déduire une dose oubliée du cadran.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
@main
struct BILUXWatchWidgetPack: WidgetBundle {
    var body: some Widget {
        NuclearLiveWatchComplication()
        BILUXXPComplication()
        BILUXQuestsComplication()
        V77GuardianComplication()
        V77TreatmentComplication()
    }
}
