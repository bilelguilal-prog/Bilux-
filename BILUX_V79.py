"""BILUX V7.9 • Lancer dans le dépôt BILUX."""
import difflib
import pathlib
import plistlib
import re
import subprocess
import sys

TODAY = '\n// MARK: - BILUX V7.9\nprivate struct V79Today: View {\n    @EnvironmentObject private var journal: BiluxStore\n    @Binding var selectedTab: Int\n    @AppStorage("bilux.v79.lastReceivedWorkout") private var lastReceived = ""\n    @AppStorage("bilux.v78.debrief") private var priorDebrief = Data()\n    @State private var sheet: FormSheet?\n    private enum FormSheet: String, Identifiable {\n        case meal, checkin, headquarters\n        var id: Self { self }\n    }\n\n    var body: some View {\n        NavigationStack {\n            ScrollView {\n                VStack(alignment: .leading, spacing: 16) {\n                    Button { selectedTab = 4 } label: {\n                        HStack(spacing: 12) {\n                            Image("BiluxHero").resizable().scaledToFill()\n                                .frame(width: 56, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))\n                            VStack(alignment: .leading, spacing: 4) {\n                                Text("Niveau \\(journal.heroLevel) · \\(journal.rankName)").font(.headline)\n                                ProgressView(value: journal.xpFraction).tint(Nuclear.gold)\n                                Text("\\(journal.totalXP) XP").font(.caption.monospacedDigit())\n                            }\n                            Image(systemName: "chevron.right").accessibilityHidden(true)\n                        }.padding(12).background(Nuclear.panel, in: RoundedRectangle(cornerRadius: 14))\n                    }.buttonStyle(.plain).accessibilityHint("Ouvre Ascension")\n                    NavigationLink { V79ExerciseChoice() } label: {\n                        Label("Séance libre", systemImage: "dumbbell.fill")\n                            .frame(maxWidth: .infinity, minHeight: 44)\n                    }.buttonStyle(.borderedProminent).tint(Nuclear.gold).foregroundStyle(.black)\n                    VStack(spacing: 2) {\n                        action("Ajouter un repas", icon: "fork.knife", sheet: .meal)\n                        action("Faire mon bilan", icon: "heart.text.square", sheet: .checkin)\n                    }\n                    Text("Dernière séance").font(.headline)\n                    if let workout = journal.safeSnapshotData?.workouts.max(by: { $0.date < $1.date }) {\n                        NavigationLink { V79WorkoutDetail(workout: workout) } label: {\n                            NuclearCard {\n                                HStack {\n                                    Text(workout.activity).font(.headline)\n                                    Spacer()\n                                    Image(systemName: "chevron.right").font(.caption)\n                                }\n                                Text(workout.date.formatted(.dateTime.day().month(.wide).year()))\n                                Text("\\(workout.durationMinutes) min · \\(workout.exercises.reduce(0) { $0 + $1.sets.count }) séries")\n                                if workout.id.uuidString == lastReceived || (try? JSONDecoder().decode(V78Debrief.self, from: priorDebrief))?.id == workout.id {\n                                    Label("Reçue de la Watch", systemImage: "checkmark.circle.fill")\n                                        .font(.caption.bold()).foregroundStyle(Nuclear.gold)\n                                }\n                            }\n                        }.buttonStyle(.plain)\n                    } else {\n                        Text("Ta première séance enregistrée apparaîtra ici.").foregroundStyle(.secondary)\n                    }\n                    action("Ouvrir le QG", icon: "bolt.shield", sheet: .headquarters)\n                }.padding()\n            }\n            .modifier(PageBackground()).navigationTitle("Aujourd’hui")\n        }\n        .sheet(item: $sheet) { item in\n            switch item {\n            case .meal: NewMealScreen()\n            case .checkin: NewCheckinScreen()\n            case .headquarters: HomeScreen(selectedTab: $selectedTab)\n            }\n        }\n        .onChange(of: selectedTab) { value in if value != 0 { sheet = nil } }\n    }\n\n    private func action(_ title: String, icon: String, sheet destination: FormSheet) -> some View {\n        Button { sheet = destination } label: {\n            Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)\n                .frame(minHeight: 44)\n        }.buttonStyle(.bordered).tint(Nuclear.gold)\n    }\n}\n\nprivate struct V79ExerciseChoice: View {\n    @EnvironmentObject private var journal: BiluxStore\n    @State private var query = ""\n    private var history: [String: WorkoutExercise] {\n        var found: [String: WorkoutExercise] = [:]\n        for workout in journal.data.workouts.sorted(by: { $0.date > $1.date }) {\n            for exercise in workout.exercises.reversed() where !exercise.sets.isEmpty {\n                let key = V78Reactor.key(exercise.name)\n                if !key.isEmpty && found[key] == nil { found[key] = exercise }\n            }\n        }\n        return found\n    }\n    var body: some View {\n        let recent = history\n        let favorites = ["Développé couché", "Tractions", "Rowing", "Dips", "Presse à cuisses", "Curl"]\n        let terms = (recent.values.map(\\.name).sorted() + favorites)\n        var seen = Set<String>()\n        let key = V78Reactor.key(query)\n        let names = terms.filter {\n            let name = V78Reactor.key($0)\n            return seen.insert(name).inserted && (key.isEmpty || name.contains(key))\n        }\n        return List {\n            if !key.isEmpty && !names.contains(where: { V78Reactor.key($0) == key }) {\n                row(query.trimmingCharacters(in: .whitespacesAndNewlines), previous: nil)\n            }\n            ForEach(names, id: \\.self) { name in\n                row(name, previous: recent[V78Reactor.key(name)]?.sets.last)\n            }\n        }\n        .searchable(text: $query, prompt: "Chercher ou saisir un exercice")\n        .navigationTitle("Séance libre")\n    }\n    private func row(_ name: String, previous: WorkoutSet?) -> some View {\n        NavigationLink {\n            V70NuclearForge(v79Name: name, v79Previous: previous)\n        } label: {\n            VStack(alignment: .leading, spacing: 3) {\n                Text(name)\n                if let set = previous {\n                    Text("Dernière série · \\(set.weight.formatted()) kg × \\(set.reps)")\n                        .font(.caption).foregroundStyle(.secondary)\n                }\n            }\n        }\n    }\n}\n\nprivate struct V79WorkoutDetail: View {\n    let workout: WorkoutSession\n    var body: some View {\n        List {\n            Section {\n                Text(workout.date.formatted(date: .long, time: .omitted))\n                Text("\\(workout.durationMinutes) min")\n            }\n            if workout.exercises.isEmpty {\n                Text("Aucune série consignée pour cette séance.").foregroundStyle(.secondary)\n            }\n            ForEach(workout.exercises) { exercise in\n                Section(exercise.name) {\n                    ForEach(Array(exercise.sets.enumerated()), id: \\.element.id) { index, set in\n                        HStack {\n                            Text("Série \\(index + 1)")\n                            Spacer()\n                            Text("\\(set.weight.formatted()) kg × \\(set.reps)").monospacedDigit()\n                        }\n                    }\n                }\n            }\n        }.navigationTitle(workout.activity)\n    }\n}\n'
root = pathlib.Path.cwd()
changes = {}
def read(path):
    return (root / path).read_text()
