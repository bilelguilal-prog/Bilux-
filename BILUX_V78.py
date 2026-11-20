"""BILUX V7.8 — installer depuis la racine du dépôt."""
import difflib
import pathlib
import plistlib
import re
import subprocess
import sys

ASSETS = {
    "Draft": "    var isFree: Bool { day.planID == V78Reactor.freeID }\n    var volume: Double {\n        actual.flatMap(\\.sets).reduce(0) { $0 + $1.weight * Double($1.reps) }\n    }\n    mutating func selectExercise(_ name: String, history: [V76Target]) {\n        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)\n        guard isFree, !title.isEmpty, title.count <= 80 else { return }\n        let key = V78Reactor.key(title)\n        let previous = history.first { V78Reactor.key($0.name) == key }\n        if let i = day.exercises.firstIndex(where: { V78Reactor.key($0.name) == key }) {\n            index = i\n        } else {\n            // Only confirmed exercises count towards the transfer limit.\n            guard actual.count < 12 else { return }\n            var choices = day.exercises.filter { option in actual.contains { $0.id == option.id } }\n            choices.append(V76Target(id: UUID(), name: title, sets: 12,\n                                     reps: previous?.reps ?? 8, weight: previous?.weight ?? 0))\n            day = V76PlanDay(planID: day.planID, id: day.id, planName: day.planName,\n                             title: day.title, exercises: choices)\n            index = choices.count - 1\n        }\n        guard let option = current else { return }\n        let last = actual.first { $0.id == option.id }?.sets.last\n        weight = last?.weight ?? previous?.weight ?? option.weight\n        reps = Double(last?.reps ?? previous?.reps ?? option.reps)\n    }\n",
    "Phone": "    private func v78History(_ data: BiluxData) -> (recent: [V76Target], model: [V76Target]) {\n        var seen = Set<String>()\n        var history: [V76Target] = []\n        var model: [V76Target] = []\n        for workout in data.workouts.sorted(by: { $0.date > $1.date }) {\n            var targets: [V76Target] = []\n            var sessionNames = Set<String>()\n            for exercise in workout.exercises.reversed() {\n                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)\n                let key = V78Reactor.key(name)\n                guard !key.isEmpty, name.count <= 80,\n                      let set = exercise.sets.last(where: { (1...100).contains($0.reps) && $0.weight.isFinite && (0...1000).contains($0.weight) }),\n                      sessionNames.insert(key).inserted else { continue }\n                let target = V76Target(id: set.id, name: name, sets: 12, reps: set.reps, weight: set.weight)\n                targets.append(target)\n                if history.count < 32, seen.insert(key).inserted { history.append(target) }\n            }\n            if model.isEmpty { model = Array(targets.reversed().prefix(12)) }\n            if history.count == 32 { break }\n        }\n        return (history, model)\n    }\n    private func v78Records(_ workout: WorkoutSession, previous: [WorkoutSession]) -> [String] {\n        var best: [String: Double] = [:]\n        for past in previous where past.id != workout.id && past.date <= workout.date {\n            for exercise in past.exercises {\n                let key = V78Reactor.key(exercise.name)\n                for set in exercise.sets where set.weight.isFinite && set.reps > 0 {\n                    best[key] = max(best[key] ?? 0, set.weight)\n                }\n            }\n        }\n        return workout.exercises.compactMap { exercise in\n            guard let old = best[V78Reactor.key(exercise.name)],\n                  exercise.sets.contains(where: { $0.weight > old && $0.reps > 0 }) else { return nil }\n            return exercise.name\n        }\n    }\n",
    "Shared": "\nstruct V78Debrief: Codable {\n    let id: UUID\n    let xp: Int\n    let records: [String]\n}\n\nenum V78Reactor {\n    static let freeID = UUID(uuidString: \"81F0896A-14F6-4B76-B937-9AC125780078\")!\n    static func key(_ name: String) -> String {\n        name.trimmingCharacters(in: .whitespacesAndNewlines)\n            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: \"fr_FR\"))\n    }\n    static func day(_ targets: [V76Target] = []) -> V76PlanDay {\n        V76PlanDay(planID: freeID, id: UUID(), planName: \"Libre\",\n                   title: \"Séance libre\", exercises: targets)\n    }\n}\n",
    "Watch": "    @State private var exerciseList = false\n    @State private var customName = \"\"\n    private var history: [V76Target] { bridge.snapshot.v78History ?? [] }\n    private let staples = [\"Développé couché\", \"Développé incliné\", \"Tirage vertical\", \"Rowing\",\n                           \"Tractions\", \"Dips\", \"Squat\", \"Presse à cuisses\", \"Curl\", \"Élévations latérales\"]\n    private func choose(_ name: String) {\n        live.selectFreeExercise(name, history: history)\n        exerciseList = false\n        customName = \"\"\n    }\n    private func selector(_ draft: V76ForgeDraft) -> some View {\n        let names = draft.day.exercises.map(\\.name) + draft.actual.map(\\.name) + history.map(\\.name) + staples\n        var keys = Set<String>()\n        let options = names.filter { keys.insert(V78Reactor.key($0)).inserted }\n        let available = Set(draft.actual.map { V78Reactor.key($0.name) })\n        return VStack(alignment: .leading) {\n            Button { exerciseList.toggle() } label: {\n                Label(draft.current?.name ?? \"Choisir un exercice\",\n                      systemImage: exerciseList ? \"chevron.up\" : \"chevron.down\")\n            }.disabled(live.phase != .running)\n            if exerciseList {\n                ForEach(options, id: \\.self) { name in\n                    Button(name) { choose(name) }\n                        .disabled(draft.actual.count >= 12 && !available.contains(V78Reactor.key(name)))\n                }\n                if draft.actual.count < 12 {\n                    TextField(\"Autre exercice\", text: $customName)\n                    Button(\"Utiliser ce nom\") { choose(customName) }\n                        .disabled(V78Reactor.key(customName).isEmpty || customName.count > 80)\n                }\n            }\n            if let name = draft.current?.name,\n               let last = history.first(where: { V78Reactor.key($0.name) == V78Reactor.key(name) }) {\n                Text(\"Dernière séance · \\(last.weight.formatted()) kg × \\(last.reps)\").font(.caption2)\n            }\n            Text(\"\\(draft.count) séries · \\(draft.volume.formatted()) kg de volume\").font(.caption2)\n        }\n    }\n    private func startFree(_ targets: [V76Target]) {\n        exerciseList = targets.isEmpty\n        customName = \"\"\n        Task { await live.start(mode: .strength, bridge: bridge, referenceMaxBPM: reference,\n                                enableHaptics: zoneHaptics, forgeDay: V78Reactor.day(targets)) }\n    }\n"
}
root = pathlib.Path.cwd()
updates = {}

