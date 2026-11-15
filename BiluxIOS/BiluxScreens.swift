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
        .init(id: 1, name: "ÉVEIL", minLevel: 11, subtitle: "L'étincelle intérieure", symbol: "sparkles", accent: Nuclear.gold),
        .init(id: 2, name: "RÉACTEUR", minLevel: 31, subtitle: "Le coeur s'embrase", symbol: "bolt.fill", accent: .orange),
        .init(id: 3, name: "NUCLÉAIRE", minLevel: 56, subtitle: "Le pouvoir rayonne", symbol: "atom", accent: Nuclear.purple),
        .init(id: 4, name: "ASCENSION", minLevel: 81, subtitle: "Au-delà des limites", symbol: "crown.fill", accent: Nuclear.paleGold)
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
// MARK: - BILUX V6.4 · NUCLEAR EVOLUTION / THUNDERSTORM
// Procedural vector lightning: paths are re-generated, split and pulsed in real time.
// This effect has NO HealthKit access, NO timer persisted to disk, and NO XP side effect.
private enum V64StormMastery {
    static func dominantPath(_ data: BiluxData) -> String {
        let branches = V63MasterySnapshot.evaluate(data).branches
        let most = branches.max { $0.unlockedCount < $1.unlockedCount }
        return (most?.unlockedCount ?? 0) > 0 ? (most?.id ?? "core") : "core"
    }
}

private struct V64StormLightning: View {
    let stage: Int
    let masteryCount: Int
    let dominantPath: String
    let epic: Bool

