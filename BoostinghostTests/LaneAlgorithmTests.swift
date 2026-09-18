import Foundation
import Testing
@testable import Boostinghost

// MARK: - Helper

private func makeRes(_ id: String, _ start: String, _ end: String,
                     prop: String = "p") -> Reservation {
    let json = """
    {"id":"\(id)","property_id":"\(prop)","start_date":"\(start)","end_date":"\(end)"}
    """.data(using: .utf8)!
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return try! d.decode(Reservation.self, from: json)
}

// MARK: - Tests

struct LaneAlgorithmTests {

    // T1 — Réservation unique → laneIndex=0, laneCount=1 (géométrie inchangée)
    @Test("T1 — réservation unique")
    func t1_single() throws {
        let lanes = ReservationLaneLayout.compute([makeRes("A","2026-09-01","2026-09-05")])
        let lane = try #require(lanes["A"])
        #expect(lane.laneIndex == 0)
        #expect(lane.laneCount == 1)
    }

    // T2 — Deux réservations disjointes → chacune laneIndex=0, laneCount=1
    @Test("T2 — deux réservations non chevauchantes")
    func t2_noOverlap() {
        let res = [makeRes("A","2026-09-01","2026-09-05"), makeRes("B","2026-09-10","2026-09-15")]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 1)
        #expect(lanes["B"]?.laneIndex == 0); #expect(lanes["B"]?.laneCount == 1)
    }

    // T3 — Réservations adjacentes (fin A == début B) — NON chevauchantes → même lane
    @Test("T3 — adjacentes : fin A == début B (non-régression)")
    func t3_adjacent() {
        let res = [makeRes("A","2026-09-01","2026-09-05"), makeRes("B","2026-09-05","2026-09-10")]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 1)
        #expect(lanes["B"]?.laneIndex == 0); #expect(lanes["B"]?.laneCount == 1)
    }

    // T4 — CDG5 : A(18→23) + B(18→20), même date d'arrivée
    @Test("T4 — CDG5 : deux réservations même date d'arrivée")
    func t4_cdg5() {
        let res = [makeRes("A","2026-09-18","2026-09-23"), makeRes("B","2026-09-18","2026-09-20")]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 2)
        #expect(lanes["B"]?.laneIndex == 1); #expect(lanes["B"]?.laneCount == 2)
    }

    // T5 — Containment : A contient B et C, B et C ne se chevauchent pas
    //      Résultat attendu : A=lane0, B=lane1, C=lane1, laneCount=2
    @Test("T5 — containment : A(01→30) contient B(05→10) et C(15→20)")
    func t5_containment() {
        let res = [
            makeRes("A","2026-09-01","2026-09-30"),
            makeRes("B","2026-09-05","2026-09-10"),
            makeRes("C","2026-09-15","2026-09-20"),
        ]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 2)
        #expect(lanes["B"]?.laneIndex == 1); #expect(lanes["B"]?.laneCount == 2)
        #expect(lanes["C"]?.laneIndex == 1); #expect(lanes["C"]?.laneCount == 2)
    }

    // T6 — Triple chevauchement mutuel → trois lanes distinctes
    @Test("T6 — triple chevauchement : A(01→10), B(05→15), C(08→20)")
    func t6_tripleOverlap() {
        let res = [
            makeRes("A","2026-09-01","2026-09-10"),
            makeRes("B","2026-09-05","2026-09-15"),
            makeRes("C","2026-09-08","2026-09-20"),
        ]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 3)
        #expect(lanes["B"]?.laneIndex == 1); #expect(lanes["B"]?.laneCount == 3)
        #expect(lanes["C"]?.laneIndex == 2); #expect(lanes["C"]?.laneCount == 3)
    }

    // T7 — Tableau vide → dictionnaire vide
    @Test("T7 — tableau vide")
    func t7_empty() {
        #expect(ReservationLaneLayout.compute([]).isEmpty)
    }

    // T8 — Indépendance de l'ordre d'entrée : même résultat que T4 avec B en premier
    @Test("T8 — ordre d'entrée inversé, résultat identique à T4")
    func t8_inputOrderIndependent() {
        let res = [makeRes("B","2026-09-18","2026-09-20"), makeRes("A","2026-09-18","2026-09-23")]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 2)
        #expect(lanes["B"]?.laneIndex == 1); #expect(lanes["B"]?.laneCount == 2)
    }

    // T9 — Chaîne de chevauchement : A∩B, B∩C mais A∩C=false
    //      Résultat attendu : A=lane0, B=lane1, C=lane0, laneCount=2
    @Test("T9 — chaîne : A(01→05), B(04→08), C(07→11)")
    func t9_chain() {
        let res = [
            makeRes("A","2026-09-01","2026-09-05"),
            makeRes("B","2026-09-04","2026-09-08"),
            makeRes("C","2026-09-07","2026-09-11"),
        ]
        let lanes = ReservationLaneLayout.compute(res)
        #expect(lanes["A"]?.laneIndex == 0); #expect(lanes["A"]?.laneCount == 2)
        #expect(lanes["B"]?.laneIndex == 1); #expect(lanes["B"]?.laneCount == 2)
        #expect(lanes["C"]?.laneIndex == 0); #expect(lanes["C"]?.laneCount == 2)
    }
}