def snippet(name):
    return ASSETS[name]

def change(source, before, after):
    if source.count(before) != 1:
        raise SystemExit("Version du projet incompatible pour " + before[:90])
    return source.replace(before, after, 1)

def modify(path, edits, suffix=""):
    source = (root / path).read_text()
    result = source
    for before, after in edits:
        result = change(result, before, after)
    updates[path] = (source, result + suffix)

watch = "BiluxWatch/WatchRootView.swift"
if not (root / watch).exists():
    sys.exit("Lance cette commande depuis le dossier contenant codemagic.yaml.")
if "func selectFreeExercise(" in (root / watch).read_text():
    print("La V7.8 est déjà présente.")
    sys.exit(0)

start = '                    Button { bridge.refresh() } label: { Label("ACTUALISER LES PROGRAMMES"'
free = '''                    Button("Séance libre") { startFree([]) }
                        .buttonStyle(.borderedProminent).tint(V54ReactorTheme.gold)
                    if let model = bridge.snapshot.v78Model, !model.isEmpty {
                        Button("Reprendre la dernière séance") { startFree(model) }
                    }
                    if let result = live.v78Result {
                        Text(result).font(.caption2)
                        if let report = bridge.snapshot.v78Debrief, report.id == live.v78FinishedID {
                            Text("XP : \\(report.xp) · Records de charge : " +
                                 (report.records.isEmpty ? "aucun" : report.records.joined(separator: ", "))).font(.caption2)
                        }
                    }
'''
summary = '''                    if let draft = self.forgeDraft {
                        self.v78FinishedID = workout.uuid
                        self.v78Result = "\\(draft.count) séries · \\(draft.volume.formatted()) kg de volume"
                    }
'''
before_set = '                Text("SÉRIE \\(draft.currentCount + 1)/\\(target.sets)")'
modify(watch, [
    ('    let day: V76PlanDay\n    var actual:', '    var day: V76PlanDay\n    var actual:'),
    ('    mutating func confirm() {', snippet("Draft") + '    mutating func confirm() {'),
    ('        if currentCount >= target.sets {','        if !isFree && currentCount >= target.sets {'),
    ('    private var forgeRestTask:', '''    @Published private(set) var v78FinishedID: UUID?
    @Published private(set) var v78Result: String?
    func selectFreeExercise(_ name: String, history: [V76Target]) {
        guard phase == .running else { return }
        forgeDraft?.selectExercise(name, history: history)
    }
    private var forgeRestTask:'''),
    ('                    self.clearReferences()\n                    self.phase = .saved', summary + '                    self.clearReferences()\n                    self.phase = .saved'),
    ('    @State private var finishConfirm = false\n    private enum CrownField:', snippet("Watch") + '    @State private var finishConfirm = false\n    private enum CrownField:'),
    (start, free + start),
    ('Crée un programme dans Eternal Forge sur l\'iPhone, puis synchronise la montre.', 'Tes programmes iPhone apparaîtront ici après synchronisation.'),
    ('        if let target = draft.current {\n            V54ReactorCard', '        if draft.isFree { selector(draft) }\n        if let target = draft.current {\n            V54ReactorCard'),
    (before_set,'                Text(draft.isFree ? "\\(draft.currentCount) séries validées" : "SÉRIE \\(draft.currentCount + 1)/\\(target.sets)")'),
    ('                    .disabled(live.phase != .running || draft.restUntil != nil)', '                    .disabled(live.phase != .running || draft.restUntil != nil || draft.currentCount >= target.sets)'),
    ('        } else {\n            Text("PROGRAMME TERMINÉ', '        } else if draft.isFree {\n            Text("Choisis ton premier exercice pour saisir une série.").font(.caption2)\n        } else {\n            Text("PROGRAMME TERMINÉ'),
    ('    @State private var selectedMode: V61LiveMode', '    @State private var showV78Forge = false\n    @State private var selectedMode: V61LiveMode'),
    ('                if !live.inProgress {', '''                if !live.inProgress || live.forgeDraft != nil {
                    Button(live.forgeDraft == nil ? "Réacteur · séance libre ou programme" : "Saisir mes séries") {
                        showV78Forge = true
                    }.sheet(isPresented: $showV78Forge) { V76WatchForge().environmentObject(bridge) }
                }
                if !live.inProgress {'''),
])
modify("BiluxShared/WatchSnapshot.swift", [('    var forgeDayCount: Int? = nil','''    var v78History: [V76Target]? = nil
    var v78Model: [V76Target]? = nil
    var v78Debrief: V78Debrief? = nil
    var forgeDayCount: Int? = nil''')], snippet("Shared"))
