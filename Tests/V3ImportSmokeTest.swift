import Foundation

enum ImportIssue: LocalizedError { case invalidFile }

@main
struct V3ImportSmokeTest {
    static func main() throws {
        let json = #"""
        {
          "version":1,
          "profile":{"alias":"Bilux","calorieGoal":"2700"},
          "sessions":[{"id":"s-100","date":"2026-11-08","activity":"Musculation","duration":80,"rpe":"8","notes":"Séance test","exercises":[{"name":"Tractions","series":[{"reps":9,"weight":0,"done":true},{"reps":0,"weight":0,"done":false}]}]}],
          "meals":[{"id":"m-1","date":"2026-11-08","name":"Déjeuner","calories":690,"protein":42,"carbs":71,"fat":20,"water":380}],
          "checkins":[{"id":"c-1","date":"2026-11-08","energy":8,"fatigue":3,"sleep":7.5,"weight":90.1,"medication":"pris","symptoms":"RAS"}],
          "labs":[{"id":"l-1","date":"2026-11-01","tsh":"0,35","ft4":"16,1","notes":"Exemple"}]
        }
        """#
        let source = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        let d = try V3Import.parse(source)
        precondition(d.workouts.count == 1 && d.meals.count == 1 && d.checkins.count == 1 && d.labs.count == 1)
        precondition(d.workouts[0].exercises[0].sets.count == 1)
        precondition(d.workouts[0].rpe == 8)
        precondition(d.meals[0].waterML == 380)
        precondition(d.checkins[0].weightKG == 90.1 && d.checkins[0].medicationNote == "pris")
        precondition(d.labs[0].t4l == 16.1)
        precondition(d.caloriesGoal == 2700)
        let rerun = try V3Import.parse(source)
        precondition(rerun.workouts[0].id == d.workouts[0].id)
        print("V3Import OK — séries, repas/eau, poids/traitement, TSH/T4L et identifiants stables")
    }
}
