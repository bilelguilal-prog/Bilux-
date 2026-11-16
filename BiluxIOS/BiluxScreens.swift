import SwiftUI
import UniformTypeIdentifiers
import UIKit
import Vision
import CoreImage
import AVFoundation

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

// MARK: - BILUX V6.5 · THUNDER DEPTH / PARALLAX LIGHTNING
// This entire renderer is visual-only. No data writing, training or XP changes.
// On-device Vision foreground lifting lets rear lightning disappear BEHIND the hero.

private enum V65SubjectCutout {
    private static let cache: NSCache<NSString, UIImage> = {
        let object = NSCache<NSString, UIImage>()
        object.totalCostLimit = 45 * 1024 * 1024
        return object
    }()

    static func cached(_ asset: String) -> UIImage? {
        cache.object(forKey: asset as NSString)
    }

    static func request(_ asset: String, completion: @escaping (UIImage?) -> Void) {
        if let existing = cached(asset) {
            DispatchQueue.main.async { completion(existing) }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            var output: UIImage?
            if #available(iOS 17.0, *), let cgImage = UIImage(named: asset)?.cgImage {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNGenerateForegroundInstanceMaskRequest()
                do {
                    try handler.perform([request])
                    if let result = request.results?.first, !result.allInstances.isEmpty {
                        // croppedToInstancesExtent:false is essential: keep exactly the
                        // original artwork's geometry for the scaledToFill duplicate.
                        let buffer = try result.generateMaskedImage(
                            ofInstances: result.allInstances,
                            from: handler,
                            croppedToInstancesExtent: false)
                        let image = CIImage(cvPixelBuffer: buffer)
                        let context = CIContext(options: [.useSoftwareRenderer: false])
                        if let visible = context.createCGImage(image, from: image.extent) {
                            let lifted = UIImage(cgImage: visible)
                            cache.setObject(lifted, forKey: asset as NSString,
                                            cost: visible.bytesPerRow * visible.height)
                            output = lifted
                        }
                    }
                } catch {
                    // Artwork with no detectable foreground: safe edge-only fallback.
                }
            }
            DispatchQueue.main.async { completion(output) }
        }
    }
}

private enum V65StormPlane {
    case back
    case front
}

private struct V65DepthLightning: View {
    let stage: Int
    let masteryCount: Int
    let dominantPath: String
    let epic: Bool
    let plane: V65StormPlane

