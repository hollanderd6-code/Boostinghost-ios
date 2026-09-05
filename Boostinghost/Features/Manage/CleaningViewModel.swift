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
        let items = historyCleanerFilter.map { f in historyItems.filter { $0.cleanerName == f } } ?? historyItems
        var grouped: [String: [CleaningHistoryItem]] = [:]
        for item in items { grouped[item.dateStr, default: []].append(item) }
        return grouped.keys.sorted(by: >).map { CleaningHistoryGroup(dateStr: $0, items: grouped[$0]!) }
    }

    // MARK: - Chargement

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

        // Index checklists par reservation_key (pour l'Historique)
        let checklistByKey: [String: CleaningChecklist] = rawChecklists.reduce(into: [:]) { d, c in
            if let key = c.reservationKey { d[key] = c }
        }

        let tightThreshold: TimeInterval = 6 * 3600

        // Filtre par date : suffix(10) == dayStr, format réel uniquement (commence par un chiffre)
        func dayAssignments(_ dayStr: String) -> [CleaningAssignment] {
            allAssignments.filter { a in
                guard let key = a.reservationKey, key.count >= 10 else { return false }
                let suffix = String(key.suffix(10))
                guard suffix.first?.isNumber == true else { return false }
                return suffix == dayStr
            }
        }

        // Résolution du nom et du créneau pour un jour donné
        func resolve(_ a: CleaningAssignment, dayStr: String) -> CleaningAssignment {
            var a = a
            guard let pid = a.propertyId else { return a }
            a.resolvedPropertyName = nameByProp[pid]
            a.windowStart = depTimeByProp[pid]
            if resaByProp[pid]?.contains(where: { $0.startDate == dayStr }) == true {
                a.windowEnd = arrTimeByProp[pid]
            }
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
        }
        #endif

        let (todayTight, todayWide) = classify(resolvedToday)
        tightAssignments = todayTight
        wideAssignments  = todayWide

        checklistsToValidate = rawChecklists
            .filter { $0.status == "completed" }
            .map { c in
                var c = c
                c.resolvedPropertyName = c.propertyId.flatMap { nameByProp[$0] }
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

        historyItems = allAssignments.compactMap { a -> CleaningHistoryItem? in
            guard let key = a.reservationKey, key.count >= 10 else { return nil }
            let suffix = String(key.suffix(10))
            guard suffix.first?.isNumber == true, historySet.contains(suffix) else { return nil }
            let propName = a.propertyId.flatMap { nameByProp[$0] } ?? a.propertyName
            return CleaningHistoryItem(
                dateStr: suffix,
                propertyName: propName,
                cleanerName: a.cleanerName,
                checklistStatus: checklistByKey[key]?.status
            )
        }.sorted { $0.dateStr > $1.dateStr }

        historyCleanerNames = Array(
            Set(historyItems.compactMap { $0.cleanerName }.filter { !$0.isEmpty })
        ).sorted()

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