    var body: some View {
        // 24 fps epic, 15 fps balanced; no active timeline when motion is reduced
        // because the caller only creates this overlay if animations are enabled.
        TimelineView(.animation(minimumInterval: epic ? 1.0 / 24.0 : 1.0 / 15.0)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                V64StormRenderer.draw(&context,
                                     size: size,
                                     time: timeline.date.timeIntervalSinceReferenceDate,
                                     stage: stage,
                                     masteryCount: masteryCount,
                                     dominantPath: dominantPath,
                                     epic: epic)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct V64StormRNG {
    private var seed: UInt64
    init(seed: UInt64) { self.seed = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> CGFloat {
        seed = seed &* 2862933555777941757 &+ 3037000493
        return CGFloat(Double(seed >> 11) / 9007199254740992.0)
    }
}

private enum V64StormRenderer {
    private static func colors(path: String, stage: Int) -> (Color, Color) {
        switch path {
        case "force": return (Nuclear.gold, Color(red: 1, green: 0.95, blue: 0.76))
        case "endurance": return (Color(red: 1, green: 0.39, blue: 0.14), Nuclear.gold)
        case "regularity": return (Nuclear.purple, Color(red: 0.63, green: 0.83, blue: 1))
        case "mastery": return (Color(red: 0.79, green: 0.87, blue: 1), Nuclear.paleGold)
        default: return stage >= 3 ? (Nuclear.purple, Nuclear.paleGold) : (Nuclear.gold, Nuclear.purple)
        }
    }

    private static func jagged(start: CGPoint, end: CGPoint, segments: Int,
                               chaos: CGFloat, rng: inout V64StormRNG) -> (Path, [CGPoint]) {
        var path = Path()
        path.move(to: start)
        var points: [CGPoint] = [start]
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(CGFloat(1), hypot(dx, dy))
        let normalX = -dy / distance
        let normalY = dx / distance
        for step in 1...segments {
            let fraction = CGFloat(step) / CGFloat(segments)
            let edgeFalloff = CGFloat(sin(Double.pi * Double(fraction)))
            let offset = (rng.next() - 0.5) * 2.0 * chaos * edgeFalloff
            let point = CGPoint(x: start.x + dx * fraction + normalX * offset,
                                y: start.y + dy * fraction + normalY * offset)
            path.addLine(to: point)
            points.append(point)
        }
        return (path, points)
    }

    private static func stroke(_ path: Path, context: inout GraphicsContext,
                               tint: Color, core: Color, strength: Double,
                               epic: Bool, thin: Bool = false) {
        let scale: CGFloat = thin ? 0.57 : 1.0
        let power = max(0.0, min(1.0, strength))
        guard power > 0.05 else { return }
        // Multiple vector strokes create a colored plasma sheath and a sharp white core.
        // No expensive blur or full-screen white strobe.
        context.stroke(path, with: .color(tint.opacity(power * 0.13)),
                       style: StrokeStyle(lineWidth: (epic ? 13.0 : 8.0) * scale, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(tint.opacity(power * 0.44)),
                       style: StrokeStyle(lineWidth: (epic ? 5.2 : 3.7) * scale, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(core.opacity(power * 0.96)),
                       style: StrokeStyle(lineWidth: (epic ? 1.65 : 1.25) * scale, lineCap: .round, lineJoin: .round))
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, time: TimeInterval,
                     stage: Int, masteryCount: Int, dominantPath: String, epic: Bool) {
        guard size.width > 20, size.height > 20 else { return }
        let palette = colors(path: dominantPath, stage: stage)
        let power = min(12, max(0, masteryCount))
        let intensity = Double(0.71 + 0.032 * Double(min(4, stage)) + 0.014 * Double(power))
        let count = min(epic ? 8 : 5, (epic ? 3 : 2) + min(stage, 4) + power / 4)
        let regenerationRate = epic ? 3.6 : 2.4
        let moment = Int64(floor(time * regenerationRate))
        let drift = CGFloat(sin(time * 1.17))

        // Light shafts at each side of the character. Branches move as the storm regenerates.
        for index in 0..<count {
            let seed = UInt64(bitPattern: moment &* 341873128712 &+ Int64(index) &* 132897987541)
            var rng = V64StormRNG(seed: seed)
            let isLeft = index % 2 == 0
            let startX: CGFloat = isLeft ? 0.02 + rng.next() * 0.27 : 0.70 + rng.next() * 0.27
            let endX: CGFloat = isLeft ? 0.17 + rng.next() * 0.33 : 0.50 + rng.next() * 0.31
            let top: CGFloat = -0.03 + rng.next() * 0.48
            let bottom: CGFloat = min(1.03, top + 0.35 + rng.next() * 0.50)
            let sway = drift * (epic ? 0.022 : 0.013)
            let start = CGPoint(x: (startX + sway) * size.width, y: top * size.height)
            let end = CGPoint(x: (endX + sway) * size.width, y: bottom * size.height)
            let (bolt, nodes) = jagged(start: start, end: end,
                                      segments: epic ? 13 : 9,
                                      chaos: min(size.width, size.height) * (epic ? 0.11 : 0.07), rng: &rng)
            // Slow pulsation with local flicker only. No full-screen flashes.
            let wave = sin(time * 2.0 * Double.pi * (0.72 + Double(index % 3) * 0.11) + Double(index) * 1.65)
            let strength = intensity * (0.29 + 0.65 * pow(max(0.0, wave), 2.0))
            stroke(bolt, context: &context, tint: palette.0, core: palette.1,
                   strength: strength, epic: epic)

            let branches = epic ? 2 : 1
            for branchIndex in 0..<branches {
                let base = 2 + Int(rng.next() * CGFloat(max(1, nodes.count - 5)))
                let anchor = nodes[min(base, nodes.count - 2)]
                let direction: CGFloat = isLeft ? 1.0 : -1.0
                let reach = size.width * (0.075 + rng.next() * 0.14)
                let tip = CGPoint(x: anchor.x + direction * reach,
                                  y: anchor.y + size.height * (0.04 + rng.next() * 0.17))
                let (branch, _) = jagged(start: anchor, end: tip,
                                         segments: 4 + branchIndex, chaos: size.width * 0.045, rng: &rng)
                stroke(branch, context: &context, tint: palette.0, core: palette.1,
                       strength: strength * 0.76, epic: epic, thin: true)
            }
        }

        // Small drifting sparks, not arbitrary flash overlays on the face.
        let sparks = epic ? 18 : 9
        for index in 0..<sparks {
            let seed = UInt64(bitPattern: moment &* 982451653 &+ Int64(index) &* 104729)
            var rng = V64StormRNG(seed: seed)
            let x = (0.08 + rng.next() * 0.84) * size.width
            let y0 = rng.next()
            let speed = 0.014 + Double(rng.next()) * 0.055
            let y = CGFloat((Double(y0) + time * speed).truncatingRemainder(dividingBy: 1.0)) * size.height
            let radius = (epic ? 1.6 : 1.1) + rng.next() * (epic ? 1.6 : 1.0)
            let spark = Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                              width: radius * 2, height: radius * 2))
            context.fill(spark, with: .color(palette.1.opacity((0.18 + 0.38 * Double(rng.next())) * intensity)))
        }
    }
}

private struct NuclearHeroAura: View {
    let level: Int
    let effectsEnabled: Bool
    let stageOverride: NuclearStage?
    let minimumStage: Int
    let masteryCount: Int
    let dominantPath: String
    @State private var stormIsVisible = false
    @AppStorage("bilux.v64.stormIntensity") private var stormIntensity = "epic"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // V5.3.1 : on n'anime JAMAIS la taille du GeometryReader ou de la photo.
    // Seuls les overlays energetiques et l'opacite des portraits sont animes.
    @State private var energized = false
    @State private var outgoingArtwork: String? = nil
    @State private var incomingOpacity: Double = 1
    @State private var fadeTask: Task<Void, Never>? = nil

    init(level: Int, effectsEnabled: Bool, stageOverride: NuclearStage? = nil, minimumStage: Int = 0,
         masteryCount: Int = 0, dominantPath: String = "core") {
        self.level = level
        self.effectsEnabled = effectsEnabled
        self.stageOverride = stageOverride
        self.minimumStage = minimumStage
        self.masteryCount = masteryCount
        self.dominantPath = dominantPath
    }

    private var stage: NuclearStage { stageOverride ?? NuclearStage.current(level: level) }
    private var lockedPreview: Bool { stageOverride != nil && stage.minLevel > level && stage.id > minimumStage }
    private var animate: Bool { effectsEnabled && !reduceMotion && !lockedPreview }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)

            ZStack {
                // Photo entrante dans un rectangle FIXE : aucune deformation d'aspect.
                portrait(stage.artwork, width: width, height: height)
                    .opacity(incomingOpacity)

                // On conserve la photo sortante pendant le fondu uniquement.
                if let outgoingArtwork {
                    portrait(outgoingArtwork, width: width, height: height)
                        .opacity(1 - incomingOpacity)
                }

                LinearGradient(
                    colors: [stage.accent.opacity(0.02),
                             Nuclear.purple.opacity(0.08 + Double(stage.id) * 0.02), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

                // L'animation est LOCALE : elle ne touche pas la geometrie du portrait.
                RadialGradient(
                    colors: [stage.accent.opacity(animate ? 0.22 : 0.10), .clear],
                    center: .center, startRadius: 20, endRadius: 260
                )
                .frame(width: width, height: height)
                .scaleEffect(energized && animate ? 1.12 : 0.94)
                .animation(animate ? .easeInOut(duration: 6.5).repeatForever(autoreverses: true) : nil,
                           value: energized)
                .blendMode(.screen)
                .allowsHitTesting(false)

                Circle()
                    .trim(from: 0.03, to: 0.79)
                    .stroke(
                        AngularGradient(colors: [.clear, stage.accent.opacity(0.86),
                                                 Nuclear.purple, .clear], center: .center),
                        style: StrokeStyle(lineWidth: stage.id >= 3 ? 3.2 : 2.1,
                                           lineCap: .round)
                    )
                    .frame(width: min(width * 0.64, 235), height: min(width * 0.64, 235))
                    .rotationEffect(.degrees(energized && animate ? 24 : -12))
                    .animation(animate ? .easeInOut(duration: 8.0).repeatForever(autoreverses: true) : nil,
                               value: energized)
                    .opacity(lockedPreview ? 0.32 : 0.75)
                    .blendMode(.screen)
                    .allowsHitTesting(false)

                // V6.4 : éclairs vectoriels réellement mouvants, sans bouger ni recadrer l'avatar.
                // Contrôlés par le toggle existant + Réduire les animations d'iOS.
                if animate && stormIsVisible {
                    V64StormLightning(stage: stage.id, masteryCount: masteryCount,
                                     dominantPath: dominantPath,
                                     epic: stormIntensity != "balanced")
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }

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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.72), in: Capsule())
                    }
                    Spacer()
                }
                .padding(12)
            }
            .frame(width: width, height: height)
            .clipped()
        }
        // Surtout PAS de .animation(repeatForever) sur le GeometryReader entier.
        .onAppear { energized = animate; stormIsVisible = true }
        .onChange(of: stage.id) { oldID, _ in
            changePortrait(from: oldID)
        }
        .onChange(of: animate) { _, enabled in
            energized = enabled
            if !enabled {
                fadeTask?.cancel()
                outgoingArtwork = nil
                incomingOpacity = 1
            }
        }
        .onDisappear { fadeTask?.cancel(); stormIsVisible = false }
        .accessibilityLabel("Avatar BILUX : " + stage.name +
                            (lockedPreview ? ", verrouillé" : ", débloqué"))
    }

    private func portrait(_ asset: String, width: CGFloat, height: CGFloat) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .saturation(lockedPreview ? 0.17 : 1)
            .accessibilityHidden(true)
    }

    private func changePortrait(from oldID: Int) {
        fadeTask?.cancel()
        guard animate,
              let former = NuclearStage.all.first(where: { $0.id == oldID }),
              former.artwork != stage.artwork else {
            outgoingArtwork = nil
            incomingOpacity = 1
            return
        }

        // Animation uniquement sur l'opacite (jamais sur frame / scaledToFill).
        outgoingArtwork = former.artwork
        incomingOpacity = 0
        withAnimation(.easeInOut(duration: 1.8)) {
            incomingOpacity = 1
        }
        fadeTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            outgoingArtwork = nil
        }
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
    let legacyStage: Int
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var stage: NuclearStage {
        NuclearStage.all[max(NuclearStage.current(level: level).id, legacyStage)]
    }
    private var newForm: Bool { stage.minLevel == level && stage.id > legacyStage }

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
    @State private var showLegacy = false
    @State private var cinematicStage: NuclearStage? = nil

    private var homeStage: NuclearStage {
        NuclearStage.all.first(where: { $0.id == equippedTransformationID && $0.id <= journal.unlockedStageIndex })
            ?? NuclearStage.all[journal.unlockedStageIndex]
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
                    Button { showLegacy = true } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.title2).foregroundStyle(Nuclear.gold)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("NUCLEAR LEGACY · PROFIL RPG")
                                    .font(.caption.bold()).tracking(0.6).foregroundStyle(Nuclear.paleGold)
                                Text("Titres, auras et emblèmes équipables")
                                    .font(.caption2).foregroundStyle(Nuclear.muted)
                            }
                            Spacer(minLength: 3)
                            Image(systemName: "chevron.right").foregroundStyle(Nuclear.gold)
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15)
                            .stroke(Nuclear.gold.opacity(0.48), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bilux.v59.openLegacy.home")
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
                        quest("Consigner une séance", done: journal.questsToday.workout, xp: "45 XP")
                        quest("Suivre l'alimentation", done: journal.questsToday.meal, xp: "6 XP")
                        quest("Noter ton ressenti", done: journal.questsToday.checkin, xp: "6 XP")
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
            .sheet(isPresented: $showLegacy) {
                BILUXV59LegacyProfile().environmentObject(journal)
            }
            .fullScreenCover(isPresented: $showLevelUp) {
                NuclearLevelUp(level: journal.heroLevel, legacyStage: journal.data.longAscensionAnchor?.legacyStage ?? 0) {
                    lastCelebratedLevel = max(lastCelebratedLevel, journal.heroLevel)
                    showLevelUp = false
                }
            }
            .fullScreenCover(item: $cinematicStage) { stage in
                BILUXV57RankCinema(stage: stage, effectsEnabled: effectsEnabled) {
                    lastCelebratedLevel = max(lastCelebratedLevel, journal.heroLevel)
                    cinematicStage = nil
                }
            }
            .alert("BILUX", isPresented: Binding(get: { health.message != nil }, set: { if !$0 { health.message = nil } })) {
                Button("OK") { health.message = nil }
            } message: { Text(health.message ?? "") }
        }
    }

    private func checkForLevelUp() {
        let level = journal.heroLevel
        guard !showLevelUp && cinematicStage == nil else { return }
        if lastCelebratedLevel == 0 {
            // Première ouverture : pas de cinématique artificielle pour les rangs déjà acquis.
            lastCelebratedLevel = level
        } else if level > lastCelebratedLevel {
            let legacy = journal.data.longAscensionAnchor?.legacyStage ?? 0
            let previousStage = max(NuclearStage.current(level: lastCelebratedLevel).id, legacy)
            let currentStage = journal.unlockedStageIndex
            if currentStage > previousStage {
                cinematicStage = NuclearStage.all[currentStage]
            } else {
                showLevelUp = true
            }
        }
    }

    private var heroPanel: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geometry in
                NuclearHeroAura(level: journal.heroLevel, effectsEnabled: effectsEnabled,
                                stageOverride: homeStage, minimumStage: journal.unlockedStageIndex,
                                masteryCount: V63MasterySnapshot.evaluate(journal.data).unlockedTotal,
                                dominantPath: V64StormMastery.dominantPath(journal.data))
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
                            .animation((effectsEnabled && !reduceMotion) ? .easeInOut(duration: 6.5).repeatForever(autoreverses: true) : .none, value: pulse)
                        Image(systemName: BILUXV59Legacy.activeCrest(journal).symbol)
                            .font(.system(size: 27))
                            .foregroundStyle(BILUXV59Legacy.activeCrest(journal).accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("RANG · \(journal.rankName.uppercased())")
                            .font(.caption2.bold()).tracking(0.7).foregroundStyle(Nuclear.paleGold)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Nuclear.background.opacity(0.77), in: Capsule())
                        Text(BILUXV59Legacy.activeTitle(journal).title)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(BILUXV59Legacy.activeAura(journal).accent)
                            .lineLimit(1).minimumScaleFactor(0.68)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Nuclear.background.opacity(0.8), in: Capsule())
                    }
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
                    Text(journal.heroLevel >= 100 ? "MAÎTRISE ULTIME" : "\(journal.xpToNextLevel) XP avant le prochain niveau")
                        .font(.caption2).foregroundStyle(.white.opacity(0.8))
                }
            }.padding(18)
        }
        .frame(height: 275)
        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(LinearGradient(colors: [Nuclear.paleGold, Nuclear.purple.opacity(0.7), Nuclear.gold.opacity(0.4)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4))
        .overlay {
            BILUXV59AuraFrame(aura: BILUXV59Legacy.activeAura(journal), cornerRadius: 23)
                .allowsHitTesting(false)
        }
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

    private var formIndex: Int { journal.unlockedStageIndex }
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
    @State private var selectedLiveWorkout: WorkoutSession?
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
                            if workout.liveReport != nil {
                                Button { selectedLiveWorkout = workout } label: {
                                    Label("DÉBRIEF NUCLEAR LIVE", systemImage: "chart.bar.fill")
                                        .font(.caption.bold()).frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Nuclear.purple)
                            }
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
            .sheet(item: $selectedLiveWorkout) { workout in
                V62NuclearDebrief(workout: workout)
            }
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
    @AppStorage("bilux.v64.stormIntensity") private var stormIntensity = "epic"
    @State private var showingImporter = false
    @State private var showCodex = false
    @State private var showLegacy = false
    @State private var exportFile: URL?
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @AppStorage("bilux.equippedTransformationID") private var equippedTransformationID = -1
    @State private var selectedStage = 0
    @State private var cinematicStage: NuclearStage? = nil
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    GeometryReader { geometry in
                        NuclearHeroAura(level: journal.heroLevel, effectsEnabled: effectsEnabled,
                                        stageOverride: NuclearStage.all[selectedStage],
                                        minimumStage: journal.unlockedStageIndex,
                                        masteryCount: V63MasterySnapshot.evaluate(journal.data).unlockedTotal,
                                        dominantPath: V64StormMastery.dominantPath(journal.data))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .frame(height: 275)
                    .clipShape(RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(Nuclear.gold.opacity(0.55), lineWidth: 1))
                    .overlay {
                        BILUXV59AuraFrame(aura: BILUXV59Legacy.activeAura(journal), cornerRadius: 19)
                            .allowsHitTesting(false)
                    }
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
                        Text("V5.5 : 45 XP par journée de séance (10 min min., max. 5 jours/semaine), 6 XP par journée de repas ou de ressenti, plus quêtes et boss. Aucun malus de repos.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    }
                    LongAscensionQuestBoard()
                    SectionCaption(title: "Ton héritage nucléaire")
                    NuclearCard {
                        HStack(spacing: 12) {
                            Image(systemName: BILUXV59Legacy.activeCrest(journal).symbol)
                                .font(.title2)
                                .foregroundStyle(BILUXV59Legacy.activeCrest(journal).accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(BILUXV59Legacy.activeTitle(journal).title)
                                    .font(.headline).foregroundStyle(Nuclear.paleGold)
                                Text("Personnalise ton profil : titres, auras et emblèmes")
                                    .font(.caption).foregroundStyle(Nuclear.muted)
                            }
                        }
                        Button { showLegacy = true } label: {
                            Label("OUVRIR LE PROFIL RPG", systemImage: "person.crop.square")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                        .accessibilityIdentifier("bilux.v59.openLegacy.ascension")
                    }
                    SectionCaption(title: "Le Nuclear Codex")
                    NuclearCard {
                        HStack(alignment: .center, spacing: 13) {
                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 33)).foregroundStyle(Nuclear.gold)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("THE NUCLEAR CODEX")
                                    .font(.headline.bold()).foregroundStyle(Nuclear.paleGold)
                                Text("Bestiaire · Trophées · Chroniques · Formes · Secrets")
                                    .font(.caption).foregroundStyle(Nuclear.muted)
                            }
                        }
                        Button { showCodex = true } label: {
                            Label("OUVRIR LE GRIMOIRE", systemImage: "book.closed.fill")
                                .font(.headline.bold()).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    }
                    SectionCaption(title: "Les cinq transformations")
                    Text("Chaque rang a désormais un portrait différent. Une forme déverrouillée peut être équipée ; les rangs futurs restent en aperçu.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(NuclearStage.all) { stage in
                                let unlocked = journal.unlockedStageIndex >= stage.id
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
                        Text(journal.unlockedStageIndex >= stage.id
                             ? (journal.heroLevel < stage.minLevel ? "Forme acquise avant V5.5 · conservée" : "Transformation acquise · niveau \(stage.minLevel)")
                             : "Encore verrouillée · disponible au niveau \(stage.minLevel)")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                        if journal.unlockedStageIndex >= stage.id {
                            Button {
                                equippedTransformationID = stage.id
                            } label: {
                                Label(equippedTransformationID == stage.id || (equippedTransformationID == -1 && journal.unlockedStageIndex == stage.id)
                                      ? "FORME ACTIVE" : "ÉQUIPER CETTE FORME",
                                      systemImage: "bolt.shield.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(stage.accent)
                            .disabled(equippedTransformationID == stage.id)
                            Button {
                                cinematicStage = stage
                            } label: {
                                Label("REVOIR LA CINÉMATIQUE", systemImage: "film.stack.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered).tint(stage.accent)
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
                        Text("TEMPÊTE ÉLECTRIQUE · V6.4")
                            .font(.caption.bold()).foregroundStyle(Nuclear.gold)
                        Picker("Intensité de l'orage", selection: $stormIntensity) {
                            Text("Équilibré").tag("balanced")
                            Text("Épique ⚡").tag("epic")
                        }
                        .pickerStyle(.segmented)
                        .disabled(!effectsEnabled)
                        Text("Arcs électriques mouvants, ramifications et étincelles : la voie de maîtrise dominante modifie leur couleur. Mode Épique activé par défaut. Aucun effet sur les XP.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
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
                let unlocked = NuclearStage.all.first(where: { $0.id == equippedTransformationID && $0.id <= journal.unlockedStageIndex })
                selectedStage = (unlocked ?? NuclearStage.all[journal.unlockedStageIndex]).id
            }
            .sheet(isPresented: $showCodex) {
                BILUXV58Codex().environmentObject(journal)
            }
            .sheet(isPresented: $showLegacy) {
                BILUXV59LegacyProfile().environmentObject(journal)
            }
            .fullScreenCover(item: $cinematicStage) { stage in
                BILUXV57RankCinema(stage: stage, effectsEnabled: effectsEnabled) {
                    cinematicStage = nil
                }
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

// MARK: - BILUX V5.5 · THE LONG ASCENSION · Quêtes vivantes
private struct LongAscensionQuestLine: View {
    let title: String
    let description: String
    let icon: String
    let current: Int
    let target: Int
    let xp: Int
    var tint: Color = Nuclear.gold

    private var progress: Double { Double(min(current, target)) / Double(max(1, target)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: current >= target ? "checkmark.seal.fill" : icon)
                    .foregroundStyle(current >= target ? Color.green : tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                    Text(description).font(.caption2).foregroundStyle(Nuclear.muted)
                }
                Spacer(minLength: 4)
                Text(current >= target ? "ACQUIS" : "+\(xp) XP")
                    .font(.caption2.bold()).foregroundStyle(current >= target ? .green : Nuclear.paleGold)
            }
            ProgressView(value: progress).tint(tint)
            Text("\(min(current, target)) / \(target)")
                .font(.caption2.monospacedDigit()).foregroundStyle(Nuclear.muted)
        }
        .padding(.vertical, 5)
    }
}

private struct LongAscensionQuestBoard: View {
    @EnvironmentObject private var journal: BiluxStore

    var body: some View {
        let quests = BILUXV55Progression.currentQuestProgress(journal.data)
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(title: "Les épreuves de la semaine")
            NuclearCard {
                Text("LA FORGE · QUÊTES HEBDOMADAIRES")
                    .font(.caption.bold()).tracking(1.1).foregroundStyle(Nuclear.paleGold)
                LongAscensionQuestLine(title: "L'épreuve du guerrier",
                    description: "3 jours avec une séance de 10 min ou plus",
                    icon: "dumbbell.fill", current: quests.weeklyWorkouts, target: 3,
                    xp: BILUXV55Progression.weeklyForgeXP)
                LongAscensionQuestLine(title: "Le carburant du réacteur",
                    description: "4 jours d'alimentation notée",
                    icon: "fork.knife", current: quests.weeklyMeals, target: 4,
                    xp: BILUXV55Progression.weeklyNutritionXP, tint: .green)
                LongAscensionQuestLine(title: "Chroniques du survivant",
                    description: "3 jours de ressenti enregistré",
                    icon: "book.closed.fill", current: quests.weeklyCheckins, target: 3,
                    xp: BILUXV55Progression.weeklyJournalXP, tint: Nuclear.purple)
            }
            BILUXV56BossArena()
            if journal.heroLevel >= 100 {
                NuclearCard {
                    Label("MAÎTRISE ULTIME · NIVEAU 100", systemImage: "crown.fill")
                        .font(.headline.bold()).foregroundStyle(Nuclear.paleGold)
                    Text("Le sommet du réacteur est atteint. Ton journal continue après le niveau 100.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }
            }
            Text("Progression permanente. Aucune série obligatoire, aucun malus en repos, aucune XP sur les résultats médicaux. Les quêtes sont validées depuis le journal, une fois par période.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }
}

// MARK: - BILUX V5.6 · L'ARÈNE DES GARDIENS
// Combat symbolique uniquement : le journal V5.5 reste l'unique source des XP.
private enum BILUXV56Boss: String, Identifiable, CaseIterable {
    case guardian
    case sovereign

    var id: String { rawValue }
    var title: String {
        switch self {
        case .guardian: return "LE GARDIEN DU RÉACTEUR"
        case .sovereign: return "LE SOUVERAIN DU NÉANT"
        }
    }
    var subtitle: String {
        switch self {
        case .guardian: return "Sentinelle du noyau · Boss mensuel"
        case .sovereign: return "Maître des ombres · Boss légendaire"
        }
    }
    var legend: String {
        switch self {
        case .guardian: return "Chaque journée de séance fissure l'armure du gardien. Aucun combat n'est perdu pendant tes jours de repos."
        case .sovereign: return "Une épreuve de trois mois : le souverain cède devant la constance, pas devant la précipitation."
        }
    }
    var victoryText: String {
        switch self {
        case .guardian: return "LE CŒUR DU RÉACTEUR EST LIBÉRÉ"
        case .sovereign: return "LE NÉANT RECONNAÎT TON ASCENSION"
        }
    }
    var period: String {
        switch self {
        case .guardian: return "Mois civil en cours"
        case .sovereign: return "Trimestre civil en cours"
        }
    }
    var target: Int { self == .guardian ? 12 : 30 }
    var reward: Int { self == .guardian ? BILUXV55Progression.monthlyBossXP : BILUXV55Progression.legendaryBossXP }
    var symbol: String { self == .guardian ? "shield.lefthalf.filled" : "crown.fill" }
    var artwork: String { self == .guardian ? "BILUXBossGuardian" : "BILUXBossSovereign" }
    var accent: Color { self == .guardian ? Nuclear.purple : Nuclear.gold }

    func countedDays(in data: BiluxData) -> Int {
        let progress = BILUXV55Progression.currentQuestProgress(data)
        return self == .guardian ? progress.monthlyWorkouts : progress.quarterWorkouts
    }
    func phase(for count: Int) -> String {
        if count >= target { return "BOSS VAINCU" }
        let percent = Double(count) / Double(target)
        if percent >= 0.75 { return "PHASE IV · DERNIÈRE RÉSISTANCE" }
        if percent >= 0.50 { return "PHASE III · ARMURE BRISÉE" }
        if percent >= 0.25 { return "PHASE II · NOYAU EXPOSÉ" }
        return "PHASE I · ÉVEIL DU BOSS"
    }
}

private struct BILUXV56BossArena: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var selectedBoss: BILUXV56Boss?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(title: "Arène des gardiens")
            ForEach(BILUXV56Boss.allCases) { boss in
                let count = boss.countedDays(in: journal.data)
                let defeated = count >= boss.target
                Button { selectedBoss = boss } label: {
                    NuclearCard {
                        HStack(alignment: .center, spacing: 12) {
                            Image(boss.artwork)
                                .resizable().scaledToFill()
                                .frame(width: 79, height: 91)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(boss.accent.opacity(0.62), lineWidth: 1))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(boss.subtitle.uppercased())
                                    .font(.system(size: 9, weight: .heavy)).tracking(1)
                                    .foregroundStyle(boss.accent)
                                Text(boss.title)
                                    .font(.subheadline.bold()).foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                Text(boss.phase(for: count))
                                    .font(.caption2.bold())
                                    .foregroundStyle(defeated ? Color.green : Nuclear.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold()).foregroundStyle(Nuclear.muted)
                        }
                        ProgressView(value: Double(min(count, boss.target)), total: Double(boss.target))
                            .tint(boss.accent)
                        HStack {
                            Text("\(min(count, boss.target)) / \(boss.target) journées")
                            Spacer()
                            Text(defeated ? "+\(boss.reward) XP · ACQUIS" : "+\(boss.reward) XP")
                        }
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(Nuclear.paleGold)
                        Label("ENTRER DANS L'ARÈNE", systemImage: "bolt.shield.fill")
                            .font(.system(size: 10, weight: .heavy)).tracking(1)
                            .foregroundStyle(boss.accent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(boss.title), \(min(count, boss.target)) journées sur \(boss.target), \(boss.phase(for: count)). Ouvrir l'arène.")
            }
            Text("Dégâts et victoires calculés depuis les séances de 10 min ou plus : 1 journée par jour, maximum 5 par semaine. Les XP sont attribués automatiquement, une seule fois par période.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
        .sheet(item: $selectedBoss) { boss in
            NavigationStack {
                BILUXV56BossBattle(boss: boss)
                    .environmentObject(journal)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { selectedBoss = nil }
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
    }
}

private struct BILUXV56BossBattle: View {
    let boss: BILUXV56Boss
    @EnvironmentObject private var journal: BiluxStore
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var charged = false
    @State private var revealed = false
    @State private var showVictory = false
    @AppStorage("bilux.v57.guardianVictoryPeriod") private var guardianVictoryPeriod = ""
    @AppStorage("bilux.v57.sovereignVictoryPeriod") private var sovereignVictoryPeriod = ""

    private var periodID: String {
        let parts = Calendar.current.dateComponents([.year, .month], from: .now)
        let year = parts.year ?? 0
        let month = parts.month ?? 1
        return boss == .guardian ? "\(year)-\(month)" : "\(year)-Q\((month - 1) / 3 + 1)"
    }

    private var count: Int { boss.countedDays(in: journal.data) }
    private var defeated: Bool { count >= boss.target }
    private var percent: Double { Double(min(count, boss.target)) / Double(boss.target) }
    private var remaining: Int { max(0, boss.target - count) }
    private var canAnimate: Bool { effectsEnabled && !reduceMotion }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("DOSSIER DE COMBAT · ARÈNE DES GARDIENS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2).foregroundStyle(Nuclear.paleGold)
                    .padding(.top, 8)
                Text(boss.title)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.center).foregroundStyle(.white)

                BILUXV57BossPortrait(boss: boss, defeated: defeated, charged: charged)

                NuclearCard {
                    HStack {
                        Text(defeated ? "PV DU BOSS · 0 %" : "PV DU BOSS · \(Int((1 - percent) * 100)) %")
                            .font(.caption.bold()).foregroundStyle(boss.accent)
                        Spacer()
                        Text(boss.phase(for: count))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Nuclear.paleGold)
                    }
                    ProgressView(value: Double(remaining), total: Double(boss.target))
                        .tint(boss.accent)
                    HStack {
                        Label("\(min(count, boss.target)) / \(boss.target) jours", systemImage: "dumbbell.fill")
                        Spacer()
                        Text(boss.period)
                    }
                    .font(.caption2).foregroundStyle(Nuclear.muted)
                }

                NuclearCard {
                    Text(defeated ? boss.victoryText : "LA BATAILLE CONTINUE")
                        .font(.headline.bold()).foregroundStyle(defeated ? Nuclear.paleGold : .white)
                    Text(defeated
                         ? "Récompense de \(boss.reward) XP déjà calculée par le système de quêtes. Aucun bonus supplémentaire à réclamer."
                         : boss.legend)
                        .font(.subheadline).foregroundStyle(Nuclear.ink)
                    if !defeated {
                        Text("Encore \(remaining) journée\(remaining > 1 ? "s" : "") de séance pour vaincre ce boss, sans limite de séries consécutives.")
                            .font(.caption).foregroundStyle(boss.accent)
                    } else {
                        Button { showVictory = true } label: {
                            Label("REVOIR LA VICTOIRE", systemImage: "crown.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(boss.accent)
                    }
                }
                Text("Aucune action dans cette arène n'ajoute d'XP. Le repos est toujours autorisé et n'inflige aucun dégât à ta progression.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
            }
            .padding(18)
        }
        .background(Nuclear.background.ignoresSafeArea())
        .navigationTitle("Arène")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if canAnimate {
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    charged = true
                }
                withAnimation(.easeOut(duration: 1.4)) { revealed = true }
            } else {
                charged = false
                revealed = true
            }
        }
        .onChange(of: effectsEnabled) { _, enabled in
            if !enabled { charged = false; revealed = true }
        }
        .task(id: defeated) {
            guard defeated else { return }
            let alreadyPlayed = boss == .guardian ? guardianVictoryPeriod : sovereignVictoryPeriod
            guard alreadyPlayed != periodID else { return }
            if boss == .guardian { guardianVictoryPeriod = periodID }
            else { sovereignVictoryPeriod = periodID }
            await Task.yield()
            guard !Task.isCancelled else { return }
            showVictory = true
        }
        .fullScreenCover(isPresented: $showVictory) {
            BILUXV57VictoryCinema(boss: boss) { showVictory = false }
        }
    }
}

// MARK: - BILUX V5.7 · NUCLEAR AWAKENING
// Présentation uniquement : aucun ajout d'XP, aucun changement du journal ou de HealthKit.
private struct BILUXV57RankCinema: View {
    let stage: NuclearStage
    let effectsEnabled: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    private var animated: Bool { effectsEnabled && !reduceMotion }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Nuclear.background.ignoresSafeArea()
                // V5.3.2 : portrait dans un cadre fixe, jamais de scaleEffect sur la photo.
                Image(stage.artwork)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)

                LinearGradient(colors: [Nuclear.background.opacity(0.25), .clear,
                                        Nuclear.background.opacity(0.65), Nuclear.background],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [stage.accent.opacity(phase >= 2 ? 0.37 : 0.10), .clear],
                               center: .center, startRadius: 25, endRadius: 340)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                if animated {
                    V64StormLightning(stage: stage.id, masteryCount: 0,
                                     dominantPath: "core", epic: true)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }

                VStack(spacing: 12) {
                    Text("BILUX · ÉVEIL NUCLÉAIRE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(3).foregroundStyle(Nuclear.paleGold)
                        .padding(.top, 48)
                    Spacer()
                    Image(systemName: stage.symbol)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(stage.accent)
                        .shadow(color: stage.accent.opacity(0.8), radius: phase >= 2 ? 25 : 6)
                        .scaleEffect(phase >= 2 ? 1 : 0.75)
                    Text(phase >= 2 ? "TRANSFORMATION RÉVÉLÉE" : "LE RÉACTEUR S'ÉVEILLE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2).foregroundStyle(Nuclear.paleGold)
                    Text(stage.name)
                        .font(.system(size: 37, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.55).lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: stage.accent.opacity(0.9), radius: 14)
                    Text("RANG · NIVEAU \(stage.minLevel)+")
                        .font(.caption.bold()).tracking(2).foregroundStyle(stage.accent)
                    Text(stage.subtitle)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    Button(action: onDismiss) {
                        Label("CONTINUER L'ASCENSION", systemImage: "bolt.shield.fill")
                            .font(.headline.bold()).frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .padding(.top, 21)
                    .accessibilityIdentifier("bilux.v57.closeRankCinema")
                    Spacer().frame(height: 36)
                }
                .padding(.horizontal, 27)
                .multilineTextAlignment(.center)
                .opacity(phase >= 1 ? 1 : 0.25)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Nuclear.background)
        .task {
            guard animated else { phase = 3; return }
            withAnimation(.easeOut(duration: 1.1)) { phase = 1 }
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.9)) { phase = 2 }
        }
        .accessibilityLabel("Cinématique de transformation, rang \(stage.name)")
    }
}

private struct BILUXV57BossPortrait: View {
    let boss: BILUXV56Boss
    let defeated: Bool
    let charged: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Image(boss.artwork)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(colors: [.clear, Nuclear.background.opacity(0.18),
                                        Nuclear.background.opacity(0.85)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [boss.accent.opacity(charged ? 0.20 : 0.10), .clear],
                               center: .center, startRadius: 15, endRadius: 250)
                    .blendMode(.screen).allowsHitTesting(false)
                    .animation(effectsEnabled && !reduceMotion
                               ? .easeInOut(duration: 6.5) : nil, value: charged)
                HStack(spacing: 8) {
                    Image(systemName: defeated ? "checkmark.seal.fill" : boss.symbol)
                        .foregroundStyle(boss.accent)
                    Text(defeated ? "VICTOIRE" : "ÉPREUVE EN COURS")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1).foregroundStyle(.white)
                }
                .padding(12)
                .background(Nuclear.background.opacity(0.82), in: Capsule())
                .padding(17)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24)
                    .stroke(boss.accent.opacity(0.40), lineWidth: 1.4))
        .accessibilityLabel(defeated ? "Portrait du boss vaincu" : "Portrait de \(boss.title)")
    }
}

private struct BILUXV57VictoryCinema: View {
    let boss: BILUXV56Boss
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @State private var revealed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Nuclear.background.ignoresSafeArea()
                Image(boss.artwork).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped().opacity(0.67)
                    .accessibilityHidden(true)
                LinearGradient(colors: [Nuclear.background.opacity(0.25),
                                        Nuclear.background.opacity(0.47), Nuclear.background],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [boss.accent.opacity(revealed ? 0.4 : 0.1), .clear],
                               center: .center, startRadius: 20, endRadius: 300)
                    .blendMode(.screen).allowsHitTesting(false)
                VStack(spacing: 17) {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 66)).foregroundStyle(Nuclear.paleGold)
                        .shadow(color: Nuclear.gold.opacity(0.8), radius: revealed ? 24 : 8)
                        .scaleEffect(revealed ? 1 : 0.82)
                    Text("BOSS TERRASSÉ")
                        .font(.system(size: 13, weight: .black)).tracking(3)
                        .foregroundStyle(Nuclear.paleGold)
                    Text("VICTOIRE")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: boss.accent.opacity(0.85), radius: 18)
                    Text(boss.title)
                        .font(.title3.bold()).foregroundStyle(boss.accent)
                        .multilineTextAlignment(.center)
                    Text("+\(boss.reward) XP")
                        .font(.title.bold()).foregroundStyle(Nuclear.paleGold)
                    Text("Récompense déjà attribuée automatiquement par ton journal. Revoir cette scène ne rapporte jamais d'XP.")
                        .font(.caption).multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                    Button(action: onDismiss) {
                        Text("RETOURNER À L'ARÈNE").font(.headline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .padding(.top, 14)
                    Spacer().frame(height: 35)
                }
                .padding(.horizontal, 25)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Nuclear.background)
        .onAppear {
            withAnimation(effectsEnabled && !reduceMotion ? .easeOut(duration: 2.2) : nil) {
                revealed = true
            }
        }
        .accessibilityLabel("Victoire sur \(boss.title), \(boss.reward) XP déjà attribués")
    }
}

// MARK: - BILUX V5.8 · THE NUCLEAR CODEX
// Archives de lecture : aucune modification du journal, des XP ou de HealthKit.
private enum BILUXV58CodexTab: String, CaseIterable, Identifiable {
    case bestiary = "Bestiaire"
    case trophies = "Trophées"
    case chronicles = "Chroniques"
    case gallery = "Formes"
    case secrets = "Secrets"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .bestiary: return "shield.lefthalf.filled"
        case .trophies: return "trophy.fill"
        case .chronicles: return "book.closed.fill"
        case .gallery: return "sparkles.rectangle.stack"
        case .secrets: return "lock.open.fill"
        }
    }
}

// Même fenêtre V5.5, même plafond de cinq jours par semaine que le moteur d'XP.
// Sert uniquement à afficher les victoires historiques, jamais à attribuer des XP.
private enum BILUXV58Archive {
    static func eligibleDays(_ data: BiluxData, now: Date = .now) -> [Date] {
        guard let anchor = data.longAscensionAnchor else { return [] }
        let calendar = Calendar.current
        let dates = Set(data.workouts.filter {
            $0.durationMinutes >= 10 && $0.date >= anchor.startedAt && $0.date <= now
        }.map { calendar.startOfDay(for: $0.date) })
        let byWeek = Dictionary(grouping: dates) { day in
            calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? calendar.startOfDay(for: day)
        }
        return byWeek.values.flatMap { Array($0.sorted().prefix(5)) }.sorted()
    }

    static func victories(_ data: BiluxData, against boss: BILUXV56Boss, now: Date = .now) -> Int {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: eligibleDays(data, now: now)) { day -> Date in
            if boss == .guardian {
                return calendar.dateInterval(of: .month, for: day)?.start ?? day
            }
            let components = calendar.dateComponents([.year, .month], from: day)
            let firstMonth = (((components.month ?? 1) - 1) / 3) * 3 + 1
            return calendar.date(from: DateComponents(year: components.year, month: firstMonth, day: 1)) ?? day
        }
        return grouped.values.filter { $0.count >= boss.target }.count
    }

    static func achievements(_ data: BiluxData, level: Int) -> [NuclearAward] {
        let oldAwards = NuclearProgress.awards(data, level: level)
        let guardianWins = victories(data, against: .guardian)
        let sovereignWins = victories(data, against: .sovereign)
        let newAwards: [NuclearAward] = [
            .init(id: "v58-25", name: "VÉTÉRAN DU NOYAU", detail: "25 séances enregistrées", icon: "medal.fill", achieved: data.workouts.count >= 25),
            .init(id: "v58-50", name: "CENTURION", detail: "50 séances enregistrées", icon: "shield.fill", achieved: data.workouts.count >= 50),
            .init(id: "v58-100", name: "CHRONIQUE VIVANTE", detail: "100 séances enregistrées", icon: "book.pages.fill", achieved: data.workouts.count >= 100),
            .init(id: "v58-guardian", name: "BRISEUR DE NOYAU", detail: "Vaincre le Gardien une fois depuis V5.5", icon: "bolt.shield.fill", achieved: guardianWins >= 1),
            .init(id: "v58-sovereign", name: "CONQUÉRANT DU NÉANT", detail: "Vaincre le Souverain une fois depuis V5.5", icon: "crown.fill", achieved: sovereignWins >= 1),
            .init(id: "v58-ultimate", name: "MAÎTRISE ULTIME", detail: "Atteindre le niveau 100", icon: "star.circle.fill", achieved: level >= 100)
        ]
        return oldAwards + newAwards
    }
}