    var body: some View {
        TimelineView(.animation(minimumInterval: epic ? 1.0 / 24.0 : 1.0 / 15.0)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                V65ThunderRenderer.draw(&context, size: size,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    stage: stage, masteryCount: masteryCount,
                    dominantPath: dominantPath, epic: epic, plane: plane)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum V65ThunderRenderer {
    private static func palette(_ path: String, stage: Int) -> (Color, Color) {
        switch path {
        case "force": return (Nuclear.gold, Color(red: 1, green: 0.98, blue: 0.82))
        case "endurance": return (Color(red: 1, green: 0.48, blue: 0.13), Nuclear.paleGold)
        case "regularity": return (Nuclear.purple, Color(red: 0.80, green: 0.88, blue: 1))
        case "mastery": return (Color(red: 0.46, green: 0.72, blue: 1), Color.white)
        default: return (stage >= 3 ? Nuclear.purple : Nuclear.gold,
                         stage >= 3 ? Nuclear.paleGold : Nuclear.purple)
        }
    }

    private static func jagged(from a: CGPoint, to b: CGPoint,
                               count: Int, chaos: CGFloat, rng: inout V64StormRNG) -> [CGPoint] {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let distance = max(1, hypot(dx, dy))
        let nx = -dy / distance
        let ny = dx / distance
        var points: [CGPoint] = [a]
        for i in 1..<count {
            let t = CGFloat(i) / CGFloat(count)
            let jag = (rng.next() - 0.5) * 2 * chaos * sin(t * .pi)
            points.append(CGPoint(x: a.x + dx * t + nx * jag,
                                  y: a.y + dy * t + ny * jag))
        }
        points.append(b)
        return points
    }

    private static func route(_ points: [CGPoint]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() { p.addLine(to: point) }
        return p
    }

    private static func flash(_ path: Path, context: inout GraphicsContext,
                              color: Color, core: Color, strength: Double,
                              front: Bool, epic: Bool, branch: Bool = false) {
        guard strength > 0.055 else { return }
        let scale: CGFloat = branch ? 0.46 : (front ? 1.0 : 1.25)
        let thick: CGFloat = epic ? 16.0 : 11.0
        context.stroke(path, with: .color(color.opacity(strength * (front ? 0.24 : 0.16))),
                       style: StrokeStyle(lineWidth: thick * scale, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(color.opacity(strength * 0.73)),
                       style: StrokeStyle(lineWidth: (epic ? 5.8 : 4.2) * scale,
                                          lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(core.opacity(strength * (front ? 1.0 : 0.83))),
                       style: StrokeStyle(lineWidth: (epic ? 2.05 : 1.5) * scale,
                                          lineCap: .round, lineJoin: .round))
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    // V6.6 · CINEMATIC STORM
    // The renderer is stateless: deterministic seeds lock one geometry for the
    // entire discharge. Rhythm is SHARED between rear/front layers so that at
    // most three main bolts can overlap in Epic mode (two rear, one foreground).
    // Deliberate silent phases avoid the frantic strobe visible in V6.5.
    private static func cinematicEnvelope(age: Double, lifetime: Double) -> Double {
        guard age >= 0, age < lifetime else { return 0 }
        let attack = min(1.0, age / 0.075)
        if age < 0.31 { return attack }
        let decay = max(0, 1.0 - (age - 0.31) / (lifetime - 0.31))
        return pow(decay, 1.35)
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, time: TimeInterval,
                     stage: Int, masteryCount: Int, dominantPath: String,
                     epic: Bool, plane: V65StormPlane) {
        guard size.width > 35, size.height > 35 else { return }
        let isFront = plane == .front
        let colors = palette(dominantPath, stage: stage)
        let progress = min(12, max(0, masteryCount))
        let magnitude = min(1.0, 0.79 + Double(stage) * 0.033 + Double(progress) * 0.008)

        // One coherent storm burst, not independent, high-speed flash generators.
        // Epic: 3 main strikes per 2.18 s, lasting 0.73 s each; roughly 0.7 s
        // of breathing room after the last strike. Balanced is quieter still.
        let cycleLength: Double = epic ? 2.18 : 3.05
        let cycle = Int64(floor(time / cycleLength))
        let phase = time - Double(cycle) * cycleLength
        let count = isFront ? 1 : (epic ? 2 : 1)
        let lifetime: Double = epic ? 0.73 : 0.60

        for index in 0..<count {
            let seed = cycle &* 16777619 &+ Int64(index) &* 741103597
                &+ (isFront ? 9176 : 231)
            var rng = V64StormRNG(seed: UInt64(bitPattern: seed))
            let offset: Double
            if isFront {
                offset = epic ? 0.38 : 0.57
            } else {
                offset = index == 0 ? 0.07 : 0.73
            }
            // Stable per-burst variation, not a random trajectory every frame.
            let startAt = offset + Double(rng.next()) * 0.055
            let age = phase - startAt
            let envelope = cinematicEnvelope(age: age, lifetime: lifetime)
            guard envelope > 0.045 else { continue }

            let fromLeft = ((cycle + Int64(index)).isMultiple(of: 2)) != isFront
            let start: CGPoint
            let end: CGPoint
            if isFront {
                // Rare, prominent bolt from outer shoulder to lower reactor.
                start = point(fromLeft ? -0.09 : 1.09,
                              0.67 + rng.next() * 0.10, size)
                end = point(fromLeft ? 0.46 : 0.54,
                            0.74 + rng.next() * 0.15, size)
            } else {
                // Long lightning bolt in the STORM BEHIND the hero. Vision's
                // foreground cutout hides this layer behind head/shoulders.
                start = point(fromLeft ? -0.09 : 1.09,
                              -0.12 + rng.next() * 0.38, size)
                end = point(fromLeft ? 0.59 : 0.41,
                            0.60 + rng.next() * 0.32, size)
            }

            let points = jagged(from: start, to: end, count: epic ? 17 : 13,
                                chaos: min(size.width, size.height)
                                    * (isFront ? 0.085 : 0.13), rng: &rng)
            // Keep the bright core briefly vivid, then a slower visible glow.
            // No rapid 100%-20%-80%-0% restrike sequence as in V6.5.
            let core = age < 0.19 ? 1.0 : 0.80
            let strength = magnitude * envelope * core
                * (isFront ? 0.89 : (index == 1 ? 0.87 : 1.0))
            flash(route(points), context: &context, color: colors.0,
                  core: colors.1, strength: strength,
                  front: isFront, epic: epic)

            // Two branches MAX in Epic (instead of three in V6.5).
            for branchID in 0..<(epic ? 2 : 1) {
                let available = max(4, points.count - 4)
                let base = 2 + Int(rng.next() * CGFloat(available - 2))
                let anchor = points[min(base, points.count - 2)]
                let dx = (fromLeft ? 1.0 : -1.0) * (0.08 + rng.next() * 0.15)
                let dy = 0.04 + rng.next() * 0.14
                let tip = CGPoint(x: anchor.x + dx * size.width,
                                  y: anchor.y + dy * size.height)
                let branchPoints = jagged(from: anchor, to: tip,
                                          count: 5 + branchID,
                                          chaos: size.width * 0.042, rng: &rng)
                flash(route(branchPoints), context: &context,
                      color: colors.0, core: colors.1,
                      strength: strength * 0.54, front: isFront,
                      epic: epic, branch: true)
            }
        }

        // One restrained reactor shockwave every fifth EPIC burst.
        // It lives in the rear/front split rather than scribbling across the face.
        if epic && cycle.isMultiple(of: 5) {
            let age = phase - 1.54
            let shock = cinematicEnvelope(age: age, lifetime: 0.36)
            if shock > 0.08 {
                let seed = cycle &* 31337 &+ (isFront ? 17 : 11)
                var rng = V64StormRNG(seed: UInt64(bitPattern: seed))
                let center = point(0.50, 0.83, size)
                var orbit: [CGPoint] = []
                for i in 0...12 {
                    let fraction = CGFloat(i) / 12
                    let angle = (isFront ? CGFloat(0.05) : CGFloat.pi) + fraction * .pi
                    let jitter = (rng.next() - 0.5) * size.width * 0.027
                    orbit.append(CGPoint(x: center.x + cos(angle) * (size.width * 0.37 + jitter),
                                         y: center.y + sin(angle) * size.height * 0.09))
                }
                flash(route(orbit), context: &context, color: colors.0,
                      core: colors.1, strength: magnitude * shock
                        * (isFront ? 0.38 : 0.22),
                      front: isFront, epic: epic)
            }
        }
    }
}

// Composite in ORIGINAL artwork coordinates; no movement, rescaling or crop of the hero.
// Rear discharge -> Vision-cut hero -> rare foreground lightning.
private struct V65DepthCompositing: View {
    let artwork: String
    let stage: Int
    let masteryCount: Int
    let dominantPath: String
    let epic: Bool
    let width: CGFloat
    let height: CGFloat
    @State private var visibleArtwork = ""
    @State private var liftedHero: UIImage?

    var body: some View {
        ZStack {
            V65DepthLightning(stage: stage, masteryCount: masteryCount,
                              dominantPath: dominantPath, epic: epic, plane: .back)
                .blur(radius: epic ? 1.8 : 2.8)
                .blendMode(.screen)
                .mask {
                    if liftedHero != nil {
                        Color.white
                    } else {
                        // Vision unavailable: keep background bolts on the OUTER
                        // edges only, rather than drawing through the face.
                        LinearGradient(stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.13),
                            .init(color: .clear, location: 0.38),
                            .init(color: .clear, location: 0.62),
                            .init(color: .white, location: 0.87),
                            .init(color: .white, location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
                }

            if let liftedHero {
                Image(uiImage: liftedHero)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .accessibilityHidden(true)
            }

            V65DepthLightning(stage: stage, masteryCount: masteryCount,
                              dominantPath: dominantPath, epic: epic, plane: .front)
                .blendMode(.screen)
        }
        .frame(width: width, height: height)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { load(artwork) }
        .onChange(of: artwork) { _, newAsset in load(newAsset) }
    }

    private func load(_ asset: String) {
        visibleArtwork = asset
        liftedHero = V65SubjectCutout.cached(asset)
        guard liftedHero == nil else { return }
        V65SubjectCutout.request(asset) { lifted in
            guard visibleArtwork == asset else { return }
            liftedHero = lifted
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

                // V6.5 : foudre arrière OCCULTÉE par le personnage détouré automatiquement
                // (Vision, sur l'iPhone), puis décharges rares au premier plan.
                // Aucune animation de la taille/cadre du portrait et aucun recalcul d'XP.
                if animate && stormIsVisible && outgoingArtwork == nil {
                    V65DepthCompositing(artwork: stage.artwork, stage: stage.id,
                                        masteryCount: masteryCount,
                                        dominantPath: dominantPath,
                                        epic: stormIntensity != "balanced",
                                        width: width, height: height)
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
    @State private var showImmersion = false

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
                        .overlay(alignment: .bottomTrailing) {
                            V72CoreSeal(stageIndex: journal.unlockedStageIndex,
                                        masteryTotal: V63MasterySnapshot.evaluate(journal.data).unlockedTotal)
                                .frame(width: 76, height: 76)
                                .padding(13)
                                .allowsHitTesting(false)
                        }
                    V70RebirthCommandDeck().environmentObject(journal)
                    Button { showImmersion = true } label: {
                        Label("CONTEMPLER MON PERSONNAGE", systemImage: "viewfinder")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 45)
                    }
                    .buttonStyle(.bordered)
                    .tint(Nuclear.paleGold)
                    .accessibilityIdentifier("bilux.v67.openImmersion.home")
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
            .fullScreenCover(isPresented: $showImmersion) {
                BILUXV67Contemplation(stage: homeStage, level: journal.heroLevel,
                    masteryCount: V63MasterySnapshot.evaluate(journal.data).unlockedTotal,
                    dominantPath: V64StormMastery.dominantPath(journal.data),
                    effectsEnabled: effectsEnabled) { showImmersion = false }
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
                    V70ForgeSportEntry().environmentObject(journal)
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
    @State private var showImmersion = false
    @AppStorage("bilux.v67.soundEnabled") private var immersionSound = false
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
                    Button { showImmersion = true } label: {
                        Label("MODE CONTEMPLATION · PLEIN ÉCRAN", systemImage: "viewfinder")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Nuclear.gold)
                    .disabled(selectedStage > journal.unlockedStageIndex)
                    .accessibilityIdentifier("bilux.v67.openImmersion.ascension")
                    V72AwakeningEntry().environmentObject(journal)
                    V73EternalForgeEntry().environmentObject(journal)
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
                        Toggle("Ambiance sonore cinématique", isOn: $immersionSound)
                            .tint(Nuclear.gold)
                        Text("Sons nucléaires originaux, optionnels et désactivés par défaut. Le mode Silence de l’iPhone est respecté. Aucun son en arrière-plan.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                        Text("NUCLEAR IMMERSION · V6.7")
                            .font(.caption.bold()).foregroundStyle(Nuclear.gold)
                        Picker("Intensité de l'orage", selection: $stormIntensity) {
                            Text("Équilibré").tag("balanced")
                            Text("Épique ⚡").tag("epic")
                        }
                        .pickerStyle(.segmented)
                        .disabled(!effectsEnabled)
                        Text("Mode Épique cinématique : trois décharges principales au maximum par rafale, environ 0,7 seconde de présence et de vraies accalmies. La foudre reste derrière ou devant la silhouette grâce au détourage Apple Vision lorsque disponible. Aucun bonus d’XP.")
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
            .fullScreenCover(isPresented: $showImmersion) {
                BILUXV67Contemplation(stage: NuclearStage.all[selectedStage],
                    level: journal.heroLevel,
                    masteryCount: V63MasterySnapshot.evaluate(journal.data).unlockedTotal,
                    dominantPath: V64StormMastery.dominantPath(journal.data),
                    effectsEnabled: effectsEnabled) { showImmersion = false }
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
// MARK: - BILUX V6.7 · NUCLEAR IMMERSION
// Purely visual and optional audio: never reads/writes the workout journal or XP.
// Reuses the existing V6.6 storm engine, V6.5 foreground depth, and V5.7 cinematics.

private enum BILUXV67Sound: Hashable {
    case awakening
    case impact
    case reactor

    var duration: Double {
        switch self {
        case .awakening: return 2.2
        case .impact: return 1.45
        case .reactor: return 0.90
        }
    }
}

@MainActor
private final class BILUXV67Audio: ObservableObject {
    private var player: AVAudioPlayer?
    private var generated: [BILUXV67Sound: Data] = [:]

    func play(_ kind: BILUXV67Sound, enabled: Bool) {
        guard enabled else { return }
        do {
            // Ambient respects iPhone silent mode and mixes with other audio.
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            let audio = generated[kind] ?? Self.makeWAV(kind)
            if generated[kind] == nil { generated[kind] = audio }
            let next = try AVAudioPlayer(data: audio)
            next.volume = kind == .impact ? 0.36 : 0.26
            player?.stop()
            player = next
            next.prepareToPlay()
            next.play()
        } catch {
            // An audio failure never prevents use of the app or the cinema.
        }
    }

    func stop() { player?.stop(); player = nil }

    // Original short, synthetic thunder/energy sounds. No bundled media, no network.
    private static func makeWAV(_ kind: BILUXV67Sound) -> Data {
        let sampleRate = 22_050
        let totalFrames = Int(kind.duration * Double(sampleRate))
        let sampleBytes = UInt32(totalFrames * 2)
        var data = Data(capacity: 44 + Int(sampleBytes))
        func appendTag(_ string: String) { data.append(contentsOf: string.utf8) }
        func append16(_ value: UInt16) {
            data.append(UInt8(truncatingIfNeeded: value))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func append32(_ value: UInt32) {
            data.append(UInt8(truncatingIfNeeded: value))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
            data.append(UInt8(truncatingIfNeeded: value >> 16))
            data.append(UInt8(truncatingIfNeeded: value >> 24))
        }
        appendTag("RIFF"); append32(36 + sampleBytes); appendTag("WAVE")
        appendTag("fmt "); append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2))
        append16(2); append16(16); appendTag("data"); append32(sampleBytes)
        var seed: UInt64 = 0xCBF29CE484222325
        var lowNoise = 0.0
        for index in 0..<totalFrames {
            let t = Double(index) / Double(sampleRate)
            seed = seed &* 2862933555777941757 &+ 3037000493
            let whiteNoise = Double((seed >> 32) & 0xFFFF_FFFF) / 4_294_967_295.0 * 2 - 1
            lowNoise = lowNoise * 0.985 + whiteNoise * 0.015
            let falloff = pow(max(0.0, 1.0 - t / kind.duration), 1.6)
            let attack = min(1.0, t / (kind == .impact ? 0.018 : 0.095))
            let bass = sin(2 * Double.pi * (51 * t + 3.8 * t * t))
            let drone = sin(2 * Double.pi * 92 * t) * sin(2 * Double.pi * 1.5 * t)
            let noiseLevel = kind == .impact ? 2.2 : 1.45
            let level = (bass * 0.35 + drone * 0.12 + lowNoise * noiseLevel + whiteNoise * 0.045)
                * falloff * attack
            let bounded = max(-1.0, min(1.0, level))
            let sample = Int16(Int((bounded * 24_000.0).rounded()))
            append16(UInt16(bitPattern: sample))
        }
        return data
    }
}

// Slowly breathing energy plus a one-second manual discharge; not another strobe.
private struct BILUXV67ReactorHalo: View {
    let accent: Color
    let active: Bool
    let lastImpulse: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                paused: !active || reduceMotion)) { tick in
            let clock = tick.date.timeIntervalSinceReferenceDate
            let breath = active && !reduceMotion ? (sin(clock * 1.65) + 1) * 0.5 : 0.2
            let elapsed = tick.date.timeIntervalSince(lastImpulse)
            let impulse = active && !reduceMotion ? max(0.0, 1.0 - max(0, elapsed) / 1.1) : 0.0
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(0.26 + breath * 0.12 + impulse * 0.24),
                                                  accent.opacity(0.065), .clear],
                                         center: .center, startRadius: 4, endRadius: 130))
                Circle()
                    .stroke(accent.opacity(0.40 + breath * 0.21 + impulse * 0.27),
                            lineWidth: 2.0 + impulse * 2.2)
                    .padding(45)
                    .scaleEffect(CGFloat(0.96 + breath * 0.055 + impulse * 0.13))
                Circle()
                    .trim(from: 0.09, to: 0.61)
                    .stroke(AngularGradient(colors: [.clear, accent, Nuclear.paleGold, .clear],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(active && !reduceMotion ? clock * 8 : 0))
                    .padding(64)
                    .opacity(0.43 + breath * 0.27)
                if impulse > 0.01 {
                    Circle()
                        .stroke(Nuclear.paleGold.opacity(impulse * 0.70), lineWidth: 1.9)
                        .scaleEffect(CGFloat(0.34 + (1.0 - impulse) * 0.88))
                        .padding(35)
                }
            }
            .compositingGroup()
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// The avatar can be contemplated without toolbars, and tapped to release an
// energy pulse. The exit button stays visible for discoverability/accessibility.
private struct BILUXV67Contemplation: View {
    let stage: NuclearStage
    let level: Int
    let masteryCount: Int
    let dominantPath: String
    let effectsEnabled: Bool
    let onDismiss: () -> Void

    @AppStorage("bilux.v64.stormIntensity") private var stormIntensity = "epic"
    @AppStorage("bilux.v67.soundEnabled") private var soundEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = BILUXV67Audio()
    @State private var lastImpulse = Date.distantPast
    @State private var showControls = true

    private var animated: Bool { effectsEnabled && !reduceMotion }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Nuclear.background.ignoresSafeArea()
                Image(stage.artwork)
                    .resizable().scaledToFill()
                    .frame(width: w, height: h)
                    .clipped().accessibilityHidden(true)
                if animated {
                    V65DepthCompositing(artwork: stage.artwork, stage: stage.id,
                                        masteryCount: masteryCount, dominantPath: dominantPath,
                                        epic: stormIntensity != "balanced", width: w, height: h)
                }
                BILUXV67ReactorHalo(accent: stage.accent, active: animated,
                                    lastImpulse: lastImpulse)
                    .frame(width: min(w * 0.68, 290), height: min(w * 0.68, 290))
                    .position(x: w * 0.52, y: h * 0.74)
                LinearGradient(colors: [Nuclear.background.opacity(0.51), .clear,
                                        .clear, Nuclear.background.opacity(0.76)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
                Button(action: unleash) {
                    Circle().fill(.clear)
                        .frame(width: min(w * 0.52, 220), height: min(w * 0.52, 220))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(x: w * 0.52, y: h * 0.74)
                .accessibilityLabel("Déclencher une impulsion du réacteur")
                .accessibilityIdentifier("bilux.v67.reactorPulse")

                VStack(spacing: 12) {
                    HStack {
                        if showControls {
                            Text("NUCLEAR IMMERSION")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(2.0).foregroundStyle(Nuclear.paleGold)
                        }
                        Spacer()
                        Button(action: onDismiss) {
                            Label("FERMER", systemImage: "xmark.circle.fill")
                                .font(.caption.bold()).foregroundStyle(.white)
                                .padding(10)
                                .background(.black.opacity(0.64), in: Capsule())
                        }
                        .accessibilityIdentifier("bilux.v67.closeImmersion")
                    }
                    .padding(.top, 13)
                    Spacer()
                    if showControls {
                        Text("RANG " + stage.name)
                            .font(.system(size: 13, weight: .black)).tracking(3.0)
                            .foregroundStyle(stage.accent)
                        Text("NIVEAU \(level)")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("TOUCHE LE RÉACTEUR POUR LIBÉRER UNE IMPULSION")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.9).multilineTextAlignment(.center)
                            .foregroundStyle(Nuclear.paleGold)
                        HStack(spacing: 12) {
                            Button { unleash() } label: {
                                Label("DÉCHARGE", systemImage: "bolt.fill")
                            }
                            Button { soundEnabled.toggle(); if !soundEnabled { audio.stop() } } label: {
                                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            }
                            .accessibilityLabel(soundEnabled ? "Couper les sons" : "Activer les sons")
                        }
                        .font(.subheadline.bold())
                        .buttonStyle(.borderedProminent)
                        .tint(stage.accent)
                        .padding(.top, 7)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.24)) { showControls.toggle() }
                    } label: {
                        Label(showControls ? "MASQUER L'INTERFACE" : "AFFICHER L'INTERFACE",
                              systemImage: showControls ? "eye.slash" : "eye")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.bordered).tint(Nuclear.paleGold)
                    .padding(.bottom, 22)
                }
                .padding(.horizontal, 22)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .background(Nuclear.background)
        .onAppear { audio.play(.awakening, enabled: soundEnabled) }
        .onDisappear { audio.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { audio.stop() }
        }
        .accessibilityLabel("Mode contemplation du rang \(stage.name)")
    }

    private func unleash() {
        guard animated else { return }
        lastImpulse = .now
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        audio.play(.reactor, enabled: soundEnabled)
    }
}

// Three-beat reveal: ignition, compression, then emergence. It is also used for
// replays of unlocked transformations; replays never award any new XP.
private struct BILUXV57RankCinema: View {
    let stage: NuclearStage
    let effectsEnabled: Bool
    let onDismiss: () -> Void

    @AppStorage("bilux.v67.soundEnabled") private var soundEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = BILUXV67Audio()
    @State private var phase = 0
    @State private var lastImpulse = Date.distantPast

    private var animated: Bool { effectsEnabled && !reduceMotion }

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            ZStack {
                Nuclear.background.ignoresSafeArea()
                Image(stage.artwork)
                    .resizable().scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
                    .accessibilityHidden(true)
                if animated && phase >= 1 {
                    V65DepthCompositing(artwork: stage.artwork, stage: stage.id,
                                        masteryCount: 0, dominantPath: "core", epic: true,
                                        width: w, height: h)
                }
                BILUXV67ReactorHalo(accent: stage.accent, active: animated && phase >= 1,
                                    lastImpulse: lastImpulse)
                    .frame(width: min(w * 0.69, 290), height: min(w * 0.69, 290))
                    .position(x: w * 0.52, y: h * 0.74)
                LinearGradient(colors: [Nuclear.background.opacity(phase == 0 ? 0.75 : 0.33),
                                        .clear, Nuclear.background.opacity(0.56), Nuclear.background],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 13) {
                    HStack {
                        Text("BILUX · NUCLEAR IMMERSION")
                            .font(.system(size: 10, weight: .black)).tracking(2.2)
                            .foregroundStyle(Nuclear.paleGold)
                        Spacer()
                        Button("PASSER") { audio.stop(); onDismiss() }
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(9)
                            .background(.black.opacity(0.60), in: Capsule())
                            .accessibilityIdentifier("bilux.v67.skipCinema")
                    }
                    .padding(.top, 20)
                    Spacer()
                    Image(systemName: stage.symbol)
                        .font(.system(size: 50, weight: .black))
                        .foregroundStyle(stage.accent)
                        .shadow(color: stage.accent.opacity(0.82), radius: phase >= 2 ? 25 : 7)
                        .scaleEffect(phase >= 2 ? 1.0 : 0.82)
                    Text(phase < 2 ? "LE NOYAU SE CHARGE" : "TRANSFORMATION RÉVÉLÉE")
                        .font(.system(size: 11, weight: .black)).tracking(2)
                        .foregroundStyle(Nuclear.paleGold)
                    Text(stage.name)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.60).lineLimit(1)
                        .shadow(color: stage.accent.opacity(0.7), radius: 12)
                    Text("RANG · NIVEAU \(stage.minLevel)+")
                        .font(.caption.bold()).tracking(1.5).foregroundStyle(stage.accent)
                    Text(stage.subtitle)
                        .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    Button {
                        audio.stop(); onDismiss()
                    } label: {
                        Label("CONTINUER L'ASCENSION", systemImage: "bolt.shield.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .disabled(animated && phase < 3)
                    .opacity(animated && phase < 3 ? 0.56 : 1)
                    .padding(.top, 18)
                    .accessibilityIdentifier("bilux.v57.closeRankCinema")
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 25)
                .multilineTextAlignment(.center)
                .opacity(animated && phase == 0 ? 0.50 : 1)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .background(Nuclear.background)
        .task {
            guard animated else { phase = 3; return }
            audio.play(.awakening, enabled: soundEnabled)
            try? await Task.sleep(nanoseconds: 580_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.65)) { phase = 1 }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.72)) { phase = 2; lastImpulse = .now }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            audio.play(.impact, enabled: soundEnabled)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.45)) { phase = 3 }
        }
        .onDisappear { audio.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { audio.stop() }
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

// MARK: - BILUX V7.0 · NUCLEAR REBIRTH
// Extension non destructive de l'interface. Lit le journal existant ;
// seule la Forge utilise BiluxStore.add(WorkoutSession) pour enregistrer une séance.
// Aucun calcul d'XP, aucune migration, aucun accès médical ni HealthKit ici.

private enum V70RebirthStyle {
    static let gold = Nuclear.gold
    static let purple = Nuclear.purple
    static let light = Nuclear.paleGold
    static let secondary = Nuclear.muted
    static let background = Nuclear.panel

    static func weight(_ value: Double) -> String {
        BiluxFormat.number(value, digits: 1)
    }
    static func name(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}

private struct V70TrainingRecord: Identifiable {
    let exercise: String
    let maxWeight: Double
    let reps: Int
    let date: Date
    var id: String { V70RebirthStyle.name(exercise) }
}

private struct V70PeriodBucket: Identifiable {
    let firstDay: Date
    let label: String
    let sessions: Int
    let minutes: Int
    let volume: Double
    var id: Date { firstDay }
}

private struct V70PerformanceSnapshot {
    let all: [WorkoutSession]
    let sessions: [WorkoutSession]
    let days: Int
    let startDate: Date
    let endDate: Date

    init(_ workouts: [WorkoutSession], days: Int, now: Date = .now) {
        let calendar = Calendar.current
        self.days = days
        self.endDate = now
        let today = calendar.startOfDay(for: now)
        let periodStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        self.startDate = periodStart
        self.all = workouts
        self.sessions = workouts.filter { $0.date >= periodStart && $0.date <= now }
    }

    var count: Int { sessions.count }
    var totalMinutes: Int { sessions.reduce(0) { $0 + min(1440, max(0, $1.durationMinutes)) } }
    var totalVolume: Double { sessions.reduce(0) { $0 + max(0, $1.volume.isFinite ? $1.volume : 0) } }
    var trainedDays: Int { Set(sessions.map { Calendar.current.startOfDay(for: $0.date) }).count }
    var strengthSessions: Int {
        sessions.filter { item in
            let activity = V70RebirthStyle.name(item.activity)
            return activity.contains("musculation") || activity.contains("strength") || activity.contains("force") || activity.contains("poids")
        }.count
    }

    var records: [V70TrainingRecord] {
        var best: [String: V70TrainingRecord] = [:]
        for session in all where session.date <= endDate {
            for exercise in session.exercises {
                let key = V70RebirthStyle.name(exercise.name)
                guard !key.isEmpty else { continue }
                for set in exercise.sets where set.weight.isFinite && set.weight > 0 && set.reps > 0 {
                    if let current = best[key], current.maxWeight >= set.weight { continue }
                    best[key] = .init(exercise: exercise.name, maxWeight: set.weight,
                                      reps: set.reps, date: session.date)
                }
            }
        }
        return best.values.sorted { $0.maxWeight > $1.maxWeight }
    }

    // Cinq à neuf colonnes selon la période ; pas d'extrapolation de HealthKit.
    var buckets: [V70PeriodBucket] {
        let step = days == 7 ? 1 : (days == 30 ? 5 : 10)
        let cal = Calendar.current
        return stride(from: 0, to: days, by: step).map { offset in
            let start = cal.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let stop = cal.date(byAdding: .day, value: step, to: start) ?? endDate
            let items = sessions.filter { $0.date >= start && $0.date < stop }
            let label = days == 7
                ? start.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "fr_FR")))
                : start.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
            return V70PeriodBucket(firstDay: start, label: label, sessions: items.count,
                                  minutes: items.reduce(0) { $0 + max(0, $1.durationMinutes) },
                                  volume: items.reduce(0) { $0 + max(0, $1.volume) })
        }
    }
}

private struct V70RebirthTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(2)
            Text(value)
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.34), lineWidth: 1))
    }
}

// Carte QG insérée après le portrait cinématique existant, sans en changer les effets.
private struct V70RebirthCommandDeck: View {
    @EnvironmentObject private var journal: BiluxStore

