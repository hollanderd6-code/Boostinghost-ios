import Foundation

// MARK: - GET /api/hosterzz/status

struct HosterzzStatusResponse: Decodable {
    let linked: Bool
    let hzName: String?
    let since: String?
}

// MARK: - GET /api/hosterzz/mission?reservation_id=

struct HosterzzMissionCheckResponse: Decodable {
    let mission: Mission?

    struct Mission: Decodable {
        let statut: String?
        let url: String?
    }
}

// MARK: - POST /api/hosterzz/link body + response
//
// 200: { ok: true, hz_name: String }
// 400: { error: String } — code invalide ou vide
// 403: { error: "Compte principal requis." } — sous-compte

struct HosterzzLinkBody: Encodable {
    let code: String
}

struct HosterzzLinkResponse: Decodable {
    let ok: Bool?
    let hzName: String?
}

// MARK: - POST /api/hosterzz/missions body

struct HosterzzMissionBody: Encodable {
    let reservationId: String
    let heure: String?
    let taskType: String
    let description: String?

    // Encoder (JSONEncoder, no convertToSnakeCase) — raw snake_case values are correct here.
    private enum CodingKeys: String, CodingKey {
        case reservationId = "reservation_id"
        case heure
        case taskType     = "task_type"
        case description
    }
}

// MARK: - POST /api/hosterzz/missions response
//
// 200: { ok: true, mission_id, already: Bool, statut, url }
// 202: { pending: true, code: "PENDING", error }
// Both fall into the 200…299 range so validate() passes; decoded as this single type.

struct HosterzzMissionResponse: Decodable {
    let ok: Bool?
    let pending: Bool?
    let missionId: String?   // flexString — backend may return Int or String
    let already: Bool?
    let statut: String?
    let url: String?
    let code: String?
    let error: String?

    // No raw values: convertFromSnakeCase converts mission_id → missionId before
    // comparing to CodingKey.stringValue, so the camelCase case name matches correctly.
    private enum CodingKeys: CodingKey {
        case ok, pending, missionId, already, statut, url, code, error
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        ok       = try? c.decodeIfPresent(Bool.self,   forKey: .ok)
        pending  = try? c.decodeIfPresent(Bool.self,   forKey: .pending)
        already  = try? c.decodeIfPresent(Bool.self,   forKey: .already)
        statut   = try? c.decodeIfPresent(String.self, forKey: .statut)
        url      = try? c.decodeIfPresent(String.self, forKey: .url)
        code     = try? c.decodeIfPresent(String.self, forKey: .code)
        error    = try? c.decodeIfPresent(String.self, forKey: .error)
        missionId = c.flexString(forKey: .missionId)
    }
}