private struct BILUXV58Codex: View {
    @EnvironmentObject private var journal: BiluxStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @State private var activeTab: BILUXV58CodexTab = .bestiary
    @State private var cinematicStage: NuclearStage?

    private var achievements: [NuclearAward] {
        BILUXV58Archive.achievements(journal.data, level: journal.heroLevel)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                        header
                        Section {
                            VStack(alignment: .leading, spacing: 18) {
                                switch activeTab {
                                case .bestiary: bestiary
                                case .trophies: trophies
                                case .chronicles: chronicles
                                case .gallery: gallery
                                case .secrets: secrets
                                }
                                Text("Archives calculées depuis ton journal local. Le Codex ne donne pas d'XP et n'impose aucune série de jours consécutifs.")
                                    .font(.caption2)
                                    .foregroundStyle(Nuclear.muted)
                                    .padding(.bottom, 18)
                            }
                            .id("codex-rubrique")
                        } header: {
                            tabs
                                .padding(.vertical, 8)
                                .background(Nuclear.background.opacity(0.98))
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 17)
                }
                .modifier(PageBackground())
                .onChange(of: activeTab) { _ in
                    withAnimation(.easeOut(duration: 0.18)) {
                        scrollProxy.scrollTo("codex-rubrique", anchor: .top)
                    }
                }
            }
            // V5.8.2 : navigation native dans le Codex, sans seconde sheet imbriquée.
            // Les deux dossiers (Gardien et Souverain) utilisent le même chemin.
            .navigationDestination(for: BILUXV56Boss.self) { boss in
                BILUXV56BossBattle(boss: boss).environmentObject(journal)
            }
            .navigationTitle("Codex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Nuclear.gold)
                }
            }
        }
        .fullScreenCover(item: $cinematicStage) { stage in
            BILUXV57RankCinema(stage: stage, effectsEnabled: effectsEnabled) {
                cinematicStage = nil
            }
        }
    }

    private var header: some View {
        NuclearCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 37))
                    .foregroundStyle(Nuclear.gold)
                    .shadow(color: Nuclear.gold.opacity(0.5), radius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE NUCLEAR CODEX")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .tracking(1.5).foregroundStyle(Nuclear.paleGold)
                    Text("Les archives de ton ascension")
                        .font(.subheadline).foregroundStyle(.white)
                    Text("Ton histoire grandit avec tes actions réelles.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }
            }
            HStack(spacing: 12) {
                codexCounter("TROPHÉES", "\(achievements.filter(\.achieved).count)/\(achievements.count)", "trophy.fill")
                codexCounter("SÉANCES", "\(journal.data.workouts.count)", "dumbbell.fill")
                codexCounter("VICTOIRES", "\(BILUXV58Archive.victories(journal.data, against: .guardian) + BILUXV58Archive.victories(journal.data, against: .sovereign))", "shield.fill")
            }
        }
    }

    private func codexCounter(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(Nuclear.gold).font(.caption)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.system(size: 8, weight: .heavy)).foregroundStyle(Nuclear.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Nuclear.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
    }

    // V5.8.1 : aucun ScrollView horizontal imbriqué. Grandes zones tactiles stables.
    // Les deux lignes restent accessibles lorsque l'utilisateur lit une longue rubrique.
    private var tabs: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                codexTabButton(.bestiary)
                codexTabButton(.trophies)
                codexTabButton(.chronicles)
            }
            HStack(spacing: 8) {
                codexTabButton(.gallery)
                codexTabButton(.secrets)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func codexTabButton(_ tab: BILUXV58CodexTab) -> some View {
        Button {
            guard activeTab != tab else { return }
            activeTab = tab
        } label: {
            Label(tab.rawValue, systemImage: tab.icon)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 5)
                .foregroundStyle(activeTab == tab ? Nuclear.background : Nuclear.paleGold)
                .background(activeTab == tab ? Nuclear.gold : Nuclear.panel,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activeTab == tab ? .isSelected : [])
    }

    // V5.8.2 : navigation directe par NavigationLink pour les deux dossiers.
    private var bestiary: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(title: "Bestiaire nucléaire")
            Text("Deux gardiens, des archives permanentes et des batailles calculées depuis les séances éligibles.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            ForEach(BILUXV56Boss.allCases) { boss in
                let count = boss.countedDays(in: journal.data)
                let wins = BILUXV58Archive.victories(journal.data, against: boss)
                NuclearCard {
                    GeometryReader { geometry in
                        Image(boss.artwork)
                            .resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .accessibilityHidden(true)
                    }
                    .frame(height: 188)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    // V5.8.3 : portraits hors hit testing. Une image recadrée peut
                    // bloquer la touche du dossier précédent avec sa zone invisible.
                    .allowsHitTesting(false)
                    Text(boss.subtitle.uppercased())
                        .font(.system(size: 10, weight: .heavy)).tracking(1.3)
                        .foregroundStyle(boss.accent)
                    Text(boss.title).font(.headline.bold()).foregroundStyle(.white)
                    Text(boss.legend).font(.caption).foregroundStyle(Nuclear.muted)
                    ProgressView(value: Double(min(count, boss.target)), total: Double(boss.target))
                        .tint(boss.accent)
                    HStack {
                        Text("\(min(count, boss.target))/\(boss.target) jours · \(boss.phase(for: count))")
                        Spacer(minLength: 0)
                        Text("\(wins) victoire\(wins > 1 ? "s" : "")")
                    }
                    .font(.caption2.monospacedDigit()).foregroundStyle(Nuclear.paleGold)
                    // V5.8.2 : une destination native par boss, plus de sheet à déclencher.
                    NavigationLink(value: boss) {
                        Label("VOIR LE DOSSIER DE COMBAT", systemImage: "shield.lefthalf.filled")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(boss.accent)
                    .accessibilityIdentifier("bilux.codex.dossier.\(boss.id)")
                }
            }
            Text("Victoires recensées uniquement depuis l'activation de la progression V5.5 ; les victoires antérieures ne sont pas reconstituées.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }

    private var trophies: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "Salle des trophées")
            Text("\(achievements.filter(\.achieved).count) exploits débloqués sur \(achievements.count). Les badges sont calculés depuis ton historique, sans récompense XP additionnelle.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                ForEach(achievements) { achievement in
                    NuclearCard {
                        Image(systemName: achievement.achieved ? achievement.icon : "lock.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(achievement.achieved ? Nuclear.gold : Nuclear.muted)
                        Text(achievement.name)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        Text(achievement.detail)
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(achievement.achieved ? "ACQUIS" : "VERROUILLÉ")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(achievement.achieved ? Nuclear.paleGold : Nuclear.muted)
                    }
                    .opacity(achievement.achieved ? 1 : 0.65)
                }
            }
        }
    }

    private var chronicles: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "Chroniques du survivant")
            Text("Les vingt dernières séances sont retranscrites comme autant de chapitres. Aucun renseignement médical n'est affiché ici.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            let sessions = Array(journal.data.workouts.sorted { $0.date > $1.date }.prefix(20))
            if sessions.isEmpty {
                NuclearCard {
                    Label("LE PREMIER CHAPITRE T'ATTEND", systemImage: "book.closed")
                        .font(.headline).foregroundStyle(Nuclear.paleGold)
                    Text("Enregistre une séance dans La Forge : elle apparaîtra ici, sans saisie supplémentaire.")
                        .font(.subheadline).foregroundStyle(Nuclear.muted)
                }
            } else {
                ForEach(sessions) { session in
                    NuclearCard {
                        HStack {
                            Label(BiluxFormat.day(session.date), systemImage: "book.pages.fill")
                                .font(.caption.bold()).foregroundStyle(Nuclear.gold)
                            Spacer()
                            Text("\(max(0, session.durationMinutes)) min")
                                .font(.caption.monospacedDigit()).foregroundStyle(Nuclear.muted)
                        }
                        Text("CHAPITRE · \(session.activity.uppercased())")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("La Forge garde la trace de cette séance : \(session.exercises.count) exercice\(session.exercises.count > 1 ? "s" : ""), \(BiluxFormat.number(session.volume)) kg·rép de volume consigné.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    }
                }
            }
            if journal.data.workouts.count > 20 {
                Text("Derniers 20 chapitres affichés sur \(journal.data.workouts.count) séances enregistrées.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }
        }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "Galerie des transformations")
            Text("Les cinq formes originales de BILUX. Tu peux revoir la cinématique d'un rang acquis, sans gagner d'XP.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            ForEach(NuclearStage.all) { stage in
                let unlocked = stage.id <= journal.unlockedStageIndex
                NuclearCard {
                    HStack(spacing: 13) {
                        Image(stage.artwork)
                            .resizable().scaledToFill()
                            .frame(width: 100, height: 126)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .saturation(unlocked ? 1 : 0)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 9) {
                            Text(stage.name)
                                .font(.headline.bold()).foregroundStyle(unlocked ? stage.accent : Nuclear.muted)
                            Text(stage.subtitle)
                                .font(.caption).foregroundStyle(.white)
                            Label(unlocked ? "FORME DÉBLOQUÉE" : "NIVEAU \(stage.minLevel) REQUIS", systemImage: unlocked ? "checkmark.seal.fill" : "lock.fill")
                                .font(.caption2.bold()).foregroundStyle(unlocked ? Nuclear.paleGold : Nuclear.muted)
                            if unlocked {
                                Button { cinematicStage = stage } label: {
                                    Label("REVOIR", systemImage: "film.stack.fill")
                                        .font(.caption.bold())
                                }
                                .tint(stage.accent)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var secrets: some View {
        let guardian = BILUXV58Archive.victories(journal.data, against: .guardian)
        let sovereign = BILUXV58Archive.victories(journal.data, against: .sovereign)
        let items: [(title: String, condition: String, unlocked: Bool, story: String, icon: String)] = [
            ("LA PREMIÈRE FAILLE", "Consigner 10 séances", journal.data.workouts.count >= 10,
             "Le métal a cédé pour la première fois. Le survivant comprend que la constance peut fissurer l'impossible.", "bolt.fill"),
            ("LE CHANT DU RÉACTEUR", "Atteindre le niveau 31", journal.heroLevel >= 31,
             "Un battement régulier traverse la Forge : la puissance naît de la maîtrise, non de la précipitation.", "waveform.path"),
            ("L'EMBLÈME DU GARDIEN", "Vaincre le Gardien depuis V5.5", guardian > 0,
             "La sentinelle du noyau reconnaît un adversaire patient. Son emblème entre dans les archives.", "shield.fill"),
            ("LE SCEAU DU NÉANT", "Vaincre le Souverain depuis V5.5", sovereign > 0,
             "La ténacité a traversé une saison entière. Le Néant ne peut effacer ce qui a été construit.", "crown.fill"),
            ("LA PORTE D'ASCENSION", "Atteindre le niveau 81", journal.heroLevel >= 81,
             "Au-delà des rangs connus, un nouveau seuil apparaît. La légende ne fait que commencer.", "sparkles"),
            ("LE NOM ÉTERNEL", "Atteindre le niveau 100", journal.heroLevel >= 100,
             "MAÎTRISE ULTIME. Cent étapes gravées dans le Codex : aucun jour de repos ne les effacera.", "star.circle.fill")
        ]
        return VStack(alignment: .leading, spacing: 13) {
            SectionCaption(title: "Secrets du réacteur")
            Text("Titres et fragments de légende se dévoilent avec le temps. Aucune mission cachée ne rapporte d'XP supplémentaire.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                let item = entry.element
                NuclearCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.unlocked ? item.icon : "lock.fill")
                            .font(.title2).foregroundStyle(item.unlocked ? Nuclear.gold : Nuclear.muted)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(item.unlocked ? item.title : "FRAGMENT SCELLÉ")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(item.unlocked ? Nuclear.paleGold : Nuclear.muted)
                            Text(item.condition)
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                            if item.unlocked {
                                Text(item.story).font(.subheadline).foregroundStyle(.white)
                            } else {
                                Text("Le Codex révélera ce fragment une fois la condition atteinte.")
                                    .font(.caption).foregroundStyle(Nuclear.muted)
                            }
                        }
                    }
                }
                .opacity(item.unlocked ? 1 : 0.67)
            }
        }
    }
}


// MARK: - BILUX V5.9 · NUCLEAR LEGACY
// Le calcul des déblocages réutilise uniquement les exploits du Codex V5.8.
// Aucun nouveau gain d'XP, aucun accès aux renseignements médicaux.
private struct BILUXV59Reward: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let accent: Color
    let unlocked: Bool
}

@MainActor
private enum BILUXV59Legacy {
    static func titles(_ journal: BiluxStore) -> [BILUXV59Reward] {
        let entries = BILUXV58Archive.achievements(journal.data, level: journal.heroLevel)
        return [BILUXV59Reward(id: "initiate", title: "INITIÉ DU NOYAU",
                               detail: "Titre de départ", symbol: "bolt.shield.fill",
                               accent: Nuclear.gold, unlocked: true)]
            + entries.map { award in
                BILUXV59Reward(id: award.id, title: award.name,
                               detail: award.detail, symbol: award.icon,
                               accent: award.id == "v58-sovereign" || award.id == "v58-ultimate"
                                   ? Nuclear.paleGold : Nuclear.purple,
                               unlocked: award.achieved)
            }
    }

    static func auras(_ journal: BiluxStore) -> [BILUXV59Reward] {
        let stage = journal.unlockedStageIndex
        let guardian = BILUXV58Archive.victories(journal.data, against: .guardian)
        let sovereign = BILUXV58Archive.victories(journal.data, against: .sovereign)
        return [
            .init(id: "core", title: "ÉTINCELLE", detail: "Aura initiale", symbol: "sparkle",
                  accent: Nuclear.gold, unlocked: true),
            .init(id: "awakening", title: "AUBE DORÉE", detail: "Débloquer Éveil", symbol: "sun.max.fill",
                  accent: Nuclear.paleGold, unlocked: stage >= 1),
            .init(id: "reactor", title: "CŒUR EN FUSION", detail: "Débloquer Réacteur", symbol: "bolt.circle.fill",
                  accent: .orange, unlocked: stage >= 2),
            .init(id: "guardian", title: "ORAGE DU NOYAU", detail: "Vaincre une fois le Gardien ou débloquer Nucléaire",
                  symbol: "bolt.shield.fill", accent: Nuclear.purple, unlocked: guardian > 0 || stage >= 3),
            .init(id: "sovereign", title: "COURONNE DU NÉANT", detail: "Vaincre le Souverain ou atteindre Ascension",
                  symbol: "crown.fill", accent: .purple, unlocked: sovereign > 0 || stage >= 4),
            .init(id: "ultimate", title: "LUMIÈRE ÉTERNELLE", detail: "Atteindre le niveau 100",
                  symbol: "star.circle.fill", accent: .white, unlocked: journal.heroLevel >= 100)
        ]
    }

    static func crests(_ journal: BiluxStore) -> [BILUXV59Reward] {
        let guardian = BILUXV58Archive.victories(journal.data, against: .guardian)
        let sovereign = BILUXV58Archive.victories(journal.data, against: .sovereign)
        return [
            .init(id: "core", title: "INSIGNE BILUX", detail: "Emblème d'origine", symbol: "crown.fill",
                  accent: Nuclear.gold, unlocked: true),
            .init(id: "veteran", title: "MARQUE DU VÉTÉRAN", detail: "25 séances consignées", symbol: "medal.fill",
                  accent: Nuclear.paleGold, unlocked: journal.data.workouts.count >= 25),
            .init(id: "guardian", title: "SCEAU DU GARDIEN", detail: "Vaincre le boss mensuel", symbol: "shield.fill",
                  accent: Nuclear.purple, unlocked: guardian > 0),
            .init(id: "sovereign", title: "COURONNE DES OMBRES", detail: "Vaincre le boss trimestriel", symbol: "crown.fill",
                  accent: Nuclear.paleGold, unlocked: sovereign > 0),
            .init(id: "ultimate", title: "SCEAU DE L'ASCENSION", detail: "Atteindre le niveau 100",
                  symbol: "star.circle.fill", accent: .white, unlocked: journal.heroLevel >= 100)
        ]
    }

    private static func equipped(_ items: [BILUXV59Reward], _ id: String?) -> BILUXV59Reward {
        items.first(where: { $0.id == id && $0.unlocked }) ?? items[0]
    }
    static func activeTitle(_ journal: BiluxStore) -> BILUXV59Reward {
        equipped(titles(journal), journal.data.legacyLoadout?.titleID)
    }
    static func activeAura(_ journal: BiluxStore) -> BILUXV59Reward {
        equipped(auras(journal), journal.data.legacyLoadout?.auraID)
    }
    static func activeCrest(_ journal: BiluxStore) -> BILUXV59Reward {
        equipped(crests(journal), journal.data.legacyLoadout?.crestID)
    }
}

// Accessible depuis WatchPhoneBridge, sans exposer les catalogues cosmétiques.
@MainActor
func BILUXV60WatchAppearance(_ journal: BiluxStore) -> (title: String, aura: String) {
    (BILUXV59Legacy.activeTitle(journal).title, BILUXV59Legacy.activeAura(journal).title)
}

// La bordure ne redimensionne ni ne recadre jamais les portraits de V5.3.2.
// Les effets sont statiques et ne capturent aucune interaction tactile.
private struct BILUXV59AuraFrame: View {
    let aura: BILUXV59Reward
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(aura.accent.opacity(aura.id == "core" ? 0.20 : 0.88), lineWidth: aura.id == "core" ? 1 : 2.4)
            .shadow(color: aura.accent.opacity(aura.id == "core" ? 0.03 : 0.58),
                    radius: aura.id == "core" ? 2 : 14)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .inset(by: 5)
                    .stroke(aura.accent.opacity(aura.id == "core" ? 0.06 : 0.22), lineWidth: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BILUXV59LegacyProfile: View {
    @EnvironmentObject private var journal: BiluxStore
    @Environment(\.dismiss) private var dismiss

    private var titles: [BILUXV59Reward] { BILUXV59Legacy.titles(journal) }
    private var auras: [BILUXV59Reward] { BILUXV59Legacy.auras(journal) }
    private var crests: [BILUXV59Reward] { BILUXV59Legacy.crests(journal) }
    private var guardianVictories: Int { BILUXV58Archive.victories(journal.data, against: .guardian) }
    private var sovereignVictories: Int { BILUXV58Archive.victories(journal.data, against: .sovereign) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader
                    rebirthCharacterSheet
                    masteryEntry
                    SectionCaption(title: "Titres de légende")
                    Text("Équipe un titre déjà acquis dans la Salle des trophées. Aucun bonus d'XP n'est ajouté.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    VStack(spacing: 9) {
                        ForEach(titles) { item in
                            equipRow(item, equipped: BILUXV59Legacy.activeTitle(journal).id == item.id) {
                                journal.equipLegacyTitle(item.id)
                            }
                        }
                    }
                    SectionCaption(title: "Auras évolutives")
                    Text("L'effet choisi embellit tes portraits sans remplacer leurs illustrations ni accélérer ta progression.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    VStack(spacing: 9) {
                        ForEach(auras) { item in
                            equipRow(item, equipped: BILUXV59Legacy.activeAura(journal).id == item.id) {
                                journal.equipLegacyAura(item.id)
                            }
                        }
                    }
                    SectionCaption(title: "Emblèmes équipables")
                    VStack(spacing: 9) {
                        ForEach(crests) { item in
                            equipRow(item, equipped: BILUXV59Legacy.activeCrest(journal).id == item.id) {
                                journal.equipLegacyCrest(item.id)
                            }
                        }
                    }
                    SectionCaption(title: "Reliques des Gardiens")
                    relicCard(name: "SCEAU DU RÉACTEUR", bossName: "Gardien du Réacteur",
                              imageName: "BILUXBossGuardian", victories: guardianVictories, color: Nuclear.purple)
                    relicCard(name: "COURONNE DU NÉANT", bossName: "Souverain du Néant",
                              imageName: "BILUXBossSovereign", victories: sovereignVictories, color: Nuclear.gold)
                    Text("Les reliques sont attribuées d'après les victoires du Codex depuis la V5.5. Elles n'apportent ni XP supplémentaire ni avantage sportif.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                    Text("Profil sauvegardé dans ton fichier JSON BILUX. Les jours de repos n'entraînent aucune pénalité.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                        .padding(.bottom, 10)
                }
                .padding(16)
            }
            .modifier(PageBackground())
            .navigationTitle("Héritage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .tint(Nuclear.gold)
                }
            }
        }
    }

    // REBIRTH : des statistiques calculées à partir du journal, jamais des XP bonus.
    // V6.3 : entrée stable vers un arbre en lecture seule et calculé localement.
    private var masteryEntry: some View {
        NuclearCard {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title2).foregroundStyle(Nuclear.purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NUCLEAR MASTERY · V6.3")
                        .font(.caption.bold()).tracking(1).foregroundStyle(Nuclear.gold)
                    Text("4 caractéristiques · 12 capacités évolutives")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
            }
            NavigationLink {
                V63NuclearMasteryView().environmentObject(journal)
            } label: {
                Label("OUVRIR L'ARBRE DE MAÎTRISE", systemImage: "arrow.up.right.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Nuclear.purple)
            .accessibilityIdentifier("bilux.v63.mastery.open")
        }
    }

    private var rebirthCharacterSheet: some View {
        let progress = BILUXV55Progression.currentQuestProgress(journal.data)
        let minutes = journal.data.workouts.reduce(0) { $0 + max(0, $1.durationMinutes) }
        return VStack(alignment: .leading, spacing: 10) {
            SectionCaption(title: "Rebirth · Fiche du combattant")
            NuclearCard {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2).foregroundStyle(Nuclear.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HÉRITAGE DU NOYAU")
                            .font(.caption.bold()).tracking(1).foregroundStyle(Nuclear.paleGold)
                        Text("Ta puissance reflète les séances consignées, sans modifier tes XP.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                    }
                }
                HStack(spacing: 8) {
                    statPill("HEURES", "\(minutes / 60) h")
                    statPill("EXERCICES", "\(NuclearProgress.uniqueExercises(journal.data))")
                    statPill("SEMAINE", "\(progress.weeklyWorkouts) / 3")
                }
                Text("PROCHAINE TRANSFORMATION")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Nuclear.gold)
                let stage = journal.unlockedStageIndex
                if stage >= NuclearStage.all.count - 1 {
                    Text("ASCENSION · FORMES MAÎTRISÉES")
                        .font(.caption.bold()).foregroundStyle(Nuclear.paleGold)
                } else {
                    let next = NuclearStage.all[stage + 1]
                    Text("\(next.name) · niveau \(next.minLevel)")
                        .font(.caption.bold()).foregroundStyle(.white)
                    ProgressView(value: Double(journal.heroLevel), total: Double(next.minLevel))
                        .tint(Nuclear.purple)
                }
                Text("Les périodes de repos n'enlèvent ni titres ni niveaux.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }
        }
    }

    private var profileHeader: some View {
        NuclearCard {
            HStack(spacing: 14) {
                Image(NuclearStage.all[journal.unlockedStageIndex].artwork)
                    .resizable().scaledToFill()
                    .frame(width: 110, height: 152)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 8) {
                    Text("REBIRTH · V6.0")
                        .font(.system(size: 10, weight: .heavy)).tracking(1)
                        .foregroundStyle(Nuclear.gold)
                    Text(journal.data.heroName.uppercased())
                        .font(.title2.bold()).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(BILUXV59Legacy.activeTitle(journal).title)
                        .font(.caption.bold()).foregroundStyle(Nuclear.paleGold)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("NIV. \(journal.heroLevel) · \(journal.rankName)", systemImage: "bolt.shield.fill")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    Label(BILUXV59Legacy.activeAura(journal).title, systemImage: "sparkles")
                        .font(.caption2).foregroundStyle(BILUXV59Legacy.activeAura(journal).accent)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                statPill("XP", "\(journal.totalXP)")
                statPill("SÉANCES", "\(journal.data.workouts.count)")
                statPill("VICTOIRES", "\(guardianVictories + sovereignVictories)")
            }
            ProgressView(value: journal.xpFraction).tint(Nuclear.gold)
            Text(journal.heroLevel >= 100 ? "MAÎTRISE ULTIME" : "Encore \(journal.xpToNextLevel) XP jusqu'au prochain niveau")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }

    private func statPill(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(title).font(.system(size: 9, weight: .heavy)).foregroundStyle(Nuclear.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Nuclear.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))
    }

    private func equipRow(_ item: BILUXV59Reward, equipped: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard item.unlocked else { return }
            action()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: item.unlocked ? item.symbol : "lock.fill")
                    .font(.title3).foregroundStyle(item.unlocked ? item.accent : Nuclear.muted)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.unlocked ? item.title : "RÉCOMPENSE VERROUILLÉE")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(item.unlocked ? .white : Nuclear.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.detail)
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 5)
                Image(systemName: equipped ? "checkmark.circle.fill" : (item.unlocked ? "circle" : "lock.fill"))
                    .foregroundStyle(equipped ? Nuclear.gold : Nuclear.muted)
            }
            .padding(.horizontal, 13).padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(equipped ? item.accent.opacity(0.15) : Nuclear.panel,
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(equipped ? item.accent.opacity(0.8) : Nuclear.purple.opacity(0.18), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!item.unlocked || equipped)
        .accessibilityLabel(item.title + (equipped ? ", équipé" : (item.unlocked ? ", équiper" : ", verrouillé")))
    }

    private func relicCard(name: String, bossName: String, imageName: String,
                           victories: Int, color: Color) -> some View {
        NuclearCard {
            HStack(spacing: 12) {
                Image(imageName)
                    .resizable().scaledToFill()
                    .frame(width: 100, height: 110)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .saturation(victories > 0 ? 1 : 0.15)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 8) {
                    Text(victories > 0 ? name : "RELIQUE SCELLÉE")
                        .font(.headline.bold())
                        .foregroundStyle(victories > 0 ? color : Nuclear.muted)
                    Text(bossName)
                        .font(.caption).foregroundStyle(.white)
                    Label(victories > 0 ? "\(victories) victoire\(victories > 1 ? "s" : "")" : "À débloquer",
                          systemImage: victories > 0 ? "checkmark.seal.fill" : "lock.fill")
                        .font(.caption2.bold()).foregroundStyle(victories > 0 ? Nuclear.paleGold : Nuclear.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - BILUX V6.2 — NUCLEAR COMMAND · Débrief post-entraînement
private struct V62NuclearDebrief: View {
    let workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    private var report: NuclearLiveReport? { workout.liveReport }
    private let captions = ["Récupération", "Endurance douce", "Soutenu", "Intense", "Très intense"]

    private func metric(_ label: String, _ value: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Nuclear.gold)
            Text(value).font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.65).lineLimit(1)
            Text(label).font(.system(size: 10)).foregroundStyle(Nuclear.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 13))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    NuclearCard {
                        Text("NUCLEAR COMMAND · RAPPORT DE COMBAT")
                            .font(.caption.bold()).foregroundStyle(Nuclear.gold).tracking(1)
                        Text(workout.activity.uppercased())
                            .font(.system(size: 24, weight: .black, design: .rounded))
                        Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(Nuclear.muted)
                        HStack(spacing: 6) {
                            metric("Durée", "\(workout.durationMinutes) min", symbol: "timer")
                            metric("Kcal actives", report?.activeKcal.map { "\(Int($0.rounded()))" } ?? "—", symbol: "flame.fill")
                        }
                        HStack(spacing: 6) {
                            metric("FC moyenne*", report?.averageBPM.map { String($0) } ?? "—", symbol: "heart.fill")
                            metric("Pic observé*", report?.peakBPM.map { String($0) } ?? "—", symbol: "waveform.path.ecg")
                        }
                    }
                    SectionCaption(title: "Répartition des 5 zones")
                    NuclearCard {
                        if let report {
                            let totals = report.zoneSeconds.count == 5 ? report.zoneSeconds : [0, 0, 0, 0, 0]
                            let maxSeconds = max(1, totals.max() ?? 0)
                            ForEach(0..<5, id: \.self) { index in
                                HStack(spacing: 8) {
                                    Text("Z\(index + 1)")
                                        .font(.caption.bold()).foregroundStyle(Nuclear.gold)
                                        .frame(width: 27, alignment: .leading)
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Nuclear.purple.opacity(0.15))
                                            Capsule()
                                                .fill(index >= 3 ? Nuclear.gold : Nuclear.purple)
                                                .frame(width: max(2, geometry.size.width * CGFloat(totals[index]) / CGFloat(maxSeconds)))
                                        }
                                    }
                                    .frame(height: 9)
                                    Text("\(totals[index]) s")
                                        .font(.caption.monospacedDigit()).foregroundStyle(Nuclear.paleGold)
                                        .frame(width: 45, alignment: .trailing)
                                }
                                Text(captions[index]).font(.system(size: 10)).foregroundStyle(Nuclear.muted)
                            }
                            Text("FC max de référence : \(report.referenceMaxBPM) bpm · \(report.sampleCount) échantillons observés")
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                    }
                    Text("* Moyenne et pic des lectures observées pendant Nuclear Live, non une mesure diagnostique. Les durées en zone sont approximatives : pauses et trous de capteur ne sont pas estimés. Repères indicatifs uniquement.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                    Text("Aucun XP supplémentaire : cette séance compte déjà une seule fois dans ton journal.")
                        .font(.caption2).foregroundStyle(Nuclear.paleGold)
                }
                .padding(16)
            }
            .background(Nuclear.background.ignoresSafeArea())
            .navigationTitle("Débrief Nuclear Live")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