    private var week: V70PerformanceSnapshot {
        V70PerformanceSnapshot(journal.data.workouts, days: 7)
    }
    private var month: V70PerformanceSnapshot {
        V70PerformanceSnapshot(journal.data.workouts, days: 30)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NUCLEAR REBIRTH · V7.0")
                        .font(.caption2.weight(.black)).tracking(2).foregroundStyle(Nuclear.purple)
                    Text("CENTRE DE COMMANDEMENT")
                        .font(.headline.weight(.black)).foregroundStyle(Nuclear.paleGold)
                }
                Spacer(minLength: 8)
                Image(systemName: "atom")
                    .font(.system(size: 24, weight: .medium)).foregroundStyle(Nuclear.gold)
                    .accessibilityHidden(true)
            }
            V73EternalForgeEntry().environmentObject(journal)
            V72AwakeningEntry().environmentObject(journal)
            HStack(spacing: 9) {
                V70RebirthTile(title: "SÉANCES / 7 J", value: "\(week.count)",
                               symbol: "dumbbell.fill", color: Nuclear.gold)
                V70RebirthTile(title: "MINUTES / 7 J", value: "\(week.totalMinutes)",
                               symbol: "clock.fill", color: Nuclear.purple)
            }
            HStack(spacing: 9) {
                V70RebirthTile(title: "VOLUME / 30 J", value: BiluxFormat.number(month.totalVolume),
                               symbol: "scalemass.fill", color: Nuclear.purple)
                V70RebirthTile(title: "RECORDS", value: "\(month.records.count)",
                               symbol: "trophy.fill", color: Nuclear.gold)
            }
            VStack(spacing: 10) {
                NavigationLink {
                    V70NuclearForge().environmentObject(journal)
                } label: {
                    Label("ENTRER DANS LA FORGE", systemImage: "hammer.fill")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(Nuclear.gold)
                .accessibilityIdentifier("bilux.v70.forge.home")

                NavigationLink {
                    V70NuclearAnalytics().environmentObject(journal)
                } label: {
                    Label("ANALYSES DU COMBATTANT", systemImage: "chart.xyaxis.line")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered)
                .tint(Nuclear.purple)
                .accessibilityIdentifier("bilux.v70.analytics.home")

                NavigationLink {
                    V71ExercisePerformance().environmentObject(journal)
                } label: {
                    Label("PROGRESSION PAR EXERCICE", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered).tint(Nuclear.gold)

                NavigationLink {
                    V71AscensionChronicleView().environmentObject(journal)
                } label: {
                    Label("JOURNAL DE L'ASCENSION", systemImage: "book.closed.fill")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.bordered).tint(Nuclear.purple)
            }
            Text("Statistiques issues du journal de séances, sans score de santé ni XP ajouté.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
        .padding(15)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(colors: [Nuclear.panel, Nuclear.background],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 17)
            .stroke(LinearGradient(colors: [Nuclear.gold.opacity(0.85), Nuclear.purple.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
    }
}

private struct V70ForgeSportEntry: View {
    @EnvironmentObject private var journal: BiluxStore
    var body: some View {
        NuclearCard {
            Text("LA FORGE DU COMBATTANT · V7.0")
                .font(.caption.bold()).tracking(1.3).foregroundStyle(Nuclear.gold)
            Text("Construis une séance série par série, compare tes charges et retrouve tes records.")
                .font(.caption).foregroundStyle(Nuclear.muted)
            NavigationLink {
                V70NuclearForge().environmentObject(journal)
            } label: {
                Label("SAISIR UNE SÉANCE DE MUSCULATION", systemImage: "dumbbell.fill")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.borderedProminent).tint(Nuclear.gold)
            NavigationLink {
                V70NuclearAnalytics().environmentObject(journal)
            } label: {
                Label("VOIR LES STATISTIQUES", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.bordered).tint(Nuclear.purple)
            V73EternalForgeEntry().environmentObject(journal)
            NavigationLink {
                V71ExercisePerformance().environmentObject(journal)
            } label: {
                Label("PROGRESSION PAR EXERCICE", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 42)
            }.buttonStyle(.bordered).tint(Nuclear.gold)
            NavigationLink {
                V71AscensionChronicleView().environmentObject(journal)
            } label: {
                Label("JOURNAL DE L'ASCENSION", systemImage: "book.closed.fill")
                    .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 42)
            }.buttonStyle(.bordered).tint(Nuclear.purple)
        }
    }
}

private struct V70DraftSet: Identifiable {
    var id: UUID = UUID()
    var reps: String = "10"
    var weight: String = "0"
}

private struct V70NuclearForge: View {
    @EnvironmentObject private var journal: BiluxStore
    @Environment(\.dismiss) private var dismiss
    var launch: V73ForgeLaunch? = nil

    @State private var sessionDate = Date()
    @State private var duration = "60"
    @State private var notes = ""
    @State private var rpe: Int = 6
    @State private var exerciseName = ""
    @State private var draftSets: [V70DraftSet] = [V70DraftSet()]
    @State private var prepared: [WorkoutExercise] = []
    @State private var errorText: String?
    @State private var saved = false
    @State private var achievedRecords: [String] = []
    @State private var programLinkWarning: String?
    @State private var showRecordCelebration = false
    @State private var restUntil: Date?

    private var knownRecords: [String: Double] {
        var result: [String: Double] = [:]
        for workout in journal.data.workouts {
            for exercise in workout.exercises {
                let key = V70RebirthStyle.name(exercise.name)
                for set in exercise.sets where set.weight.isFinite && set.weight > 0 && set.reps > 0 {
                    result[key] = max(result[key] ?? 0, set.weight)
                }
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("NUCLEAR FORGE", systemImage: "hammer.fill")
                        .font(.title2.weight(.black)).foregroundStyle(Nuclear.gold)
                    Text("Une séance, plusieurs exercices, autant de séries que nécessaire.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }
                NuclearCard {
                    DatePicker("Date", selection: $sessionDate, in: ...Date(), displayedComponents: .date)
                    HStack {
                        Text("Durée (min)").font(.subheadline)
                        Spacer()
                        TextField("60", text: $duration).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(width: 64)
                    }
                    HStack {
                        Text("Effort perçu").font(.subheadline)
                        Spacer()
                        Stepper("\(rpe)/10", value: $rpe, in: 1...10)
                            .labelsHidden()
                        Text("\(rpe)/10").foregroundStyle(Nuclear.gold)
                            .font(.subheadline.monospacedDigit())
                    }
                    TextField("Notes de séance (facultatif)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if !prepared.isEmpty {
                    SectionCaption(title: "Exercices préparés")
                    ForEach(prepared) { exercise in
                        NuclearCard {
                            HStack {
                                Text(exercise.name).font(.subheadline.bold())
                                Spacer()
                                Text("\(exercise.sets.count) séries")
                                    .font(.caption).foregroundStyle(Nuclear.paleGold)
                            }
                            Text(exercise.sets.map {
                                "\($0.reps) × \(V70RebirthStyle.weight($0.weight)) kg"
                            }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Retirer cet exercice", role: .destructive) {
                                prepared.removeAll { $0.id == exercise.id }
                            }.font(.caption)
                        }
                    }
                }

                if !saved {
                    SectionCaption(title: "Exercice en cours")
                    NuclearCard {
                        TextField("Nom de l'exercice", text: $exerciseName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(false)
                        if let old = knownRecords[V70RebirthStyle.name(exerciseName)] {
                            Label("Charge max enregistrée : \(V70RebirthStyle.weight(old)) kg", systemImage: "trophy.fill")
                                .font(.caption).foregroundStyle(Nuclear.gold)
                        }
                        ForEach($draftSets) { $set in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.hexagongrid.fill")
                                    .font(.caption).foregroundStyle(Nuclear.purple)
                                TextField("Rép.", text: $set.reps)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Charge kg", text: $set.weight)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                if draftSets.count > 1 {
                                    Button(role: .destructive) {
                                        draftSets.removeAll { $0.id == set.id }
                                    } label: { Image(systemName: "minus.circle.fill") }
                                        .accessibilityLabel("Retirer la série")
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            Button {
                                if draftSets.count < 12 { draftSets.append(V70DraftSet()) }
                            } label: { Label("+ SÉRIE", systemImage: "plus.circle") }
                                .disabled(draftSets.count >= 12)
                            Spacer()
                            Button("REPOS 90 S") { restUntil = Date().addingTimeInterval(90) }
                        }
                        .buttonStyle(.bordered).tint(Nuclear.purple)
                        if let restUntil {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let seconds = max(0, Int(restUntil.timeIntervalSince(context.date).rounded(.up)))
                                HStack {
                                    Label("Repos indicatif : \(seconds) s", systemImage: "timer")
                                        .font(.caption.bold()).foregroundStyle(Nuclear.paleGold)
                                    Spacer()
                                    Button("Arrêter") { self.restUntil = nil }.font(.caption)
                                }
                            }
                        }
                        Button {
                            addPreparedExercise()
                        } label: {
                            Label("VALIDER CET EXERCICE", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered).tint(Nuclear.gold)
                        .disabled(prepared.count >= 25)
                    }
                }

                NuclearCard {
                    if saved {
                        Label("SÉANCE ENREGISTRÉE", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(Nuclear.gold)
                        if let programLinkWarning {
                            Text(programLinkWarning)
                                .font(.caption).foregroundStyle(Nuclear.purple)
                        }
                        if !achievedRecords.isEmpty {
                            Label("RECORD BRISÉ ⚡", systemImage: "bolt.fill")
                                .font(.title3.weight(.black)).foregroundStyle(Nuclear.purple)
                            ForEach(achievedRecords, id: \.self) { item in
                                Text(item).font(.subheadline).foregroundStyle(Nuclear.paleGold)
                            }
                        }
                        Button("RETOUR AU JOURNAL") { dismiss() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    } else {
                        Button {
                            saveSession()
                        } label: {
                            Label("ENREGISTRER LA SÉANCE", systemImage: "square.and.arrow.down.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                        Text("Une seule séance est ajoutée au journal. XP et quêtes restent calculés par BILUX.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                    }
                }
            }
            .padding(15)
        }
        .navigationTitle("La Forge")
        .sheet(isPresented: $showRecordCelebration) {
            V71RecordCelebration(records: achievedRecords)
        }
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .onAppear(perform: prefillFromProgram)
        .alert("Vérifie la séance", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK") { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func prefillFromProgram() {
        guard let launch, !saved, prepared.isEmpty,
              exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        prepared = launch.day.exercises.map { target in
            let sets = (0..<target.sets).map { _ in
                WorkoutSet(reps: target.reps, weight: target.weight)
            }
            return WorkoutExercise(name: target.name, sets: sets)
        }
        duration = String(launch.day.durationMinutes)
        notes = "Programme : \(launch.planName) · \(launch.day.title)"
    }

    private func makeCurrentExercise() -> WorkoutExercise? {
        let name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !draftSets.isEmpty else { return nil }
        var sets: [WorkoutSet] = []
        for draft in draftSets {
            guard let reps = Int(draft.reps), (1...300).contains(reps),
                  let weight = Double(draft.weight.replacingOccurrences(of: ",", with: ".")),
                  weight.isFinite, (0...1000).contains(weight) else { return nil }
            sets.append(WorkoutSet(reps: reps, weight: weight))
        }
        return WorkoutExercise(name: name, sets: sets)
    }

    private func addPreparedExercise() {
        guard let exercise = makeCurrentExercise() else {
            errorText = "Indique un nom d'exercice, des répétitions de 1 à 300 et une charge entre 0 et 1 000 kg."
            return
        }
        prepared.append(exercise)
        exerciseName = ""
        draftSets = [V70DraftSet()]
        restUntil = nil
    }

    private func saveSession() {
        guard !saved else { return }
        guard let minutes = Int(duration), (1...1440).contains(minutes) else {
            errorText = "La durée doit être comprise entre 1 et 1 440 minutes."
            return
        }
        var exercises = prepared
        if !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let current = makeCurrentExercise() else {
                errorText = "L'exercice en cours comporte une série ou une charge invalide."
                return
            }
            exercises.append(current)
        }
        guard !exercises.isEmpty, exercises.count <= 25 else {
            errorText = "Ajoute au moins un exercice avant d'enregistrer la séance."
            return
        }
        let previous = knownRecords
        var newRecords: [String] = []
        for exercise in exercises {
            let bestWeight = exercise.sets.map(\.weight).max() ?? 0
            let old = previous[V70RebirthStyle.name(exercise.name)] ?? 0
            if bestWeight > 0 && bestWeight > old {
                newRecords.append("\(exercise.name) · \(V70RebirthStyle.weight(bestWeight)) kg")
            }
        }
        let savedWorkout = WorkoutSession(date: sessionDate, activity: "Musculation",
                                           durationMinutes: minutes, notes: notes, rpe: rpe,
                                           exercises: exercises)
        journal.add(savedWorkout)
        if let launch {
            do {
                try V73LedgerStore.link(launch, to: savedWorkout)
            } catch {
                programLinkWarning = "Séance enregistrée mais non reliée à la campagne : \(error.localizedDescription)"
            }
        }
        achievedRecords = Array(Set(newRecords)).sorted()
        saved = true
        showRecordCelebration = !achievedRecords.isEmpty
    }
}

private struct V70NuclearAnalytics: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var period = 30
    private var data: V70PerformanceSnapshot {
        V70PerformanceSnapshot(journal.data.workouts, days: period)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NUCLEAR ANALYTICS · V7.0")
                            .font(.caption2.bold()).tracking(1.5).foregroundStyle(Nuclear.purple)
                        Text("STATISTIQUES DU COMBATTANT")
                            .font(.title3.weight(.black)).foregroundStyle(Nuclear.paleGold)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2).foregroundStyle(Nuclear.gold)
                }
                Picker("Période", selection: $period) {
                    Text("7 jours").tag(7)
                    Text("30 jours").tag(30)
                    Text("90 jours").tag(90)
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    V70RebirthTile(title: "SÉANCES", value: "\(data.count)",
                                   symbol: "dumbbell.fill", color: Nuclear.gold)
                    V70RebirthTile(title: "MINUTES", value: "\(data.totalMinutes)",
                                   symbol: "clock.fill", color: Nuclear.purple)
                    V70RebirthTile(title: "VOLUME*", value: "\(BiluxFormat.number(data.totalVolume))",
                                   symbol: "scalemass.fill", color: Nuclear.purple)
                    V70RebirthTile(title: "JOURS ACTIFS", value: "\(data.trainedDays)",
                                   symbol: "calendar", color: Nuclear.gold)
                }

                NuclearCard {
                    SectionCaption(title: "Rythme d'entraînement")
                    let buckets = data.buckets
                    let maxCount = max(1, buckets.map(\.sessions).max() ?? 0)
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(buckets) { bucket in
                            VStack(spacing: 4) {
                                Text("\(bucket.sessions)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Nuclear.paleGold)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(bucket.sessions == 0 ? Nuclear.purple.opacity(0.15) : Nuclear.gold)
                                    .frame(height: CGFloat(max(5.0, 85.0 * Double(bucket.sessions) / Double(maxCount))))
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                Text(bucket.label)
                                    .font(.system(size: period == 7 ? 10 : 8, weight: .medium))
                                    .foregroundStyle(Nuclear.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 122)
                    Text("Nombre de séances consignées par période, sans estimation des séances non enregistrées.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }

                NuclearCard {
                    SectionCaption(title: "Bilan du réacteur")
                    HStack {
                        Label("Musculation", systemImage: "bolt.shield.fill")
                        Spacer()
                        Text("\(data.strengthSessions) séances").foregroundStyle(Nuclear.gold)
                    }
                    HStack {
                        Label("Durée moyenne", systemImage: "clock")
                        Spacer()
                        Text(data.count == 0 ? "—" : "\(data.totalMinutes / data.count) min")
                            .foregroundStyle(Nuclear.gold)
                    }
                    HStack {
                        Label("Charge cumulée*", systemImage: "sum")
                        Spacer()
                        Text("\(BiluxFormat.number(data.totalVolume)) kg·rép")
                            .foregroundStyle(Nuclear.gold)
                    }
                    Text("* Volume = répétitions × charge déclarée, pour les exercices saisis ; les séances Watch sans séries détaillées ne contribuent pas au volume.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }

                NuclearCard {
                    SectionCaption(title: "Records · historique complet")
                    if data.records.isEmpty {
                        Text("Aucune charge saisie pour le moment. La Forge permet d'enregistrer tes séries.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    } else {
                        ForEach(Array(data.records.prefix(10))) { record in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "trophy.fill").foregroundStyle(Nuclear.gold)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.exercise).font(.subheadline.weight(.semibold))
                                    Text("\(record.reps) répétition(s) · \(BiluxFormat.day(record.date))")
                                        .font(.caption2).foregroundStyle(Nuclear.muted)
                                }
                                Spacer(minLength: 4)
                                Text("\(V70RebirthStyle.weight(record.maxWeight)) kg")
                                    .font(.subheadline.weight(.heavy)).foregroundStyle(Nuclear.paleGold)
                            }
                        }
                    }
                    Text("Records de charges déclarées, pas des mesures médicales ni une estimation de force maximale.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
            }
            .padding(15)
        }
        .navigationTitle("Nuclear Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .accessibilityIdentifier("bilux.v70.analytics")
    }
}

// MARK: - BILUX V7.1 · NUCLEAR PERFORMANCE
// Lecture seule du journal V7.0, aucune écriture dans les XP ni les sauvegardes.
private enum V71Metric: String, CaseIterable, Identifiable {
    case weight = "Charge"
    case reps = "Répétitions"
    case volume = "Volume"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .reps: return "repeat"
        case .volume: return "chart.bar.fill"
        }
    }
    var unit: String { self == .weight ? "kg" : self == .reps ? "rép." : "kg·rép" }
}

private struct V71WorkoutPoint: Identifiable {
    let sessionID: UUID
    let date: Date
    let maxWeight: Double
    let totalReps: Int
    let volume: Double
    let validSets: Int
    var id: UUID { sessionID }
    func value(_ metric: V71Metric) -> Double {
        switch metric {
        case .weight: return maxWeight
        case .reps: return Double(totalReps)
        case .volume: return volume
        }
    }
}

private struct V71ExerciseTrend: Identifiable {
    let key: String
    let title: String
    let points: [V71WorkoutPoint]
    var id: String { key }
    var latest: V71WorkoutPoint? { points.last }
    var previous: V71WorkoutPoint? { points.count >= 2 ? points[points.count - 2] : nil }
    var personalBest: Double { points.map(\.maxWeight).max() ?? 0 }
}

private enum V71PerformanceEngine {
    // Un point par séance et par exercice : doublons de nom fusionnés au sein d'une même séance.
    static func trends(_ workouts: [WorkoutSession], now: Date = .now) -> [V71ExerciseTrend] {
        var index: [String: (title: String, points: [V71WorkoutPoint])] = [:]
        for session in workouts where session.date <= now {
            var sessionExercises: [String: (title: String, sets: [WorkoutSet])] = [:]
            for exercise in session.exercises {
                let title = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = V70RebirthStyle.name(title)
                guard !key.isEmpty else { continue }
                let valid = exercise.sets.filter {
                    $0.weight.isFinite && (0...1000).contains($0.weight) && (1...300).contains($0.reps)
                }
                guard !valid.isEmpty else { continue }
                if sessionExercises[key] == nil { sessionExercises[key] = (title, []) }
                sessionExercises[key]?.sets.append(contentsOf: valid)
            }
            for (key, entry) in sessionExercises {
                let point = V71WorkoutPoint(
                    sessionID: session.id, date: session.date,
                    maxWeight: entry.sets.map(\.weight).max() ?? 0,
                    totalReps: entry.sets.reduce(0) { $0 + $1.reps },
                    volume: entry.sets.reduce(0) { $0 + Double($1.reps) * $1.weight },
                    validSets: entry.sets.count
                )
                if index[key] == nil { index[key] = (entry.title, []) }
                index[key]?.points.append(point)
            }
        }
        return index.map { key, item in
            V71ExerciseTrend(key: key, title: item.title,
                             points: item.points.sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.sessionID.uuidString < $1.sessionID.uuidString
            })
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

private struct V71MetricComparison: View {
    let title: String
    let current: Double
    let previous: Double?
    let unit: String

    private var change: Double? { previous.map { current - $0 } }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Nuclear.muted)
            Text("\(BiluxFormat.number(current, digits: unit == "kg" ? 1 : 0)) \(unit)")
                .font(.headline.monospacedDigit()).foregroundStyle(Nuclear.paleGold)
                .minimumScaleFactor(0.7).lineLimit(1)
            if let change {
                Text("\(change > 0 ? "+" : "")\(BiluxFormat.number(change, digits: unit == "kg" ? 1 : 0)) depuis la précédente")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(change > 0 ? Nuclear.gold : change < 0 ? Nuclear.purple : Nuclear.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Première séance connue").font(.caption2).foregroundStyle(Nuclear.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct V71TrendBars: View {
    let points: [V71WorkoutPoint]
    let metric: V71Metric

    var body: some View {
        let values = Array(points.suffix(8))
        let maximum = max(1.0, values.map { $0.value(metric) }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(values) { point in
                VStack(spacing: 5) {
                    Text(BiluxFormat.number(point.value(metric), digits: metric == .weight ? 1 : 0))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Nuclear.paleGold)
                        .lineLimit(1).minimumScaleFactor(0.65)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [Nuclear.gold, Nuclear.purple],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: CGFloat(max(4, 90 * point.value(metric) / maximum)))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    Text(point.date.formatted(.dateTime.day().month(.twoDigits)))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Nuclear.muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 133)
        .accessibilityLabel("Historique des huit dernières séances : \(values.map { BiluxFormat.number($0.value(metric)) }.joined(separator: ", ")) \(metric.unit)")
    }
}

private struct V71ExercisePerformance: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var selectedKey = ""
    @State private var period = 90
    @State private var metric: V71Metric = .weight

    private var trends: [V71ExerciseTrend] { V71PerformanceEngine.trends(journal.data.workouts) }
    private var activeKey: String {
        trends.contains(where: { $0.key == selectedKey }) ? selectedKey : (trends.first?.key ?? "")
    }
    private var current: V71ExerciseTrend? { trends.first { $0.key == activeKey } }

    private var filtered: [V71WorkoutPoint] {
        guard let current else { return [] }
        guard period > 0, let cutoff = Calendar.current.date(byAdding: .day, value: -period, to: .now) else {
            return current.points
        }
        return current.points.filter { $0.date >= cutoff }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("NUCLEAR PERFORMANCE · V7.1")
                        .font(.caption2.bold()).tracking(1.3).foregroundStyle(Nuclear.purple)
                    Text("PROGRESSION PAR EXERCICE")
                        .font(.title3.weight(.black)).foregroundStyle(Nuclear.paleGold)
                }
                if trends.isEmpty {
                    NuclearCard {
                        Label("Aucune série enregistrée", systemImage: "dumbbell.fill")
                        Text("Consigne une séance avec des répétitions et des charges dans la Forge pour voir ta progression.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    }
                } else if let current {
                    NuclearCard {
                        Picker("Exercice", selection: Binding(
                            get: { activeKey }, set: { selectedKey = $0 }
                        )) {
                            ForEach(trends) { exercise in
                                Text(exercise.title).tag(exercise.key)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Mesure", selection: $metric) {
                            ForEach(V71Metric.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }.pickerStyle(.segmented)
                        Picker("Période", selection: $period) {
                            Text("30 j").tag(30)
                            Text("90 j").tag(90)
                            Text("1 an").tag(365)
                            Text("Tout").tag(0)
                        }.pickerStyle(.segmented)
                    }
                    NuclearCard {
                        SectionCaption(title: "Courbe du réacteur")
                        if filtered.isEmpty {
                            Text("Aucune séance sur cette période.").font(.caption).foregroundStyle(Nuclear.muted)
                        } else {
                            V71TrendBars(points: filtered, metric: metric)
                            Text("\(filtered.count) séance(s) · dernières huit représentées · \(metric.unit)")
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                    }
                    NuclearCard {
                        SectionCaption(title: "Cette séance contre la précédente")
                        if let latest = current.latest {
                            Text("Dernière : \(BiluxFormat.day(latest.date))")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                            HStack(alignment: .top, spacing: 12) {
                                V71MetricComparison(title: "Charge max", current: latest.maxWeight,
                                    previous: current.previous?.maxWeight, unit: "kg")
                                V71MetricComparison(title: "Rép. totales", current: Double(latest.totalReps),
                                    previous: current.previous.map { Double($0.totalReps) }, unit: "rép.")
                            }
                            Divider()
                            V71MetricComparison(title: "Volume de l'exercice", current: latest.volume,
                                previous: current.previous?.volume, unit: "kg·rép")
                            Text("Comparaison des deux dernières séances consignées pour cet exercice, quel que soit le filtre de dates.")
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                    }
                    NuclearCard {
                        SectionCaption(title: "Meilleure charge déclarée")
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(Nuclear.gold)
                            Text("\(V70RebirthStyle.weight(current.personalBest)) kg")
                                .font(.title2.weight(.heavy)).foregroundStyle(Nuclear.paleGold)
                            Spacer()
                            Text("\(current.points.count) séances")
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                        }
                        Text("Une charge plus faible sur une séance de récupération n'est pas une régression physique. Ces graphiques décrivent seulement les séries consignées.")
                            .font(.caption2).foregroundStyle(Nuclear.muted)
                    }
                }
            }.padding(15)
        }
        .navigationTitle("Nuclear Performance")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .accessibilityIdentifier("bilux.v71.performance")
    }
}

private struct V71AscensionEvent: Identifiable {
    enum Kind { case record, milestone, boss, transformation }
    let id: String
    let date: Date
    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
}

private enum V71AscensionChronicle {
    static func events(_ data: BiluxData, now: Date = .now) -> [V71AscensionEvent] {
        let cal = Calendar.current
        let ordered = data.workouts.filter { $0.date <= now }.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
        var result: [V71AscensionEvent] = []
        var previousBest: [String: Double] = [:]
        for (index, workout) in ordered.enumerated() {
            if [0, 9, 24, 49, 99].contains(index) {
                let count = index + 1
                result.append(.init(id: "session-\(workout.id.uuidString)", date: workout.date,
                    kind: .milestone,
                    title: count == 1 ? "PREMIER COMBAT" : "\(count) SÉANCES CONSIGNÉES",
                    detail: "Jalon du journal sportif · sans XP supplémentaire", symbol: "flag.checkered"))
            }
            var sessionBest: [String: (title: String, weight: Double)] = [:]
            for exercise in workout.exercises {
                let title = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = V70RebirthStyle.name(title)
                guard !key.isEmpty else { continue }
                let best = exercise.sets.filter { $0.weight.isFinite && $0.weight > 0 && $0.reps > 0 }
                    .map(\.weight).max() ?? 0
                guard best > 0 else { continue }
                if best > (sessionBest[key]?.weight ?? 0) { sessionBest[key] = (title, best) }
            }
            for (key, item) in sessionBest.sorted(by: { $0.key < $1.key }) {
                if let old = previousBest[key], item.weight > old {
                    result.append(.init(id: "record-\(workout.id.uuidString)-\(key)", date: workout.date,
                        kind: .record, title: "RECORD BRISÉ ⚡",
                        detail: "\(item.title) · \(V70RebirthStyle.weight(old)) → \(V70RebirthStyle.weight(item.weight)) kg",
                        symbol: "trophy.fill"))
                }
                previousBest[key] = max(previousBest[key] ?? 0, item.weight)
            }
        }
        // Les boss utilisent les mêmes journées éligibles que V5.5 : >=10 min,
        // un jour distinct, jusqu'à cinq jours par semaine, après l'ancre de migration.
        let anchor = data.longAscensionAnchor?.startedAt ?? now
        let days = Set(ordered.filter { $0.date >= anchor && $0.durationMinutes >= 10 }
            .map { cal.startOfDay(for: $0.date) })
        let weekGroups = Dictionary(grouping: days, by: { day in
            cal.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        })
        let eligible = weekGroups.values.flatMap { $0.sorted().prefix(5) }.sorted()
        var monthly: [Date: Int] = [:]
        var quarterly: [Date: Int] = [:]
        for day in eligible {
            let month = cal.dateInterval(of: .month, for: day)?.start ?? day
            let components = cal.dateComponents([.year, .month], from: day)
            let quarterStartMonth = (((components.month ?? 1) - 1) / 3) * 3 + 1
            let quarter = cal.date(from: DateComponents(year: components.year, month: quarterStartMonth, day: 1)) ?? day
            monthly[month, default: 0] += 1
            quarterly[quarter, default: 0] += 1
            if monthly[month] == 12 {
                result.append(.init(id: "guardian-\(month.timeIntervalSince1970)", date: day,
                    kind: .boss, title: "GARDIEN DU RÉACTEUR VAINCU",
                    detail: "12 journées éligibles sur un mois civil · victoire reconstituée",
                    symbol: "shield.fill"))
            }
            if quarterly[quarter] == 30 {
                result.append(.init(id: "sovereign-\(quarter.timeIntervalSince1970)", date: day,
                    kind: .boss, title: "SOUVERAIN DU NÉANT VAINCU",
                    detail: "30 journées éligibles sur un trimestre civil · victoire reconstituée",
                    symbol: "crown.fill"))
            }
        }
        // Dates de transformations : uniquement si le passage est traçable
        // depuis l'ancre V5.5. Les rangs déjà acquis avant migration restent sans date.
        let initialStage = data.longAscensionAnchor?.legacyStage ?? 0
        var lastStage = initialStage
        let activeDays = Set((ordered.map(\.date) + data.meals.map(\.date) + data.checkins.map(\.date))
            .filter { $0 >= anchor && $0 <= now }.map { cal.startOfDay(for: $0) }).sorted()
        for day in activeDays where lastStage < 4 {
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: day) else { continue }
            let instant = min(now, nextDay.addingTimeInterval(-0.001))
            let xp = BILUXV55Progression.totalXP(data, now: instant)
            let level = BILUXV55Progression.level(for: xp,
                floor: data.longAscensionAnchor?.legacyLevel ?? 1)
            let stage = BILUXV55Progression.unlockedStage(level: level, legacyFloor: initialStage)
            if stage > lastStage {
                for newStage in (lastStage + 1)...min(stage, 4) {
                    result.append(.init(id: "stage-\(newStage)", date: day,
                        kind: .transformation,
                        title: "ÉVEIL · \(BILUXV55Progression.stageNames[newStage])",
                        detail: "Palier d'ascension atteint · date reconstituée depuis le journal",
                        symbol: "bolt.shield.fill"))
                }
                lastStage = stage
            }
        }
        return result.sorted {
            if $0.date != $1.date { return $0.date > $1.date }
            return $0.id < $1.id
        }
    }
}

private struct V71AscensionChronicleView: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var filter = 0
    private var events: [V71AscensionEvent] { V71AscensionChronicle.events(journal.data) }
    private var visible: [V71AscensionEvent] {
        events.filter { item in
            switch filter {
            case 1: return item.kind == .record
            case 2: return item.kind == .boss
            case 3: return item.kind == .transformation
            default: return true
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LES CHRONIQUES DU NOYAU · V7.1")
                        .font(.caption2.bold()).tracking(1.5).foregroundStyle(Nuclear.purple)
                    Text("JOURNAL DE L'ASCENSION")
                        .font(.title3.weight(.black)).foregroundStyle(Nuclear.paleGold)
                }
                NuclearCard {
                    HStack {
                        Image(systemName: "crown.fill").foregroundStyle(Nuclear.gold)
                        Text("\(journal.rankName.uppercased()) · NIV. \(journal.heroLevel)")
                            .font(.headline.weight(.bold)).foregroundStyle(Nuclear.paleGold)
                    }
                    Text("Rang actuel : les formes obtenues avant la migration V5.5 n'ont pas de date d'obtention fiable.")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
                Picker("Événements", selection: $filter) {
                    Text("Tout").tag(0)
                    Text("Records").tag(1)
                    Text("Boss").tag(2)
                    Text("Formes").tag(3)
                }.pickerStyle(.segmented)
                if visible.isEmpty {
                    NuclearCard {
                        Text("Aucun événement historique confirmé dans cette catégorie.")
                            .font(.subheadline).foregroundStyle(Nuclear.muted)
                    }
                } else {
                    ForEach(Array(visible.prefix(120))) { event in
                        NuclearCard {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: event.symbol)
                                    .font(.title2).foregroundStyle(event.kind == .record ? Nuclear.gold : Nuclear.purple)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.title).font(.subheadline.weight(.heavy)).foregroundStyle(Nuclear.paleGold)
                                    Text(BiluxFormat.day(event.date)).font(.caption2).foregroundStyle(Nuclear.gold)
                                    Text(event.detail).font(.caption).foregroundStyle(Nuclear.muted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                Text("Chronologie calculée depuis les séances existantes. Records et victoires peuvent changer si tu modifies ou supprimes d'anciennes données. Aucune récompense, session ou XP n'est créé.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }.padding(15)
        }
        .navigationTitle("Journal de l'Ascension")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .accessibilityIdentifier("bilux.v71.chronicle")
    }
}

private struct V71RecordCelebration: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let records: [String]
    @State private var glowing = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nuclear.background, Nuclear.purple.opacity(0.28), Nuclear.background],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 19) {
                ZStack {
                    Circle()
                        .stroke(Nuclear.purple.opacity(0.48), style: StrokeStyle(lineWidth: 2, dash: [11, 18]))
                        .frame(width: 202, height: 202)
                        .rotationEffect(.degrees(glowing ? 24 : -24))
                    Circle()
                        .stroke(Nuclear.gold.opacity(0.55), lineWidth: 2)
                        .frame(width: 165, height: 165)
                        .scaleEffect(glowing ? 1.08 : 0.93)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 85, weight: .black))
                        .foregroundStyle(Nuclear.gold)
                        .shadow(color: Nuclear.purple.opacity(glowing ? 0.85 : 0.22), radius: glowing ? 35 : 8)
                        .scaleEffect(glowing ? 1.1 : 0.95)
                }
                .frame(height: 218)
                .accessibilityHidden(true)
                Text("RECORD BRISÉ ⚡")
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .foregroundStyle(Nuclear.gold)
                Text("LA FORGE RECONNAÎT TA PUISSANCE")
                    .font(.caption.bold()).tracking(1.2).foregroundStyle(Nuclear.paleGold)
                ForEach(records.prefix(4), id: \.self) { record in
                    Text(record).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white).multilineTextAlignment(.center)
                }
                Text("Record déclaré dans ton journal · aucun XP supplémentaire")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
                    .multilineTextAlignment(.center)
                Button("RETOUR À LA FORGE") { dismiss() }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
            }.padding(24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { glowing = true }
        }
    }
}

// MARK: - BILUX V7.2 · NUCLEAR AWAKENING
// Pure presentation. Unlocks are derived from existing V5.5 and V6.3 data.
// No XP, achievements, dates, HealthKit, storage schema or Watch changes.

private struct V72Milestone: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let symbol: String

    static let all: [V72Milestone] = [
        .init(id: 10, name: "PREMIER ÉVEIL", subtitle: "Le noyau commence à répondre.", symbol: "bolt.fill"),
        .init(id: 25, name: "RÉACTEUR EN FUSION", subtitle: "L'énergie prend forme.", symbol: "atom"),
        .init(id: 50, name: "MAÎTRISE NUCLÉAIRE", subtitle: "La puissance devient discipline.", symbol: "shield.lefthalf.filled"),
        .init(id: 75, name: "LÉGENDE DU RÉACTEUR", subtitle: "L'orage répond à l'appel.", symbol: "crown.fill"),
        .init(id: 100, name: "ASCENSION ABSOLUE", subtitle: "La dernière forme est révélée.", symbol: "sparkles")
    ]
}

private struct V72CoreSeal: View {
    let stageIndex: Int
    let masteryTotal: Int
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color {
        NuclearStage.all[min(max(0, stageIndex), NuclearStage.all.count - 1)].accent
    }
    private var layers: Int { 1 + min(3, max(0, stageIndex)) }
    private var motionAllowed: Bool { effectsEnabled && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: !motionAllowed)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let glow = motionAllowed ? (sin(time * 1.35) + 1.0) / 2.0 : 0.35
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [accent.opacity(0.30 + glow * 0.23),
                                                  Nuclear.purple.opacity(0.15), .clear],
                                         center: .center, startRadius: 2, endRadius: 82))
                ForEach(0..<layers, id: \.self) { layer in
                    Circle()
                        .trim(from: 0.08, to: 0.66)
                        .stroke(AngularGradient(colors: [.clear, accent,
                                                        Nuclear.purple.opacity(0.9), .clear],
                                                center: .center),
                                style: StrokeStyle(lineWidth: layer == 0 ? 3.0 : 1.5,
                                                   lineCap: .round))
                        .padding(CGFloat(5 + layer * 12))
                        .rotationEffect(.degrees(motionAllowed
                            ? (time * (layer.isMultiple(of: 2) ? 9.0 : -7.0))
                            : Double(layer * 40)))
                        .opacity(0.58 + glow * 0.35)
                }
                Image(systemName: stageIndex >= 3 ? "crown.fill" : "atom")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Nuclear.paleGold)
                    .shadow(color: accent.opacity(0.85), radius: CGFloat(6 + glow * 8))
                if masteryTotal >= 4 {
                    Circle().stroke(Nuclear.paleGold.opacity(0.42 + glow * 0.32), lineWidth: 1.1)
                        .padding(3)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Réacteur visuel, rang \(stageIndex + 1) sur 5, \(masteryTotal) maîtrises débloquées")
    }
}

private struct V72AwakeningEntry: View {
    @EnvironmentObject private var journal: BiluxStore
    private var unlocked: Int { V63MasterySnapshot.evaluate(journal.data).unlockedTotal }

    var body: some View {
        NavigationLink {
            V72AwakeningChamber().environmentObject(journal)
        } label: {
            HStack(spacing: 12) {
                V72CoreSeal(stageIndex: journal.unlockedStageIndex, masteryTotal: unlocked)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 5) {
                    Text("CHAMBRE D'ÉVEIL · V7.2")
                        .font(.caption.weight(.black)).tracking(1.2)
                        .foregroundStyle(Nuclear.gold)
                    Text("TRANSFORMATIONS & RELIQUES")
                        .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                    Text("Rang \(journal.rankName) · \(unlocked)/12 maîtrises")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold()).foregroundStyle(Nuclear.gold)
            }
            .padding(12)
            .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15)
                .stroke(LinearGradient(colors: [Nuclear.gold.opacity(0.8), Nuclear.purple.opacity(0.48)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bilux.v72.openAwakening")
    }
}

private struct V72AwakeningChamber: View {
    @EnvironmentObject private var journal: BiluxStore
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cinemaStage: NuclearStage?
    @State private var cinemaMilestone: V72Milestone?

    private var mastery: V63MasterySnapshot { V63MasterySnapshot.evaluate(journal.data) }
    private var rank: NuclearStage {
        NuclearStage.all[min(max(0, journal.unlockedStageIndex), NuclearStage.all.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BILUX · NUCLEAR AWAKENING")
                        .font(.caption2.weight(.black)).tracking(2.0)
                        .foregroundStyle(Nuclear.purple)
                    Text("CHAMBRE D'ÉVEIL")
                        .font(.title2.weight(.black)).foregroundStyle(Nuclear.paleGold)
                    Text("Une récompense visuelle pour chaque véritable palier.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }

                ZStack(alignment: .bottom) {
                    NuclearHeroAura(level: journal.heroLevel,
                                    effectsEnabled: effectsEnabled,
                                    stageOverride: rank,
                                    minimumStage: journal.unlockedStageIndex,
                                    masteryCount: mastery.unlockedTotal,
                                    dominantPath: V64StormMastery.dominantPath(journal.data))
                        .frame(height: 335).clipped()
                    LinearGradient(colors: [.clear, Nuclear.background.opacity(0.82)],
                                   startPoint: .center, endPoint: .bottom)
                        .frame(height: 110)
                        .allowsHitTesting(false)
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rank.name.uppercased())
                                .font(.headline.weight(.black)).foregroundStyle(rank.accent)
                            Text("NIVEAU \(journal.heroLevel) · \(journal.totalXP) XP")
                                .font(.caption.bold()).foregroundStyle(.white)
                        }
                        Spacer(minLength: 0)
                        V72CoreSeal(stageIndex: journal.unlockedStageIndex,
                                    masteryTotal: mastery.unlockedTotal)
                            .frame(width: 86, height: 86)
                    }
                    .padding(13)
                }
                .background(Nuclear.panel)
                .clipShape(RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17)
                    .stroke(rank.accent.opacity(0.70), lineWidth: 1.1))
                .accessibilityIdentifier("bilux.v72.heroReactor")

                Button { cinemaStage = rank } label: {
                    Label("REVOIR L'ÉVEIL DU RANG", systemImage: "film.stack.fill")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity, minHeight: 45)
                }
                .buttonStyle(.borderedProminent).tint(Nuclear.gold)

                SectionCaption(title: "Reliques des cinq rangs")
                Text("Déblocages automatiques selon tes rangs existants. Aucun XP supplémentaire.")
                    .font(.caption).foregroundStyle(Nuclear.muted)
                ForEach(NuclearStage.all) { stage in
                    let achieved = stage.id <= journal.unlockedStageIndex
                    HStack(spacing: 12) {
                        Image(systemName: achieved ? stage.symbol : "lock.fill")
                            .font(.title3).frame(width: 32)
                            .foregroundStyle(achieved ? stage.accent : .gray)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SCEAU · \(stage.name.uppercased())")
                                .font(.subheadline.bold()).foregroundStyle(.white)
                            Text(achieved ? "RELIQUE ACQUISE" : "Rang non débloqué")
                                .font(.caption2).foregroundStyle(achieved ? Nuclear.gold : Nuclear.muted)
                        }
                        Spacer()
                        if achieved {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Nuclear.gold)
                        }
                    }
                    .padding(12)
                    .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 12))
                }

                SectionCaption(title: "Signatures des quatre voies")
                Text("Chaque voie enrichit visuellement le réacteur à mesure que ses compétences sont acquises.")
                    .font(.caption).foregroundStyle(Nuclear.muted)
                ForEach(mastery.branches) { branch in
                    HStack(spacing: 12) {
                        Image(systemName: branch.icon)
                            .font(.title2).frame(width: 35)
                            .foregroundStyle(branch.unlockedCount > 0 ? Nuclear.purple : .gray)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(branch.title).font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                            Text("\(branch.unlockedCount)/3 insignes révélés")
                                .font(.caption2).foregroundStyle(Nuclear.muted)
                            HStack(spacing: 6) {
                                ForEach(branch.nodes) { node in
                                    Image(systemName: node.achieved ? node.icon : "lock.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(node.achieved ? Nuclear.gold : .gray)
                                        .frame(maxWidth: .infinity, minHeight: 24)
                                        .background(node.achieved ? Nuclear.gold.opacity(0.12)
                                                  : Color.gray.opacity(0.10),
                                                    in: RoundedRectangle(cornerRadius: 6))
                                        .accessibilityLabel("\(node.title) : \(node.achieved ? "acquis" : "verrouillé")")
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 12))
                }

                SectionCaption(title: "Cinématiques des grands paliers")
                ForEach(V72Milestone.all) { milestone in
                    let attained = journal.heroLevel >= milestone.id
                    NuclearCard {
                        HStack(spacing: 12) {
                            Image(systemName: attained ? milestone.symbol : "lock.fill")
                                .font(.title2).frame(width: 28)
                                .foregroundStyle(attained ? Nuclear.gold : Nuclear.muted)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(milestone.name)
                                    .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                                Text("PALIER NIVEAU \(milestone.id) · \(attained ? "ATTEINT" : "À DÉBLOQUER")")
                                    .font(.caption2).foregroundStyle(attained ? Nuclear.gold : Nuclear.muted)
                            }
                            Spacer(minLength: 4)
                            if attained {
                                Button("REVOIR") { cinemaMilestone = milestone }
                                    .font(.caption.bold()).tint(Nuclear.gold)
                            }
                        }
                    }
                }
                NavigationLink {
                    V71AscensionChronicleView().environmentObject(journal)
                } label: {
                    Label("OUVRIR LE JOURNAL DE L'ASCENSION", systemImage: "book.closed.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered).tint(Nuclear.purple)
                Text("Les ornements sont calculés à partir des données déjà sauvegardées. Supprimer d'anciennes séances peut modifier les déblocages. Les cinématiques rejouées ne donnent pas d'XP.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }
            .padding(15)
        }
        .navigationTitle("Éveil nucléaire")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .fullScreenCover(item: $cinemaStage) { stage in
            BILUXV57RankCinema(stage: stage, effectsEnabled: effectsEnabled) {
                cinemaStage = nil
            }
        }
        .fullScreenCover(item: $cinemaMilestone) { milestone in
            V72MilestoneCinema(milestone: milestone, stage: rank,
                                level: journal.heroLevel,
                                masteryCount: mastery.unlockedTotal,
                                dominantPath: V64StormMastery.dominantPath(journal.data),
                                effectsEnabled: effectsEnabled) {
                cinemaMilestone = nil
            }
        }
        .accessibilityIdentifier("bilux.v72.awakening")
    }
}

// Replays are cinematic only; no XP or historical event is written.
private struct V72MilestoneCinema: View {
    let milestone: V72Milestone
    let stage: NuclearStage
    let level: Int
    let masteryCount: Int
    let dominantPath: String
    let effectsEnabled: Bool
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Int = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Nuclear.background.ignoresSafeArea()
                NuclearHeroAura(level: level, effectsEnabled: effectsEnabled,
                                stageOverride: stage, minimumStage: stage.id,
                                masteryCount: masteryCount, dominantPath: dominantPath)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(phase == 0 && effectsEnabled && !reduceMotion ? 0.45 : 1.0)
                LinearGradient(colors: [Nuclear.background.opacity(0.55), .clear,
                                        Nuclear.background.opacity(0.60), Nuclear.background],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 17) {
                    HStack {
                        Text("NUCLEAR AWAKENING · V7.2")
                            .font(.caption2.weight(.black)).tracking(1.4)
                            .foregroundStyle(Nuclear.paleGold)
                        Spacer()
                        Button("PASSER") { onDismiss() }
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(9).background(.black.opacity(0.65), in: Capsule())
                    }
                    Spacer()
                    V72CoreSeal(stageIndex: stage.id, masteryTotal: masteryCount)
                        .frame(width: phase >= 2 ? 180 : 124,
                               height: phase >= 2 ? 180 : 124)
                        .accessibilityHidden(true)
                    Text(phase < 2 ? "LE RÉACTEUR S'ÉVEILLE" : "PALIER RÉVÉLÉ")
                        .font(.caption.weight(.black)).tracking(2.0)
                        .foregroundStyle(Nuclear.paleGold)
                    Text(milestone.name)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: stage.accent.opacity(0.9), radius: 14)
                    Text("NIVEAU \(milestone.id) · \(milestone.subtitle)")
                        .font(.subheadline).multilineTextAlignment(.center)
                        .foregroundStyle(Nuclear.paleGold)
                    Button { onDismiss() } label: {
                        Label("CONTINUER L'ASCENSION", systemImage: "crown.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .disabled(effectsEnabled && !reduceMotion && phase < 3)
                    .opacity(effectsEnabled && !reduceMotion && phase < 3 ? 0.55 : 1)
                    Spacer().frame(height: 22)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Nuclear.background)
        .task {
            guard effectsEnabled && !reduceMotion else { phase = 3; return }
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.55)) { phase = 1 }
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.60)) { phase = 2 }
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { phase = 3 }
        }
    }
}

// MARK: - BILUX V7.3 · ETERNAL FORGE
// Programmes locaux, séances reliées au journal existant et campagne cosmétique.
// Aucun changement à BiluxData, BILUXV55Progression, HealthKit ou WatchConnectivity.

private struct V73ExerciseTarget: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
}

private struct V73PlannedDay: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var muscleGroup: String
    var durationMinutes: Int
    var exercises: [V73ExerciseTarget]
}

