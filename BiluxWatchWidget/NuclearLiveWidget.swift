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

// MARK: - BILUX V6.9 / Watch 4.1 · raccourcis de complication
// Pas de valeur XP ou de quête prétendument temps réel : WidgetKit n'a pas
// accès au résumé WCSession sans un partage de données supplémentaire.
private struct V69QuickComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let symbol: String
    let shortName: String
    let detail: String
    let destination: String
    let color: Color

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    Circle().stroke(color.opacity(0.9), lineWidth: 3)
                    VStack(spacing: 1) {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .black))
                        Text(shortName)
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(color)
                }
                .padding(2)
            case .accessoryRectangular:
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BILUX · \(shortName)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                        Text(detail)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            case .accessoryInline:
                Label("BILUX \(shortName)", systemImage: symbol)
            default:
                Label(shortName, systemImage: symbol)
            }
        }
        .widgetURL(URL(string: "biluxwatch://\(destination)"))
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.035, blue: 0.10)
        }
        .accessibilityLabel("BILUX \(shortName), ouvrir \(detail)")
    }
}

struct BILUXXPComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXXPShortcut", provider: NuclearLiveProvider()) { _ in
            V69QuickComplicationView(symbol: "crown.fill", shortName: "XP",
                                     detail: "Profil RPG", destination: "xp",
                                     color: LiveWidgetTheme.gold)
        }
        .configurationDisplayName("BILUX · XP / Profil")
        .description("Raccourci vers le cockpit RPG sur la montre.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct BILUXQuestsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BILUXQuestShortcut", provider: NuclearLiveProvider()) { _ in
            V69QuickComplicationView(symbol: "checkmark.seal.fill", shortName: "QUÊTES",
                                     detail: "Missions du jour", destination: "quests",
                                     color: LiveWidgetTheme.purple)
        }
        .configurationDisplayName("BILUX · Quêtes")
        .description("Raccourci vers les missions RPG sur la montre.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct BILUXWatchWidgetPack: WidgetBundle {
    var body: some Widget {
        NuclearLiveWatchComplication()
        BILUXXPComplication()
        BILUXQuestsComplication()
    }
}
