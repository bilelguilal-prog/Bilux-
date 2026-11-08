import Foundation

enum ImportIssue: LocalizedError { case invalidFile }

@main struct Check {
    static func main() throws {
        let raw = #"""
        {"version":1,"profile":{"alias":"Bilux","calorieGoal":"2700"},
        "sessions":[{"id":"abc","date":"2026-11-08","activity":"Musculation","duration":80,
          "exercises":[{"name":"Développé couché","series":[{"reps":8,"weight":60,"done":true},{"reps":7,"weight":60,"done":true}]}]}],
        "meals":[{"id":"meal1","date":"2026-11-08","name":"Repas","calories":600,"protein":40,"carbs":55,"fat":20}],
        "checkins":[{"id":"check1","date":"2026-11-08","energy":7,"fatigue":3,"sleep":7.5,"weight":90,"medication":"prise confirmée","symptoms":"fatigue légère"}],
        "labs":[{"id":"lab1","date":"2026-11-07","tsh":0.3,"ft4":17.2,"notes":"laboratoire"}]}
        """#
        let obj = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String:Any]
        let first = try V3Import.parse(obj)
        let second = try V3Import.parse(obj)
        precondition(first.workouts.count == 1 && first.workouts[0].volume == 900)
        precondition(first.workouts[0].id == second.workouts[0].id)
        precondition(first.meals.first?.kcal == 600)
        precondition(first.checkins.first?.weightKG == 90)
        precondition(first.checkins.first?.medicationNote == "prise confirmée")
        precondition(first.labs.first?.t4l == 17.2)
        precondition(first.caloriesGoal == 2700)
        print("✓ Import V3 JSON: 1 séance, 1 repas, 1 bilan, 1 laboratoire; IDs stables; séries et volume conservés")
    }
}