private struct V73TrainingPlan: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var createdAt: Date
    var days: [V73PlannedDay]
    var archived: Bool = false
}

private struct V73LinkedSession: Codable, Identifiable {
    var id: UUID = UUID()
    var planID: UUID
    var dayID: UUID
    var workoutID: UUID
    var recordedAt: Date
}

private struct V73Ledger: Codable {
    var schema: Int = 1
    var plans: [V73TrainingPlan] = []
    var linkedSessions: [V73LinkedSession] = []
    var celebratedPlanIDs: [UUID] = []
    var highestRelicThreshold: [UUID: Int] = [:]
    var firstVictoryDates: [UUID: Date] = [:]
}

private enum V73LedgerStore {
    static let key = "bilux.v73.eternalforge.ledger.v1"
    static let didChange = Notification.Name("bilux.v73.eternalforge.changed")

    static func load() throws -> V73Ledger {
        guard let raw = UserDefaults.standard.data(forKey: key) else { return V73Ledger() }
        let ledger = try JSONDecoder().decode(V73Ledger.self, from: raw)
        guard ledger.schema == 1 else { throw V73StorageIssue.unsupportedVersion }
        return ledger
    }

    static func persist(_ ledger: V73Ledger) throws {
        guard ledger.plans.count <= 100,
              ledger.linkedSessions.count <= 20_000 else { throw V73StorageIssue.invalidBackup }
        let raw = try JSONEncoder().encode(ledger)
        UserDefaults.standard.set(raw, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func link(_ launch: V73ForgeLaunch, to workout: WorkoutSession) throws {
        var ledger = try load()
        guard ledger.plans.contains(where: { $0.id == launch.planID && $0.days.contains(where: { $0.id == launch.dayID }) }) else {
            throw V73StorageIssue.missingPlan
        }
        guard !ledger.linkedSessions.contains(where: { $0.workoutID == workout.id }) else { return }
        ledger.linkedSessions.append(V73LinkedSession(planID: launch.planID, dayID: launch.dayID,
                                                       workoutID: workout.id, recordedAt: workout.date))
        try persist(ledger)
    }

    static func exportURL(_ ledger: V73Ledger) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("BILUX-V7.3-programmes-sauvegarde.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(ledger).write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }

    static func importBackup(_ url: URL, into current: V73Ledger) throws -> V73Ledger {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let raw = try Data(contentsOf: url)
        guard raw.count < 3_000_000 else { throw V73StorageIssue.invalidBackup }
        let imported = try JSONDecoder().decode(V73Ledger.self, from: raw)
        guard imported.schema == 1, imported.plans.count <= 100,
              imported.linkedSessions.count <= 20_000,
              imported.plans.allSatisfy({ $0.days.count <= 7 && $0.title.count <= 80 &&
                  $0.days.allSatisfy({ $0.exercises.count <= 12 && $0.durationMinutes >= 10 && $0.durationMinutes <= 240 &&
                      $0.exercises.allSatisfy({ $0.name.count <= 80 && (1...12).contains($0.sets) &&
                          (1...100).contains($0.reps) && $0.weight.isFinite && (0...1000).contains($0.weight) }) }) })
        else { throw V73StorageIssue.invalidBackup }
        var merged = current
        var ids = Set(merged.plans.map(\.id))
        for plan in imported.plans where ids.insert(plan.id).inserted { merged.plans.append(plan) }
        let planIDs = Set(merged.plans.map(\.id))
        var workoutIDs = Set(merged.linkedSessions.map(\.workoutID))
        for entry in imported.linkedSessions where planIDs.contains(entry.planID) && workoutIDs.insert(entry.workoutID).inserted {
            merged.linkedSessions.append(entry)
        }
        merged.celebratedPlanIDs = Array(Set(merged.celebratedPlanIDs + imported.celebratedPlanIDs))
        for (id, threshold) in imported.highestRelicThreshold where planIDs.contains(id) {
            merged.highestRelicThreshold[id] = max(merged.highestRelicThreshold[id] ?? 0, min(12, max(0, threshold)))
        }
        for (id, date) in imported.firstVictoryDates where planIDs.contains(id) {
            if let previous = merged.firstVictoryDates[id] {
                merged.firstVictoryDates[id] = min(date, previous)
            } else { merged.firstVictoryDates[id] = date }
        }
        return merged
    }
}

private enum V73StorageIssue: LocalizedError {
    case unsupportedVersion, invalidBackup, missingPlan
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "Version de sauvegarde des programmes non reconnue. Aucune donnée n'a été remplacée."
        case .invalidBackup: return "Sauvegarde des programmes invalide ou trop volumineuse."
        case .missingPlan: return "Programme source introuvable. La séance du journal reste enregistrée."
        }
    }
}

private struct V73ForgeLaunch {
    let planID: UUID
    let dayID: UUID
    let planName: String
    let day: V73PlannedDay
}

private struct V73CampaignProgress {
    let sessions: [WorkoutSession]  // Une seule séance admissible par jour, cinq par semaine au plus.
    var completed: Int { sessions.count }
    var counted: Int { min(12, completed) }
    var fraction: Double { Double(counted) / 12.0 }
    var hitPoints: Int { max(0, (12 - counted) * 100) }
    var defeated: Bool { counted >= 12 }
    var victoryDate: Date? { defeated ? sessions[11].date : nil }
    var phase: String {
        switch counted {
        case 12...: return "VICTOIRE · NÉANT VAINCU"
        case 8...: return "PHASE IV · LE DERNIER REMPART"
        case 4...: return "PHASE III · ARMURE FRACTURÉE"
        case 2...: return "PHASE II · LE NOYAU S'ÉVEILLE"
        default: return "PHASE I · ÉCHO DES TÉNÈBRES"
        }
    }
    var relics: [String] {
        var result: [String] = []
        if counted >= 4 { result.append("Sceau de la Brèche") }
        if counted >= 8 { result.append("Aura des Cendres") }
        if defeated { result.append("Couronne du Néant") }
        return result
    }
}

private enum V73CampaignEngine {
    static func linkedWorkouts(plan: V73TrainingPlan, ledger: V73Ledger,
                               workouts: [WorkoutSession], now: Date = .now) -> [WorkoutSession] {
        var byID: [UUID: WorkoutSession] = [:]
        for item in workouts { byID[item.id] = item }
        let days: [UUID: V73PlannedDay] = Dictionary(uniqueKeysWithValues: plan.days.map { ($0.id, $0) })
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: plan.createdAt)
        var seen = Set<UUID>()
        var accepted: [WorkoutSession] = []
        for link in ledger.linkedSessions where link.planID == plan.id {
            guard seen.insert(link.workoutID).inserted,
                  let day = days[link.dayID], let workout = byID[link.workoutID],
                  workout.date <= now, calendar.startOfDay(for: workout.date) >= firstDay,
                  workout.durationMinutes >= 10, !day.exercises.isEmpty else { continue }
            let completedNames = Set(workout.exercises.filter { !$0.sets.isEmpty }
                .map { V70RebirthStyle.name($0.name) })
            let targetNames = Set(day.exercises.map { V70RebirthStyle.name($0.name) })
            guard targetNames.isSubset(of: completedNames) else { continue }
            accepted.append(workout)
        }
        accepted.sort { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
        var onePerDay = Set<Date>()
        var perWeek: [Date: Int] = [:]
        return accepted.filter { workout in
            let day = calendar.startOfDay(for: workout.date)
            let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            guard !onePerDay.contains(day), perWeek[week, default: 0] < 5 else { return false }
            onePerDay.insert(day)
            perWeek[week, default: 0] += 1
            return true
        }
    }

