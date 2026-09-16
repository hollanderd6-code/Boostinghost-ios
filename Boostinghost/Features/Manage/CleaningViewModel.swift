import Foundation
import Observation

@MainActor
@Observable
final class CleaningViewModel {

    enum LoadState { case idle, loading, loaded, error(String) }

    // MARK: - État

    private(set) var loadState: LoadState = .idle

    private(set) var tightAssignments:     [CleaningAssignment] = []
    private(set) var wideAssignments:      [CleaningAssignment] = []
    private(set) var checklistsToValidate: [CleaningChecklist]  = []
    private(set) var cleaners:             [CleanerItem]        = []

    private(set) var weekGroups:          [CleaningDayGroup]    = []

    private(set) var historyItems:        [CleaningHistoryItem] = []
    private(set) var historyCleanerNames: [String]              = []
    var historyCleanerFilter: String? = nil

    var showRejectSheet = false
    var rejectTargetId: String? = nil
    var rejectNotes:    String  = ""

    // MARK: - Calculés

    var todayCount:        Int { tightAssignments.count + wideAssignments.count }
    var validateCount:     Int { checklistsToValidate.count }
    var weekCount:         Int { weekGroups.reduce(0) { $0 + $1.tight.count + $1.wide.count } }
    var historyTotalCount: Int { historyItems.count }

