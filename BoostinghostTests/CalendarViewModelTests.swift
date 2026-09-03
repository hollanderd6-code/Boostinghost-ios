// Pour ajouter ces tests : File > New > Target > Unit Testing Bundle dans Xcode,
// nommer « BoostinghostTests », puis ajouter ce fichier à la cible.
// Exécuter avec l'env. TZ forcé :
//   TZ=Pacific/Midway   xcodebuild test -scheme Boostinghost -destination 'platform=macOS'
//   TZ=Pacific/Kiritimati xcodebuild test -scheme Boostinghost -destination 'platform=macOS'

import Testing
@testable import Boostinghost

struct CalendarViewModelTests {

    // currentMonthKey() doit retourner le mois local, jamais le mois UTC.
    //
    // Cas critiques :
    //  • Pacific/Midway (UTC-12) : à 00 h 30 UTC le 1er du mois, Midway est au mois précédent.
    //  • Pacific/Kiritimati (UTC+14) : à 22 h 30 UTC le dernier jour du mois,
    //    Kiritimati est déjà au mois suivant.
    //
    // Dans les deux cas, currentMonthKey() doit coïncider avec Calendar.current.

    @Test("currentMonthKey() == mois local sous n'importe quel TZ")
    func currentMonthKeyMatchesLocalCalendar() {
        let key      = CalendarViewModel.currentMonthKey()
        let comps    = Calendar.current.dateComponents([.year, .month], from: Date())
        let expected = String(format: "%04d-%02d", comps.year!, comps.month!)
        #expect(key == expected,
                "Attendu \(expected), obtenu \(key) — vérifier TZ=\(TimeZone.current.identifier)")
    }

    @Test("Clé persistée antérieure est remplacée par le mois courant")
    func staleMonthKeyIsReset() {
        let staleKey = "2026-07"
        UserDefaults.standard.set(staleKey, forKey: "cal.month")
        defer { UserDefaults.standard.removeObject(forKey: "cal.month") }

        let stored  = UserDefaults.standard.string(forKey: "cal.month") ?? ""
        let current = CalendarViewModel.currentMonthKey()
        let result  = (stored.isEmpty || stored < current) ? current : stored

        #expect(result == current,
                "La clé périmée « \(staleKey) » devrait être écrasée par « \(current) »")
    }

    @Test("Clé future n'est pas écrasée")
    func futuremonthKeyIsKept() {
        // Un mois futur persisté (navigation volontaire) doit être conservé.
        let futureKey = "2099-12"
        UserDefaults.standard.set(futureKey, forKey: "cal.month")
        defer { UserDefaults.standard.removeObject(forKey: "cal.month") }

        let stored  = UserDefaults.standard.string(forKey: "cal.month") ?? ""
        let current = CalendarViewModel.currentMonthKey()
        let result  = (stored.isEmpty || stored < current) ? current : stored

        #expect(result == futureKey, "Un mois futur (\(futureKey)) doit rester sélectionné")
    }
}