    static func progress(plan: V73TrainingPlan, ledger: V73Ledger,
                         workouts: [WorkoutSession]) -> V73CampaignProgress {
        V73CampaignProgress(sessions: linkedWorkouts(plan: plan, ledger: ledger, workouts: workouts))
    }
}

private struct V73EternalForgeEntry: View {
    @EnvironmentObject private var journal: BiluxStore
    var body: some View {
        NavigationLink {
            V73EternalForgeHub().environmentObject(journal)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "flame.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(Nuclear.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ETERNAL FORGE · V7.3")
                        .font(.caption.weight(.black)).tracking(1.2).foregroundStyle(Nuclear.gold)
                    Text("PROGRAMMES & CAMPAGNES RPG")
                        .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                    Text("Séances planifiées · boss évolutif · récompenses visuelles")
                        .font(.caption2).foregroundStyle(Nuclear.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").foregroundStyle(Nuclear.gold)
            }
            .padding(13)
            .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Nuclear.purple.opacity(0.7), lineWidth: 1.3))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bilux.v73.eternalForge")
    }
}

private struct V73EternalForgeHub: View {
    @EnvironmentObject private var journal: BiluxStore
    @State private var ledger = V73Ledger()
    @State private var showEditor = false
    @State private var showImporter = false
    @State private var fileToShare: URL?
    @State private var message: String?
    @State private var canEdit = true