    var superTitle: String {
        var parts: [String] = []
        if todayCount    > 0 { parts.append("\(todayCount) aujourd'hui") }
        if validateCount > 0 { parts.append("\(validateCount) à valider") }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    var filteredHistoryGroups: [CleaningHistoryGroup] {
        let items = historyCleanerFilter.map { f in historyItems.filter { $0.effectiveCleanerName == f } } ?? historyItems
        var grouped: [String: [CleaningHistoryItem]] = [:]
        for item in items { grouped[item.dateStr, default: []].append(item) }
        return grouped.keys.sorted(by: >).map { CleaningHistoryGroup(dateStr: $0, items: grouped[$0]!) }
    }

    // MARK: - Chargement

    func load(isSubAccount: Bool) async {
        if case .loaded = loadState {} else { loadState = .loading }

        // Un sous-compte cleaner n'a pas can_view_properties → utiliser l'endpoint
        // dédié qui renvoie uniquement id/name/arrivalTime/departureTime/color
        // derrière can_view_cleaning. Pour un compte principal, garder /api/properties.
        let propEndpoint = isSubAccount ? Endpoint.cleaningPropertyNames : Endpoint.properties

        async let assignmentsResult: CleaningAssignmentsResponse =
            APIClient.shared.get(Endpoint.cleaningAssignments, agencyAll: true)
        async let propertiesResult: PropertiesResponse =
            APIClient.shared.get(propEndpoint, agencyAll: true)
        async let checklistsResult: CleaningChecklistsResponse =
            APIClient.shared.get(Endpoint.cleaningChecklists, agencyAll: true)
        async let reservationsResult: ReservationsResponse =
            APIClient.shared.get(Endpoint.reservations, agencyAll: true)

        let allAssignments = (try? await assignmentsResult)?.assignments ?? []
        let properties: [Property]
        do {
            properties = try await propertiesResult.properties ?? []
        } catch {
            // 403 = cleaner sans can_view_properties sur /api/properties (ne devrait
            // plus arriver après migration vers cleaningPropertyNames, mais loggé pour
            // ne pas avaler l'erreur silencieusement).
            print("[CleaningVM] ⚠️ GET propriétés échoué (\(propEndpoint.path)): \(error) — les noms de logements ne seront pas résolus.")
            properties = []
        }
        let rawChecklists  = (try? await checklistsResult)?.checklists   ?? []
        let reservations   = (try? await reservationsResult)?.reservations ?? []

        if !isSubAccount {
            let r: CleanersListResponse? = try? await APIClient.shared.get(Endpoint.cleaners, agencyAll: true)
            cleaners = r?.cleaners ?? []
        } else {
            cleaners = []
        }

        // Références de dates (Calendar components, jamais DateFormatter avec fuseau local)
        let cal        = Calendar(identifier: .gregorian)
        let todayStart = cal.startOfDay(for: Date())
        let dc         = cal.dateComponents([.year, .month, .day], from: todayStart)
        let todayStr   = String(format: "%04d-%02d-%02d", dc.year!, dc.month!, dc.day!)

        // Dictionnaires logement
        let nameByProp = properties.reduce(into: [String: String]()) { d, p in
            d[p.id] = p.internalName ?? p.name
        }
        let depTimeByProp = properties.reduce(into: [String: String]()) { d, p in
            if let t = p.departureTime { d[p.id] = t }
        }
        let arrTimeByProp = properties.reduce(into: [String: String]()) { d, p in
            if let t = p.arrivalTime { d[p.id] = t }
        }

        // Index réservations par logement (Array(keys) pour éviter la mutation concurrente)
        var resaByPropMut = [String: [Reservation]]()
        for r in reservations where !r.isBlock {
            resaByPropMut[r.propertyId, default: []].append(r)
        }
        let propKeys = Array(resaByPropMut.keys)
        for key in propKeys { resaByPropMut[key]?.sort { $0.startDate < $1.startDate } }
        let resaByProp = resaByPropMut

        #if DEBUG
        print("[SLOT] reservations reçues=\(reservations.count) logements indexés=\(resaByProp.count)")
        #endif

        // Index checklists par reservation_key (pour l'Historique)
        let checklistByKey: [String: CleaningChecklist] = rawChecklists.reduce(into: [:]) { d, c in
            if let key = c.reservationKey { d[key] = c }
        }

        #if DEBUG
        let avecKey = rawChecklists.filter { $0.reservationKey != nil }.count
        print("[DEBUG-CL] rawChecklists=\(rawChecklists.count)  avecReservationKey=\(avecKey)  indexés=\(checklistByKey.count)")
        for c in rawChecklists.prefix(5) {
            print("[DEBUG-CL]   id=\(c.id)  key=\(c.reservationKey ?? "nil")  ownerStatus=\(c.ownerStatus ?? "nil")  completedAt=\(c.completedAt ?? "nil")")
        }
        #endif

        let tightThreshold: TimeInterval = 6 * 3600

        // Filtre par date : suffix(10) == dayStr, format réel uniquement (commence par un chiffre).
        // Déduplique par reservationKey — le serveur peut renvoyer deux fois la même assignation virtuelle.
        func dayAssignments(_ dayStr: String) -> [CleaningAssignment] {
            var seen = Set<String>()
            return allAssignments.filter { a in
                guard let key = a.reservationKey, key.count >= 10 else { return false }
                let suffix = String(key.suffix(10))
                guard suffix.first?.isNumber == true, suffix == dayStr else { return false }
                return seen.insert(key).inserted
            }
        }

        // Résolution du nom, du créneau et de la checklist liée pour un jour donné
        var slotLogDone = false
        func resolve(_ a: CleaningAssignment, dayStr: String) -> CleaningAssignment {
            var a = a
            guard let pid = a.propertyId else { return a }
            a.resolvedPropertyName = nameByProp[pid]
            a.windowStart = depTimeByProp[pid]
            #if DEBUG
            if !slotLogDone {
                slotLogDone = true
                let resasForPid = resaByProp[pid] ?? []
                print("[SLOT] premier ménage prop=\(nameByProp[pid] ?? pid) pid=\(pid) dayStr=\(dayStr)")
                print("[SLOT]   résas pour ce logement=\(resasForPid.count) startDates=\(resasForPid.map(\.startDate))")
            }
            #endif
            if resaByProp[pid]?.contains(where: { $0.startDate == dayStr }) == true {
                a.windowEnd = arrTimeByProp[pid]
            }
            a.checklistId = a.reservationKey.flatMap { checklistByKey[$0]?.id }
            return a
        }

        // Classification SERRÉ / LARGE
        func classify(_ items: [CleaningAssignment]) -> (tight: [CleaningAssignment], wide: [CleaningAssignment]) {
            (
                items.filter { a in
                    guard let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
                    else { return false }
                    return dur <= tightThreshold
                },
                items.filter { a in
                    let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
                    return dur == nil || dur! > tightThreshold
                }
            )
        }

        // MARK: Aujourd'hui
        let resolvedToday = dayAssignments(todayStr).map { resolve($0, dayStr: todayStr) }

        #if DEBUG
        print("[DEBUG-CLEANING] reçu=\(allAssignments.count) → filtrés=\(resolvedToday.count) (\(todayStr))")
        for a in resolvedToday {
            let dur = CleaningAssignment.slotDuration(start: a.windowStart, end: a.windowEnd)
            let d   = dur.map { String(format: "%.0f min", $0 / 60) } ?? "nil"
            print("[DEBUG-CLEANING]   \(a.resolvedPropertyName ?? a.propertyId ?? "?")  start=\(a.windowStart ?? "nil")  end=\(a.windowEnd ?? "nil")  dur=\(d)")
            print("[DEBUG-DUP]     propertyId=\(a.propertyId ?? "nil")  reservationKey=\(a.reservationKey ?? "nil")  isDefault=\(a.isDefault.map(String.init) ?? "nil")  cleanerName=\(a.cleanerName ?? "nil")")
        }
        #endif

        let (todayTight, todayWide) = classify(resolvedToday)
        tightAssignments = todayTight
        wideAssignments  = todayWide

        checklistsToValidate = rawChecklists
            .filter { $0.ownerStatus == "pending" }
            .map { c in
                var c = c
                // resolvedPropertyName : dict d'abord (compte principal), puis champ
                // serveur comme repli (cleaner dont GET /api/properties était 403)
                c.resolvedPropertyName = c.propertyId.flatMap { nameByProp[$0] }
                    ?? c.propertyName
                return c
            }

        // MARK: Semaine (J+1 à J+7)
        weekGroups = (1...7).compactMap { n -> CleaningDayGroup? in
            guard let date = cal.date(byAdding: .day, value: n, to: todayStart) else { return nil }
            let dc2    = cal.dateComponents([.year, .month, .day], from: date)
            let dayStr = String(format: "%04d-%02d-%02d", dc2.year!, dc2.month!, dc2.day!)
            let items  = dayAssignments(dayStr).map { resolve($0, dayStr: dayStr) }
            guard !items.isEmpty else { return nil }
            let (tight, wide) = classify(items)
            return CleaningDayGroup(dateStr: dayStr, tight: tight, wide: wide)
        }

        // MARK: Historique (J-1 à J-30)
        let historySet: Set<String> = Set((1...30).compactMap { n -> String? in
            guard let date = cal.date(byAdding: .day, value: -n, to: todayStart) else { return nil }
            let dc2 = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", dc2.year!, dc2.month!, dc2.day!)
        })

        var historySeen = Set<String>()
        historyItems = allAssignments.compactMap { a -> CleaningHistoryItem? in
            guard let key = a.reservationKey, key.count >= 10 else { return nil }
            let suffix = String(key.suffix(10))
            guard suffix.first?.isNumber == true, historySet.contains(suffix) else { return nil }
            guard historySeen.insert(key).inserted else { return nil }
            let propName = a.propertyId.flatMap { nameByProp[$0] }
                ?? a.propertyName
                ?? a.reservationKey.flatMap { checklistByKey[$0]?.propertyName }
            return CleaningHistoryItem(
                dateStr: suffix,
                propertyId: a.propertyId,
                propertyName: propName,
                cleanerName: a.cleanerName,
                checklistCleanerName: checklistByKey[key]?.cleanerName,
                checklistStatus: checklistByKey[key]?.ownerStatus,
                checklistId: checklistByKey[key]?.id
            )
        }.sorted { $0.dateStr > $1.dateStr }

        historyCleanerNames = Array(
            Set(historyItems.compactMap { $0.effectiveCleanerName }.filter { !$0.isEmpty })
        ).sorted()

        #if DEBUG
        print("[DEBUG-HIST] allAssignments=\(allAssignments.count) historyItems=\(historyItems.count)")
        let histAvecId     = historyItems.filter { $0.checklistId != nil }.count
        let histAvecStatus = historyItems.filter { $0.checklistStatus != nil }.count
        var statusDist: [String: Int] = [:]
        for item in historyItems { statusDist[item.checklistStatus ?? "nil", default: 0] += 1 }
        let distStr = statusDist.sorted { $0.value > $1.value }.map { "\($0.key)×\($0.value)" }.joined(separator: "  ")
        print("[DEBUG-HIST] avecChecklistId=\(histAvecId)  avecStatus=\(histAvecStatus)  dist: \(distStr)")

        // Diagnostic croisement : pour les items sans checklist, compare le suffix date
        // de la reservationKey de l'assignation avec les suffixes des checklists indexées.
        // Si clMêmeDate > 0 → les clés partagent la même date mais diffèrent avant.
        // Si clMêmeDate = 0 → les dates sont différentes (hypothèse : assignation = séjour
        // à venir, checklist = séjour qui vient de finir).
        let sansChecklist = historyItems.filter { $0.checklistId == nil }.prefix(5)
        if !sansChecklist.isEmpty {
            print("[DEBUG-CROSS] \(sansChecklist.count) items sans checklist (total historyItems=\(historyItems.count))")
            let clSuffixes: [(key: String, suffix: String)] = checklistByKey.keys.compactMap { ck in
                guard ck.count >= 10 else { return nil }
                let s = String(ck.suffix(10))
                guard s.first?.isNumber == true else { return nil }
                return (ck, s)
            }
            for item in sansChecklist {
                guard let assKey = allAssignments.first(where: { a in
                    guard let k = a.reservationKey, k.count >= 10 else { return false }
                    return String(k.suffix(10)) == item.dateStr && a.propertyId == item.propertyId
                })?.reservationKey else {
                    print("[DEBUG-CROSS]  \(item.dateStr) \(item.propertyName ?? "?") — reservationKey introuvable dans allAssignments")
                    continue
                }
                let assDateSuffix = assKey.count >= 10 ? String(assKey.suffix(10)) : assKey
                let mêmeDate = clSuffixes.filter { $0.suffix == assDateSuffix }
                let autresDates = clSuffixes.filter { $0.suffix != assDateSuffix }.prefix(3)
                print("[DEBUG-CROSS]  assKey=\(assKey)  assDate=\(assDateSuffix)  clMêmeDate=\(mêmeDate.count) \(mêmeDate.prefix(2).map(\.key))")
                if mêmeDate.isEmpty {
                    print("[DEBUG-CROSS]    → aucune checklist avec ce suffix. Dates disponibles: \(autresDates.map(\.suffix))")
                }
            }
        }
        #endif

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
