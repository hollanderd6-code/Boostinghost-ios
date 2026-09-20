import Foundation

/// Compact vertical placement for one reservation bar in a calendar row.
struct BarLane {
    let laneIndex: Int  // 0-based slot within the overlap group
    let laneCount: Int  // total slots in the group (1 = solo, geometry unchanged)
}

/// Greedy interval-scheduling lane assignment for a single calendar row.
///
/// - Sort order: startDate ASC · endDate DESC (longer first) · id ASC (deterministic)
/// - Overlap convention: [start, end) — adjacent (a.end == b.start) is NOT overlapping
/// - laneCount is per connected component, not per row maximum
enum ReservationLaneLayout {

    static func compute(_ reservations: [Reservation]) -> [String: BarLane] {
        let valid = reservations.filter { $0.startDayDate != nil && $0.endDayDate != nil }
        guard !valid.isEmpty else { return [:] }

        // 1 — Deterministic sort
        let sorted = valid.sorted { a, b in
            let sa = a.startDayDate!, sb = b.startDayDate!
            if sa != sb { return sa < sb }
            let ea = a.endDayDate!, eb = b.endDayDate!
            if ea != eb { return ea > eb }
            return a.id < b.id
        }
        let n = sorted.count

        // 2 — Greedy lane assignment: find first free lane, or open a new one
        var laneEnds = [Date]()
        var laneIdx  = [Int](repeating: 0, count: n)

        for (i, r) in sorted.enumerated() {
            let start = r.startDayDate!, end = r.endDayDate!
            var placed = false
            for j in 0..<laneEnds.count where laneEnds[j] <= start {
                laneEnds[j] = end
                laneIdx[i]  = j
                placed = true
                break
            }
            if !placed {
                laneIdx[i] = laneEnds.count
                laneEnds.append(end)
            }
        }

        // 3 — Union-Find: group transitively overlapping reservations
        //     No path compression — n ≤ ~100 per row per month.
        var parent = Array(0..<n)

        func root(_ i: Int) -> Int {
            var cur = i
            while parent[cur] != cur { cur = parent[cur] }
            return cur
        }

        for i in 0..<n {
            let ea = sorted[i].endDayDate!
            for j in (i+1)..<n {
                let sb = sorted[j].startDayDate!
                if sb >= ea { break }   // sorted by start — no later j can overlap i
                // sa < eb guaranteed: sa ≤ sb < ea and eb > sb ≥ sa
                let ri = root(i), rj = root(j)
                if ri != rj { parent[ri] = rj }
            }
        }

        // 4 — Per-component max lane index → laneCount
        var compMax = [Int: Int]()
        for i in 0..<n {
            let r = root(i)
            compMax[r] = max(compMax[r, default: 0], laneIdx[i])
        }

        // 5 — Build result keyed by reservation id
        var result = [String: BarLane](minimumCapacity: n)
        for i in 0..<n {
            let lc = (compMax[root(i)] ?? 0) + 1
            result[sorted[i].id] = BarLane(laneIndex: laneIdx[i], laneCount: lc)
        }
        return result
    }
}