    private var activePlans: [V73TrainingPlan] { ledger.plans.filter { !$0.archived } }
    private var archivedPlans: [V73TrainingPlan] { ledger.plans.filter(\.archived) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("ETERNAL FORGE · V7.3", systemImage: "flame.fill")
                    .font(.title2.weight(.black)).foregroundStyle(Nuclear.gold)
                Text("Construis ton programme, enregistre tes vraies séances dans la Forge, fais reculer le Néant.")
                    .font(.subheadline).foregroundStyle(Nuclear.muted)

                NuclearCard {
                    HStack {
                        Label("PROGRAMMES", systemImage: "calendar.badge.plus")
                            .font(.headline).foregroundStyle(Nuclear.paleGold)
                        Spacer()
                        Text("\(activePlans.count) actif(s)")
                            .font(.caption).foregroundStyle(Nuclear.gold)
                    }
                    Button {
                        showEditor = true
                    } label: {
                        Label("CRÉER UN PROGRAMME", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .disabled(!canEdit || ledger.plans.count >= 100)
                }

                if activePlans.isEmpty {
                    NuclearCard {
                        Text("Aucun programme pour le moment.")
                            .font(.subheadline.bold()).foregroundStyle(Nuclear.paleGold)
                        Text("Crée une ou plusieurs journées de musculation. Tu décideras librement quand les effectuer.")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    }
                }
                ForEach(activePlans) { plan in
                    V73PlanRow(plan: plan, ledger: ledger, workouts: journal.data.workouts)
                        .environmentObject(journal)
                }

                NuclearCard {
                    SectionCaption(title: "Les Gardiens historiques")
                    Text("Les boss des versions précédentes restent inchangés : les séances de campagne ne donnent pas un deuxième bonus d'XP.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    HStack {
                        Text("Gardien du Réacteur")
                        Spacer()
                        Text("\(BILUXV56Boss.guardian.countedDays(in: journal.data))/12 jours")
                            .foregroundStyle(Nuclear.gold)
                    }.font(.caption)
                    HStack {
                        Text("Souverain du Néant")
                        Spacer()
                        Text("\(BILUXV56Boss.sovereign.countedDays(in: journal.data))/30 jours")
                            .foregroundStyle(Nuclear.purple)
                    }.font(.caption)
                }

                if !archivedPlans.isEmpty {
                    SectionCaption(title: "Programmes archivés")
                    ForEach(archivedPlans) { plan in
                        V73PlanRow(plan: plan, ledger: ledger, workouts: journal.data.workouts)
                            .environmentObject(journal)
                    }
                }

                NuclearCard {
                    SectionCaption(title: "Sauvegarde des programmes")
                    Text("Les programmes sont stockés localement, séparément de l'ancien journal JSON BILUX. Exporte aussi ce fichier pour les conserver en cas de réinstallation.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                    Button("PRÉPARER LE FICHIER DE SAUVEGARDE") {
                        do { fileToShare = try V73LedgerStore.exportURL(ledger) }
                        catch { message = error.localizedDescription }
                    }
                    .font(.caption.bold()).disabled(!canEdit)
                    if let fileToShare {
                        ShareLink(item: fileToShare) {
                            Label("PARTAGER / ENREGISTRER LE JSON", systemImage: "square.and.arrow.up")
                                .font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 38)
                        }.buttonStyle(.bordered).tint(Nuclear.gold)
                    }
                    Button("IMPORTER UNE SAUVEGARDE DE PROGRAMMES") { showImporter = true }
                        .font(.caption.bold()).disabled(!canEdit)
                }
                Text("Repos libres, zéro pénalité et zéro XP supplémentaire. Les objectifs de charge sont indicatifs.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }
            .padding(15)
        }
        .navigationTitle("Eternal Forge")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: V73LedgerStore.didChange)) { _ in reload() }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                V73ProgramEditor { plan in
                    var next = ledger
                    next.plans.append(plan)
                    do {
                        try V73LedgerStore.persist(next)
                        ledger = next
                        return true
                    } catch {
                        message = error.localizedDescription
                        return false
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let merged = try V73LedgerStore.importBackup(url, into: ledger)
                try V73LedgerStore.persist(merged)
                ledger = merged
                fileToShare = nil
                message = "Sauvegarde des programmes importée sans écraser les programmes existants."
            } catch { message = error.localizedDescription }
        }
        .alert("Eternal Forge", isPresented: Binding(get: { message != nil },
                                                     set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func reload() {
        do { ledger = try V73LedgerStore.load(); canEdit = true }
        catch { message = error.localizedDescription; canEdit = false }
    }
}

private struct V73PlanRow: View {
    @EnvironmentObject private var journal: BiluxStore
    let plan: V73TrainingPlan
    let ledger: V73Ledger
    let workouts: [WorkoutSession]
    private var progress: V73CampaignProgress {
        V73CampaignEngine.progress(plan: plan, ledger: ledger, workouts: workouts)
    }
    private var hasCrown: Bool {
        max(progress.counted, ledger.highestRelicThreshold[plan.id] ?? 0) >= 12
    }
    var body: some View {
        NavigationLink {
            V73ProgramDetail(planID: plan.id).environmentObject(journal)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(plan.title).font(.headline.weight(.heavy)).foregroundStyle(Nuclear.paleGold)
                        .lineLimit(2)
                    Spacer(minLength: 3)
                    Image(systemName: "chevron.right").foregroundStyle(Nuclear.gold)
                }
                HStack {
                    Label("\(plan.days.count) journées", systemImage: "calendar")
                    Spacer()
                    Text("Campagne \(progress.counted)/12")
                }.font(.caption).foregroundStyle(Nuclear.muted)
                ProgressView(value: progress.fraction).tint(Nuclear.purple)
                if hasCrown {
                    Label("COURONNE DU NÉANT DÉBLOQUÉE", systemImage: "crown.fill")
                        .font(.caption.bold()).foregroundStyle(Nuclear.gold)
                }
            }
            .padding(13)
            .background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct V73ProgramEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (V73TrainingPlan) -> Bool
    @State private var name = ""
    @State private var dayName = "Séance A"
    @State private var group = "Haut du corps"
    @State private var duration = "60"
    @State private var exerciseName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight = "0"
    @State private var exercises: [V73ExerciseTarget] = []
    @State private var days: [V73PlannedDay] = []
    @State private var warning: String?
    private let groups = ["Haut du corps", "Bas du corps", "Full body", "Poussée", "Tirage", "Cardio / mobilité", "Libre"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("CRÉER TON PROGRAMME")
                    .font(.title2.weight(.black)).foregroundStyle(Nuclear.gold)
                NuclearCard {
                    TextField("Nom du programme (ex. Cycle Réacteur)", text: $name)
                        .textInputAutocapitalization(.words)
                    Text("Les journées sont flexibles : tu peux t'entraîner ou te reposer quand tu veux.")
                        .font(.caption).foregroundStyle(Nuclear.muted)
                }
                SectionCaption(title: "Composer une journée")
                NuclearCard {
                    TextField("Nom de la journée", text: $dayName)
                    Picker("Groupe musculaire", selection: $group) {
                        ForEach(groups, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Text("Durée cible (min)")
                        Spacer()
                        TextField("60", text: $duration).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(width: 62)
                    }.font(.subheadline)
                    Divider()
                    TextField("Exercice (ex. développé couché)", text: $exerciseName)
                    HStack {
                        Stepper("Séries : \(sets)", value: $sets, in: 1...12)
                        Stepper("Rép. : \(reps)", value: $reps, in: 1...100)
                    }.font(.caption)
                    HStack {
                        Text("Charge cible (kg)").font(.caption)
                        Spacer()
                        TextField("0", text: $weight).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 72)
                    }
                    Button("+ AJOUTER CET EXERCICE") { addExercise() }
                        .buttonStyle(.bordered).tint(Nuclear.purple)
                        .disabled(exercises.count >= 12)
                    ForEach(exercises) { target in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(target.name).font(.subheadline.bold())
                                Text("\(target.sets) × \(target.reps) · \(BiluxFormat.number(target.weight, digits: 1)) kg")
                                    .font(.caption2).foregroundStyle(Nuclear.muted)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                exercises.removeAll { $0.id == target.id }
                            } label: { Image(systemName: "minus.circle.fill") }
                        }
                    }
                    Button {
                        addDay()
                    } label: {
                        Label("VALIDER CETTE JOURNÉE", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .disabled(days.count >= 7)
                }
                if !days.isEmpty {
                    SectionCaption(title: "Journées du programme")
                    ForEach(days) { day in
                        NuclearCard {
                            HStack {
                                Text(day.title).font(.subheadline.bold())
                                Spacer()
                                Button(role: .destructive) {
                                    days.removeAll { $0.id == day.id }
                                } label: { Image(systemName: "trash") }
                            }
                            Text("\(day.muscleGroup) · \(day.exercises.count) exercices · \(day.durationMinutes) min")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                        }
                    }
                }
                Button("ENREGISTRER LE PROGRAMME") { save() }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .disabled(days.isEmpty)
                Text("Tes séances existantes ne sont pas modifiées. Tu pourras importer cette journée dans la Forge.")
                    .font(.caption2).foregroundStyle(Nuclear.muted)
            }.padding(15)
        }
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        .modifier(PageBackground())
        .alert("Vérifie le programme", isPresented: Binding(get: { warning != nil },
            set: { if !$0 { warning = nil } })) {
            Button("OK") { warning = nil }
        } message: { Text(warning ?? "") }
    }