phone = "BiluxIOS/WatchPhoneBridge.swift"
before = '        if let old = recoveredEntry {\n            if !old.exercises.isEmpty'
after = '            V76LinkWatchWorkout(forge, workout: entry)'
modify(phone, [
    ('    private func encodedSnapshot() -> Data? {',snippet("Phone") + '    private func encodedSnapshot() -> Data? {'),
    ('        enriched.forgeDayCount = days.count','''        enriched.forgeDayCount = days.count
        if let data = journal?.safeSnapshotData {
            let history = v78History(data)
            enriched.v78History = history.recent
            enriched.v78Model = history.model
            if let raw = UserDefaults.standard.data(forKey: "bilux.v78.debrief"),
               let report = try? JSONDecoder().decode(V78Debrief.self, from: raw),
               data.workouts.contains(where: { $0.id == report.id }) {
                enriched.v78Debrief = report
            }
        }'''),
    (before, '        let xpBefore = journal.totalXP\n        let previousWorkouts = journal.data.workouts\n' + before),
    (after, '''            let report = V78Debrief(id: entry.id, xp: journal.totalXP - xpBefore,
                                   records: v78Records(entry, previous: previousWorkouts))
            if let raw = try? JSONEncoder().encode(report) {
                UserDefaults.standard.set(raw, forKey: "bilux.v78.debrief")
            }
            sendSnapshot()
''' + after),
])
versions = []
for target in ('BiluxIOS','BiluxWatch','BiluxWatchWidget'):
    path = target + '/Info.plist'
    old = (root / path).read_text()
    value = str(plistlib.loads(old.encode())['CFBundleVersion'])
    versions.append(int(value))
    pattern = r'(<key>CFBundleVersion</key>\s*<(?:integer|string)>)' + re.escape(value) + r'(?=</)'
    new, count = re.subn(pattern, lambda m: m[1] + str(int(value)+1), old)
    if count != 1: sys.exit("Version illisible : " + path)
    updates[path] = old, new
if len(set(versions)) != 1: sys.exit("Les trois cibles ont des versions différentes.")
path = 'BiluxIOS.xcodeproj/project.pbxproj'
old = (root / path).read_text()
v = versions[0]
updates[path] = old, old.replace(f'CURRENT_PROJECT_VERSION = {v};', f'CURRENT_PROJECT_VERSION = {v+1};')
patch = ''.join(''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True), 'a/'+p, 'b/'+p))
                for p,(a,b) in updates.items()).encode()
subprocess.run(['git','apply','--check','-'], input=patch, check=True)
subprocess.run(['git','apply','-'], input=patch, check=True)
print(f'V7.8 appliquée · build {v+1}.')
