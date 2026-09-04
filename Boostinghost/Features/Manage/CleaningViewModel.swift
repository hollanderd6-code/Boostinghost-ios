import Foundation
import Observation

@MainActor
@Observable
final class CleaningViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    private(set) var loadState: LoadState = .idle

    private(set) var tightAssignments: [CleaningAssignment] = []
    private(set) var wideAssignments:  [CleaningAssignment] = []

    private(set) var checklistsToValidate: [CleaningChecklist] = []
    private(set) var cleaners:             [CleanerItem]       = []

    var showRejectSheet = false
    var rejectTargetId: String? = nil
    var rejectNotes:    String  = ""

    var todayCount:    Int { tightAssignments.count + wideAssignments.count }
    var validateCount: Int { checklistsToValidate.count }

    var superTitle: String {
        var parts: [String] = []
        if todayCount    > 0 { parts.append("\(todayCount) aujourd'hui") }
        if validateCount > 0 { parts.append("\(validateCount) à valider") }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    // MARK: - Load

    func load(isSubAccount: Bool, reservations: [Reservation] = []) async {
        loadState = .loading

        async let assignmentsResult: CleaningAssignmentsResponse =
            APIClient.shared.get(Endpoint.cleaningAssignments, agencyAll: true)
        async let propertiesResult: PropertiesResponse =
            APIClient.shared.get(Endpoint.properties, agencyAll: true)
        async let checklistsResult: CleaningChecklistsResponse =
            APIClient.shared.get(Endpoint.cleaningChecklists, agencyAll: true)

        let allAssignments = (try? await assignmentsResult)?.assignments ?? []
        let properties     = (try? await propertiesResult)?.properties   ?? []
        let rawChecklists  = (try? await checklistsResult)?.checklists   ?? []

        if !isSubAccount {
            let r: CleanersListResponse? = try? await APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
            cleaners = r?.cleaners ?? []
        } else {
            cleaners = []
        }

        // Filtre : seules les assignations dont le checkout tombe aujourd'hui.
        // reservation_key format réel : "<propertyId>_YYYY-MM-DD_YYYY-MM-DD".
        // Le ménage se fait au départ → la SECONDE date (suffix 10) est la référence.
        // Format virtuel cassé ("Mon Apr 20") : le suffix commence par une lettre → exclu.
        // Calendar components évitent le glissement de date à minuit vs UTC.
        let cal      = Calendar(identifier: .gregorian)
        let dc       = cal.dateComponents([.year, .month, .day], from: Date())
        let todayStr = String(format: "%04d-%02d-%02d", dc.year!, dc.month!, dc.day!)

        let todayAssignments = allAssignments.filter { a in
            guard let key = a.reservationKey, key.count >= 10 else { return false }
            let suffix = String(key.suffix(10))
            guard suffix.first?.isNumber == true else { return false }
            return suffix == todayStr
        }

        // Dictionnaires pour la résolution des noms et des créneaux.
        let nameByProp = properties.reduce(into: [String: String]()) { d, p in
            d[p.id] = p.internalName ?? p.name
        }
        let depTimeByProp = properties.reduce(into: [String: String]()) { d, p in
            if let t = p.departureTime { d[p.id] = t }
        }
        let arrTimeByProp = properties.reduce(into: [String: String]()) { d, p in
            if let t = p.arrivalTime  { d[p.id] = t }
        }

        // Index des réservations réelles (non-block) par logement, trié par date de début.
        // On copie les clés avant de trier pour éviter toute mutation concurrente du dict.
        var resaByProp = [String: [Reservation]]()
        for r in reservations where !r.isBlock {
            resaByProp[r.propertyId, default: []].append(r)
        }
        let propKeys = Array(resaByProp.keys)
        for key in propKeys {
            resaByProp[key]?.sort { $0.startDate < $1.startDate }
        }

        // Source unique pour cartes, compteur et calcul de créneau.
        let resolved: [CleaningAssignment] = todayAssignments.map { a in
            var a = a
            guard let pid = a.propertyId else { return a }
            a.resolvedPropertyName = nameByProp[pid]

            // Borne gauche : heure de départ du logement.
            a.windowStart = depTimeByProp[pid]

            // Borne droite : heure d'arrivée du logement, uniquement si la prochaine
            // réservation démarre CE JOUR. Une arrivée demain ou plus tard → nil → LARGE.
            // Les deux bornes sont "HH:mm" ; parseWindowTime les ancre à aujourd'hui,
            // donc un créneau cross-day donnerait une durée fausse.
            if let nextResa = resaByProp[pid]?.first(where: { $0.startDate >= todayStr }),
               nextResa.startDate == todayStr {
                a.windowEnd = arrTimeByProp[pid]
            }

            return a
        }

        #if DEBUG
        print("[DEBUG-CLEANING] reçu=\(allAssignments.count) → filtrés=\(resolved.count) (\(todayStr))")
        for a in resolved {
            let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
            let d   = dur.map { String(format: "%.0f min", $0 / 60) } ?? "nil"
            print("[DEBUG-CLEANING]   \(a.resolvedPropertyName ?? a.propertyId ?? "?")  start=\(a.windowStart ?? "nil")  end=\(a.windowEnd ?? "nil")  dur=\(d)")
        }
        #endif

        let tightThreshold: TimeInterval = 6 * 3600
        tightAssignments = resolved.filter { a in
            guard let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
            else { return false }
            return dur <= tightThreshold
        }
        wideAssignments = resolved.filter { a in
            let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
            return dur == nil || dur! > tightThreshold
        }

        // Checklists à valider : status "completed"
        checklistsToValidate = rawChecklists
            .filter { $0.status == "completed" }
            .map { c in
                var c = c
                c.resolvedPropertyName = c.propertyId.flatMap { nameByProp[$0] }
                return c
            }

        loadState = .loaded
    }

    // MARK: - Actions

    func validate(checklist: CleaningChecklist) async {
        let url = Endpoint.checklistValidate(checklist.id)
        try? await APIClient.shared.putVoid(url, body: EmptyBody(), agencyAll: true)
        checklistsToValidate.removeAll { $0.id == checklist.id }
    }

    func reject(checklist: CleaningChecklist, notes: String) async {
        let url  = Endpoint.checklistReject(checklist.id)
        let body = RejectBody(notes: notes)
        try? await APIClient.shared.putVoid(url, body: body, agencyAll: true)
        checklistsToValidate.removeAll { $0.id == checklist.id }
    }
}