    private func addExercise() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 80,
              let load = Double(weight.replacingOccurrences(of: ",", with: ".")),
              load.isFinite, (0...1000).contains(load) else {
            warning = "Précise un exercice (80 caractères maximum) et une charge entre 0 et 1000 kg."
            return
        }
        exercises.append(V73ExerciseTarget(name: trimmed, sets: sets, reps: reps, weight: load))
        exerciseName = ""
    }

    private func addDay() {
        let title = dayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, !exercises.isEmpty,
              let time = Int(duration), (10...240).contains(time) else {
            warning = "Nom de journée, au moins un exercice et durée entre 10 et 240 minutes requis."
            return
        }
        days.append(V73PlannedDay(title: title, muscleGroup: group,
                                 durationMinutes: time, exercises: exercises))
        exercises = []
        dayName = "Séance \(days.count + 1)"
        exerciseName = ""
    }

    private func save() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 80, !days.isEmpty else {
            warning = "Indique un nom de programme (80 caractères maximum) et une journée au minimum."
            return
        }
        if onSave(V73TrainingPlan(title: title, createdAt: .now, days: days)) { dismiss() }
        else { warning = "Impossible de sauvegarder le programme. Réessaie après vérification du stockage." }
    }
}

private struct V73ProgramDetail: View {
    @EnvironmentObject private var journal: BiluxStore
    let planID: UUID
    @State private var ledger = V73Ledger()
    @State private var errorText: String?
    @State private var showVictory = false