// MARK: - BILUX V6.3 · NUCLEAR MASTERY — Fiche RPG interactive
@MainActor
private struct V63NuclearMasteryView: View {
    @EnvironmentObject private var journal: BiluxStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath = "force"
    @State private var selectedNode: String? = nil

    private var snapshot: V63MasterySnapshot { V63MasterySnapshot.evaluate(journal.data) }
    private var paths: [V63MasteryBranch] { snapshot.branches }
    private var active: V63MasteryBranch { paths.first(where: { $0.id == selectedPath }) ?? paths[0] }

    private func color(_ id: String) -> Color {
        switch id {
        case "force": return Nuclear.gold
        case "endurance": return .orange
        case "regularity": return Nuclear.purple
        default: return Nuclear.paleGold
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    heroHeader
                    SectionCaption(title: "Caractéristiques du combattant")
                    VStack(spacing: 9) {
                        ForEach(paths) { path in attributeRow(path) }
                    }
                    Text("Ces scores reflètent les activités consignées dans BILUX, pas ta force réelle ni ta condition médicale. Aucun XP supplémentaire.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                    SectionCaption(title: "Arbre des quatre voies")
                    HStack(spacing: 6) {
                        ForEach(paths) { path in
                            Button {
                                selectedPath = path.id
                                selectedNode = nil
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: path.icon).font(.system(size: 17))
                                    Text(path.title)
                                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, minHeight: 57)
                                .foregroundStyle(selectedPath == path.id ? Nuclear.background : Nuclear.paleGold)
                                .background(selectedPath == path.id ? color(path.id) : Nuclear.panel,
                                            in: RoundedRectangle(cornerRadius: 13))
                                .contentShape(RoundedRectangle(cornerRadius: 13))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Voie \(path.title), \(path.unlockedCount) capacités débloquées sur 3")
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(active.title)
                                .font(.system(.headline, design: .rounded, weight: .heavy))
                                .foregroundStyle(color(active.id))
                            Spacer()
                            Text("\(active.unlockedCount)/3")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(Nuclear.paleGold)
                        }
                        Text(active.subtitle).font(.caption).foregroundStyle(Nuclear.muted)
                        ForEach(active.nodes) { node in nodeRow(node, tint: color(active.id)) }
                    }
                    .padding(12)
                    .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 16))
                    SectionCaption(title: "Prochaine quête de maîtrise")
                    nextMilestone
                    Text("Les capacités sont des titres et étapes symboliques. Elles se débloquent automatiquement grâce à tes séances existantes. Les journées de repos ne retirent aucun acquis.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                        .padding(.bottom, 12)
                }
                .padding(15)
            }
            .background(Nuclear.background.ignoresSafeArea())
            .navigationTitle("Nuclear Mastery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Retour") { dismiss() }.tint(Nuclear.gold)
                }
            }
    }

    private var heroHeader: some View {
        NuclearCard {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(Nuclear.gold)
                    .frame(width: 44, height: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("NUCLEAR MASTERY · V6.3")
                        .font(.system(size: 10, weight: .heavy)).tracking(1)
                        .foregroundStyle(Nuclear.gold)
                    Text("LES QUATRE VOIES")
                        .font(.title3.bold()).foregroundStyle(.white)
                    Text("\(snapshot.unlockedTotal) / 12 capacités légendaires débloquées")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func attributeRow(_ path: V63MasteryBranch) -> some View {
        NuclearCard {
            HStack(spacing: 9) {
                Image(systemName: path.icon)
                    .frame(width: 20)
                    .foregroundStyle(color(path.id))
                Text(path.title)
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Nuclear.paleGold)
                Spacer(minLength: 4)
                Text("\(path.levelPercent)/100")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            ProgressView(value: min(1, Double(path.current) / Double(max(1, path.ultimateTarget))))
                .tint(color(path.id))
            Text("\(path.current) \(path.unit)")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }

    private func nodeRow(_ node: V63MasteryNode, tint: Color) -> some View {
        Button {
            selectedNode = selectedNode == node.id ? nil : node.id
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 11) {
                    Image(systemName: node.achieved ? node.icon : "lock.fill")
                        .font(.title3)
                        .foregroundStyle(node.achieved ? tint : Nuclear.muted)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title).font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(node.achieved ? .white : Nuclear.muted)
                        Text(node.achieved ? "DÉBLOQUÉ · EXPLOIT ACQUIS" : "SCELLÉ · \(node.current)/\(node.goal)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(node.achieved ? tint : Nuclear.muted)
                    }
                    Spacer(minLength: 2)
                    Image(systemName: selectedNode == node.id ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundStyle(Nuclear.muted)
                }
                ProgressView(value: node.progress).tint(tint)
                if selectedNode == node.id {
                    Text(node.detail).font(.caption).foregroundStyle(Nuclear.paleGold)
                    Text(node.achieved ? "Acquis automatiquement grâce au journal." : "Encore \(node.remaining) avant ce palier.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
            }
            .padding(12)
            .background(Nuclear.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(node.title), \(node.achieved ? "débloqué" : "verrouillé"), afficher les conditions")
    }

    private var nextMilestone: some View {
        NuclearCard {
            if let node = active.next {
                Label(node.title, systemImage: "flag.checkered")
                    .font(.headline).foregroundStyle(Nuclear.paleGold)
                Text(node.detail).font(.caption).foregroundStyle(Nuclear.muted)
                HStack {
                    Text("\(node.current) / \(node.goal) \(active.unit)")
                    Spacer()
                    Text("\(node.remaining) restant(s)")
                }
                .font(.caption2.bold()).foregroundStyle(color(active.id))
                ProgressView(value: node.progress).tint(color(active.id))
            } else {
                Label("VOIE MAÎTRISÉE", systemImage: "checkmark.seal.fill")
                    .font(.headline.bold()).foregroundStyle(Nuclear.gold)
                Text("Les trois capacités de cette voie sont acquises.")
                    .font(.caption).foregroundStyle(Nuclear.muted)
            }
        }
    }
}