def replace_once(source, old, new):
    if source.count(old) != 1:
        sys.exit("Source différente de la V7.8 attendue : " + old[:100])
    return source.replace(old, new, 1)
def stage(path, result):
    changes[path] = read(path), result

screen = 'BiluxIOS/BiluxScreens.swift'
bridge = 'BiluxIOS/WatchPhoneBridge.swift'
if not (root / screen).is_file():
    sys.exit("Place-toi dans le dossier qui contient codemagic.yaml.")
if 'private struct V79Today: View' in read(screen):
    print("L’accueil V7.9 est déjà installé.")
    sys.exit(0)
s = read(screen)
s = replace_once(s, 'HomeScreen(selectedTab: $selected)', 'V79Today(selectedTab: $selected)')
start = s.index('private struct V70NuclearForge: View')
end = s.index('private struct V70NuclearAnalytics: View', start)
forge = s[start:end]
marker = '    var launch: V73ForgeLaunch? = nil'
forge = replace_once(forge, marker, marker + '''
    var v79Name: String? = nil
    var v79Previous: WorkoutSet? = nil
    @State private var v79Opened = false''')
marker = '        .onAppear(perform: prefillFromProgram)'
forge = replace_once(forge, marker, marker + '''
        .onAppear {
            guard !v79Opened, launch == nil, let name = v79Name else { return }
            v79Opened = true
            exerciseName = name
            if let set = v79Previous {
                draftSets = [V70DraftSet(reps: String(set.reps), weight: String(set.weight))]
            }
        }''')
# Put the series first on the quick-entry route. Keep the full form accessible.
anchor = '                NuclearCard {\n                    DatePicker("Date", selection: $sessionDate'
a = forge.index(anchor)
b = forge.index('\n                if !prepared.isEmpty', a)
card = forge[a:b].strip()
if not card.endswith('}') or 'Notes de séance' not in card:
    sys.exit("Carte de réglages de séance inconnue.")
forge = forge[:a]+'''                if v79Name == nil {
                    v79SessionSettings
                } else {
                    DisclosureGroup("Durée : \\(duration) min · Détails") { v79SessionSettings }
                }
''' + forge[b:]
marker = '    private func makeCurrentExercise()'
forge = replace_once(forge, marker, '    private var v79SessionSettings: some View {\n        '+card+'\n    }\n\n'+marker)
stage(screen, s[:start] + forge + s[end:] + '\n' + TODAY)
s = read(bridge)
if 'let report = V78Debrief(' not in s:
    sys.exit("Le build avec les séances libres V7.8 est requis.")
marker = '                if journal.safeSnapshotData?.workouts.contains(where: { $0.id == id && !$0.notes.hasPrefix("Récupération V7.6.1 depuis Apple Santé") }) == true {'
stage(bridge, replace_once(s, marker, marker+'\n                    UserDefaults.standard.set(id.uuidString, forKey: "bilux.v79.lastReceivedWorkout")'))
versions = set()
for target in ['BiluxIOS','BiluxWatch','BiluxWatchWidget']:
    path = target+'/Info.plist'
    s = read(path)
    v = int(plistlib.loads(s.encode())['CFBundleVersion'])
    versions.add(v)
    pattern = r'(<key>CFBundleVersion</key>\s*<(?:string|integer)>)'+str(v)+r'(?=</)'
    new, count = re.subn(pattern, lambda m: m[1]+str(v+1), s)
    if count != 1: sys.exit('Version illisible : '+path)
    stage(path,new)
if len(versions) != 1: sys.exit('Les trois numéros de build diffèrent.')
path = 'BiluxIOS.xcodeproj/project.pbxproj'
s = read(path)
stage(path,s.replace(f'CURRENT_PROJECT_VERSION = {v};',f'CURRENT_PROJECT_VERSION = {v+1};'))
patch = ''.join(''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True),'a/'+p,'b/'+p)) for p,(a,b) in changes.items()).encode()
subprocess.run(['git','apply','--check','-'],input=patch,check=True)
if '--check' not in sys.argv:
    subprocess.run(['git','apply','-'],input=patch,check=True)
print(f'BILUX V7.9 · build {v+1} · '+('vérifié' if '--check' in sys.argv else 'appliqué'))