    private var plan: V73TrainingPlan? { ledger.plans.first { $0.id == planID } }
    private var progress: V73CampaignProgress? {
        guard let plan else { return nil }
        return V73CampaignEngine.progress(plan: plan, ledger: ledger, workouts: journal.data.workouts)
    }
    private var historicRelics: [String] {
        let counted = max(progress?.counted ?? 0, ledger.highestRelicThreshold[planID] ?? 0)
        var items: [String] = []
        if counted >= 4 { items.append("Sceau de la Brèche") }
        if counted >= 8 { items.append("Aura des Cendres") }
        if counted >= 12 { items.append("Couronne du Néant") }
        return items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let plan, let progress {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(plan.title).font(.title2.weight(.black)).foregroundStyle(Nuclear.paleGold)
                        Text("\(plan.days.count) journées · programme flexible")
                            .font(.caption).foregroundStyle(Nuclear.muted)
                    }
                    V73BossPanel(progress: progress)
                    SectionCaption(title: "Tes journées de Forge")
                    ForEach(plan.days) { day in
                        NuclearCard {
                            Text(day.title).font(.headline.bold()).foregroundStyle(Nuclear.gold)
                            Text("\(day.muscleGroup) · \(day.durationMinutes) min visés")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                            ForEach(day.exercises) { exercise in
                                HStack {
                                    Text(exercise.name)
                                        .font(.subheadline).lineLimit(2)
                                    Spacer(minLength: 3)
                                    Text("\(exercise.sets)×\(exercise.reps) · \(BiluxFormat.number(exercise.weight, digits: 1)) kg")
                                        .font(.caption2).foregroundStyle(Nuclear.paleGold)
                                }
                            }
                            NavigationLink {
                                V70NuclearForge(launch: V73ForgeLaunch(
                                    planID: plan.id, dayID: day.id,
                                    planName: plan.title, day: day))
                                    .environmentObject(journal)
                            } label: {
                                Label("DÉMARRER DANS LA FORGE", systemImage: "dumbbell.fill")
                                    .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.borderedProminent).tint(Nuclear.gold)
                            .disabled(plan.archived)
                            let recorded = linkedForDay(day.id, plan: plan)
                            if !recorded.isEmpty {
                                Text("\(recorded.count) séance(s) reliée(s) au programme")
                                    .font(.caption2).foregroundStyle(Nuclear.purple)
                                if let recent = recorded.last {
                                    Text("Dernière : \(BiluxFormat.day(recent.date)) · \(recent.durationMinutes) min")
                                        .font(.caption2).foregroundStyle(Nuclear.muted)
                                }
                            }
                        }
                    }
                    SectionCaption(title: "Récompenses cosmétiques")
                    NuclearCard {
                        ForEach(["Sceau de la Brèche", "Aura des Cendres", "Couronne du Néant"], id: \.self) { title in
                            HStack {
                                Image(systemName: historicRelics.contains(title) ? "checkmark.seal.fill" : "lock.fill")
                                    .foregroundStyle(historicRelics.contains(title) ? Nuclear.gold : Nuclear.muted)
                                Text(title).font(.subheadline)
                                Spacer()
                                Text(historicRelics.contains(title) ? "ACQUIS" : "VERROUILLÉ")
                                    .font(.caption2).foregroundStyle(Nuclear.muted)
                            }
                        }
                        if historicRelics.contains("Couronne du Néant") {
                            Button("REVOIR LA CINÉMATIQUE DE VICTOIRE") { showVictory = true }
                                .font(.caption.bold()).tint(Nuclear.gold)
                        }
                    }
                    if let date = ledger.firstVictoryDates[planID] ?? progress.victoryDate {
                        NuclearCard {
                            Label("NÉANT VAINCU", systemImage: "crown.fill")
                                .font(.headline.weight(.black)).foregroundStyle(Nuclear.gold)
                            Text("Victoire du \(BiluxFormat.day(date)) · 12 journées éligibles, sans XP supplémentaire.")
                                .font(.caption).foregroundStyle(Nuclear.muted)
                        }
                    }
                    Button(plan.archived ? "RÉACTIVER LE PROGRAMME" : "ARCHIVER LE PROGRAMME") {
                        toggleArchive()
                    }
                    .font(.caption.bold()).tint(Nuclear.purple)
                } else {
                    Text("Programme introuvable. Les séances du journal n'ont pas été touchées.")
                        .font(.subheadline).foregroundStyle(Nuclear.muted)
                }
            }.padding(15)
        }
        .navigationTitle("Campagne RPG")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PageBackground())
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: V73LedgerStore.didChange)) { _ in refresh() }
        .sheet(isPresented: $showVictory) {
            V73VictoryCinema().environmentObject(journal).presentationDragIndicator(.visible)
        }
        .alert("Programme", isPresented: Binding(get: { errorText != nil },
            set: { if !$0 { errorText = nil } })) {
            Button("OK") { errorText = nil }
        } message: { Text(errorText ?? "") }
    }

    private func linkedForDay(_ dayID: UUID, plan: V73TrainingPlan) -> [WorkoutSession] {
        var byID: [UUID: WorkoutSession] = [:]
        for session in journal.data.workouts { byID[session.id] = session }
        return ledger.linkedSessions.filter { $0.planID == plan.id && $0.dayID == dayID }
            .compactMap { byID[$0.workoutID] }.sorted { $0.date < $1.date }
    }

    private func toggleArchive() {
        var next = ledger
        guard let index = next.plans.firstIndex(where: { $0.id == planID }) else { return }
        next.plans[index].archived.toggle()
        do { try V73LedgerStore.persist(next); ledger = next }
        catch { errorText = error.localizedDescription }
    }

    private func refresh() {
        do {
            var next = try V73LedgerStore.load()
            if let plan = next.plans.first(where: { $0.id == planID }) {
                let state = V73CampaignEngine.progress(plan: plan, ledger: next,
                                                       workouts: journal.data.workouts)
                var shouldPersist = false
                if state.counted > (next.highestRelicThreshold[planID] ?? 0) {
                    next.highestRelicThreshold[planID] = state.counted
                    shouldPersist = true
                }
                if state.defeated && next.firstVictoryDates[planID] == nil,
                   let date = state.victoryDate {
                    next.firstVictoryDates[planID] = date
                    shouldPersist = true
                }
                if state.defeated && !next.celebratedPlanIDs.contains(planID) {
                    next.celebratedPlanIDs.append(planID)
                    shouldPersist = true
                    showVictory = true
                }
                if shouldPersist { try V73LedgerStore.persist(next) }
            }
            ledger = next
        } catch { errorText = error.localizedDescription }
    }
}

private struct V73BossPanel: View {
    let progress: V73CampaignProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NuclearCard {
            HStack {
                Image(systemName: progress.defeated ? "crown.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 32)).foregroundStyle(Nuclear.purple)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LE RÉACTEUR DU NÉANT")
                        .font(.headline.weight(.black)).foregroundStyle(Nuclear.paleGold)
                    Text(progress.phase).font(.caption.bold()).foregroundStyle(Nuclear.gold)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: progress.fraction).tint(Nuclear.gold)
            HStack {
                Text("\(progress.counted)/12 journées éligibles")
                Spacer()
                Text("PV : \(progress.hitPoints)/1200")
            }.font(.caption.bold()).foregroundStyle(Nuclear.muted)
            Text("Quatre phases, 12 journées validées : une seule par jour, cinq au plus par semaine. Repos sans pénalité.")
                .font(.caption2).foregroundStyle(Nuclear.muted)
        }
    }
}

private struct V73VictoryCinema: View {
    @EnvironmentObject private var journal: BiluxStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("bilux.effectsEnabled") private var effectsEnabled = true
    var body: some View {
        ZStack {
            Nuclear.background.ignoresSafeArea()
            TimelineView(.animation(minimumInterval: 1.0 / 16.0,
                                    paused: reduceMotion || !effectsEnabled)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let shine = reduceMotion || !effectsEnabled ? 0.4 : (sin(t * 1.2) + 1.0) / 2.0
                Circle()
                    .fill(RadialGradient(colors: [Nuclear.gold.opacity(0.30 + shine * 0.30),
                                                  Nuclear.purple.opacity(0.14), .clear],
                                         center: .center, startRadius: 10, endRadius: 210))
                    .frame(width: 380, height: 380)
            }
            VStack(spacing: 22) {
                Spacer()
                Text("VICTOIRE LÉGENDAIRE")
                    .font(.title2.weight(.black)).tracking(1.6).foregroundStyle(Nuclear.gold)
                V72CoreSeal(stageIndex: journal.unlockedStageIndex,
                               masteryTotal: V63MasterySnapshot.evaluate(journal.data).unlockedTotal)
                    .frame(width: 185, height: 185)
                Text("LE NÉANT S'INCLINE")
                    .font(.title.weight(.black)).foregroundStyle(Nuclear.paleGold)
                    .multilineTextAlignment(.center)
                Text("COURONNE DU NÉANT ACQUISE")
                    .font(.subheadline.weight(.heavy)).foregroundStyle(Nuclear.purple)
                Text("Un exploit cosmétique lié à ton entraînement. Aucun XP supplémentaire.")
                    .font(.caption).foregroundStyle(Nuclear.muted)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("REVENIR À LA FORGE") { dismiss() }
                    .buttonStyle(.borderedProminent).tint(Nuclear.gold)
            }
            .padding(24)
        }
        .accessibilityIdentifier("bilux.v73.victory")
    }
}
