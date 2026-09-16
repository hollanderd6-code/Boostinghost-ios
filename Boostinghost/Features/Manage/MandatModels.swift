import Foundation

// MARK: - Draft (état complet du formulaire 5 étapes)

struct MandatDraft {

    // Conciergerie — pré-remplie depuis GET /api/user/profile, bloc replié
    var companyName: String     = ""
    var companyEmail: String    = ""
    var companyPhone: String    = ""
    var companySiret: String    = ""
    var companyRep: String      = ""
    var companyAddress: String  = ""
    var companyLogoUrl: String  = ""
    var companyLegal: String    = ""
    var companyFreeTitle: String = ""
    var companyFreeValue: String = ""

    // Propriétaire — pré-rempli depuis le client sélectionné
    var ownerFirstName: String  = ""
    var ownerLastName: String   = ""
    var ownerEmail: String      = ""
    var ownerAddress: String    = ""
    var ownerPhone: String      = ""
    var ownerDOB: String        = ""
    var ownerSiren: String      = ""

    // Bien
    var propAddress: String     = ""
    var propType: String        = ""          // "" = aucun sélectionné
    var propCapacity: String    = ""
    var minStay: String         = ""
    var maxStay: String         = ""
    var animals: String         = "non"       // défaut spec
    var smoking: String         = "non"       // défaut spec
    var parties: String         = "non"       // défaut spec
    var checkinTime: String     = "15:00"     // défaut spec
    var checkoutTime: String    = "11:00"     // défaut spec

    // Missions (étape 2 — TODO)
    var missions: [String]         = []
    var urgenceLimit: String       = ""
    var extrasFacturables: [String] = []

    // Honoraires (étape 3 — TODO)
    // ⚠️ commissionRate, forfaitMensuel, forfaitResa, mixteRate, mixteForfait sont des String
    // conformément à la section "Format du payload" de la spec.
    var remuType: String        = ""
    var commissionRate: String  = ""
    var commissionBase: String  = "ht"         // défaut spec
    var forfaitMensuel: String  = ""
    var forfaitResa: String     = ""
    var mixteRate: String       = ""
    var mixteForfait: String    = ""
    var tva: String             = "franchise"  // défaut spec
    var tarifPreavis: String    = "60"         // défaut spec — String
    var reversement: String     = "mensuel"    // défaut spec

    // Conditions (étape 4 — TODO)
    // ⚠️ preavis, dureeMois, confidentialite sont des String
    var dureeType: String          = "indeterminee" // défaut spec
    var dateDebut: String          = ""
    var dureeMois: String          = ""             // String
    var renouvellement: String     = "tacite"       // défaut spec
    var preavis: String            = "30"           // défaut spec — String
    var exclusivite: String        = "non"          // défaut spec
    var respPlafond: String        = "oui"          // défaut spec
    var juridiction: String        = "lieu_bien"    // défaut spec
    var confidentialite: String    = "5"            // défaut spec — String
    var clausesPersonnalisees: [String] = []

    // Signature (étape 5)
    // ⚠️ signatureData DOIT commencer par "data:image/png;base64," — le serveur vérifie ce préfixe.
    var signatureData: String   = ""
    var signatureDate: String   = ""  // ISO 8601

    // MARK: Validation

    var isStep1Valid: Bool {
        !ownerEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !ownerFirstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !ownerLastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isSignatureReady: Bool {
        signatureData.hasPrefix("data:image/png;base64,")
    }
}

// MARK: - GET /api/mandat/last

// Réponse : { source: {...} | null, sourceId: "...", contractType: "mandat" }
// source == null = aucun mandat précédent → appliquer les défauts. C'est un état normal.
struct MandatLastResponse: Decodable {
    let source: MandatSource?
    let sourceId: String?
    let contractType: String?

    init(from decoder: Decoder) throws {
        let c        = try decoder.container(keyedBy: CodingKeys.self)
        source       = try? c.decodeIfPresent(MandatSource.self, forKey: .source)
        sourceId     = try? c.decodeIfPresent(String.self, forKey: .sourceId)
        contractType = try? c.decodeIfPresent(String.self, forKey: .contractType)
    }

    private enum CodingKeys: CodingKey { case source, sourceId, contractType }
}

// Contenu de contract_data du dernier mandat — tous les champs sont optionnels.
// Les champs numériques arrivent en String car le web les envoie en String.
struct MandatSource: Decodable {
    let remuType: String?
    let commissionRate: String?
    let commissionBase: String?
    let forfaitMensuel: String?
    let forfaitResa: String?
    let mixteRate: String?
    let mixteForfait: String?
    let tva: String?
    let tarifPreavis: String?
    let reversement: String?
    let dureeType: String?
    let dateDebut: String?
    let dureeMois: String?
    let renouvellement: String?
    let preavis: String?
    let exclusivite: String?
    let respPlafond: String?
    let juridiction: String?
    let confidentialite: String?

    init(from decoder: Decoder) throws {
        let c            = try decoder.container(keyedBy: CodingKeys.self)
        remuType         = try? c.decodeIfPresent(String.self, forKey: .remuType)
        commissionRate   = try? c.decodeIfPresent(String.self, forKey: .commissionRate)
        commissionBase   = try? c.decodeIfPresent(String.self, forKey: .commissionBase)
        forfaitMensuel   = try? c.decodeIfPresent(String.self, forKey: .forfaitMensuel)
        forfaitResa      = try? c.decodeIfPresent(String.self, forKey: .forfaitResa)
        mixteRate        = try? c.decodeIfPresent(String.self, forKey: .mixteRate)
        mixteForfait     = try? c.decodeIfPresent(String.self, forKey: .mixteForfait)
        tva              = try? c.decodeIfPresent(String.self, forKey: .tva)
        tarifPreavis     = try? c.decodeIfPresent(String.self, forKey: .tarifPreavis)
        reversement      = try? c.decodeIfPresent(String.self, forKey: .reversement)
        dureeType        = try? c.decodeIfPresent(String.self, forKey: .dureeType)
        dateDebut        = try? c.decodeIfPresent(String.self, forKey: .dateDebut)
        dureeMois        = try? c.decodeIfPresent(String.self, forKey: .dureeMois)
        renouvellement   = try? c.decodeIfPresent(String.self, forKey: .renouvellement)
        preavis          = try? c.decodeIfPresent(String.self, forKey: .preavis)
        exclusivite      = try? c.decodeIfPresent(String.self, forKey: .exclusivite)
        respPlafond      = try? c.decodeIfPresent(String.self, forKey: .respPlafond)
        juridiction      = try? c.decodeIfPresent(String.self, forKey: .juridiction)
        confidentialite  = try? c.decodeIfPresent(String.self, forKey: .confidentialite)
    }

    private enum CodingKeys: CodingKey {
        case remuType, commissionRate, commissionBase
        case forfaitMensuel, forfaitResa, mixteRate, mixteForfait
        case tva, tarifPreavis, reversement
        case dureeType, dateDebut, dureeMois, renouvellement
        case preavis, exclusivite, respPlafond, juridiction, confidentialite
    }
}

// MARK: - POST /api/mandat/send — payload

// ⚠️ TOUS les champs numériques sont des String.
// JSONEncoder() sans stratégie → camelCase, cohérent avec ce que le web envoie.
// Le serveur stocke le JSONB tel quel ; envoyer un Int ou Double produirait une
// forme différente de celle du web pour le même mandat.
struct MandatSendBody: Encodable {
    let clientId: String
    let contractType: String

    // Conciergerie
    let companyName: String
    let companyEmail: String
    let companyPhone: String
    let companySiret: String
    let companyRep: String
    let companyAddress: String
    let companyLogoUrl: String
    let companyLegal: String
    let companyFreeTitle: String
    let companyFreeValue: String

    // Propriétaire
    let ownerFirstName: String
    let ownerLastName: String
    let ownerEmail: String
    let ownerAddress: String
    let ownerPhone: String
    let ownerDOB: String
    let ownerSiren: String

    // Bien
    let propAddress: String
    let propType: String
    let propCapacity: String
    let minStay: String
    let maxStay: String
    let animals: String
    let smoking: String
    let parties: String
    let checkinTime: String
    let checkoutTime: String

    // Missions
    let missions: [String]
    let urgenceLimit: String
    let extrasFacturables: [String]

    // Honoraires — tous String
    let remuType: String
    let commissionRate: String
    let commissionBase: String
    let forfaitMensuel: String
    let forfaitResa: String
    let mixteRate: String
    let mixteForfait: String
    let tva: String
    let tarifPreavis: String
    let reversement: String

    // Conditions — numériques en String
    let dureeType: String
    let dateDebut: String
    let dureeMois: String
    let renouvellement: String
    let preavis: String
    let exclusivite: String
    let respPlafond: String
    let juridiction: String
    let confidentialite: String
    let clausesPersonnalisees: [String]

    // Signature
    let signatureData: String
    let signatureDate: String

    init(draft d: MandatDraft, clientId: String) {
        self.clientId          = clientId
        self.contractType      = "mandat"
        self.companyName       = d.companyName
        self.companyEmail      = d.companyEmail
        self.companyPhone      = d.companyPhone
        self.companySiret      = d.companySiret
        self.companyRep        = d.companyRep
        self.companyAddress    = d.companyAddress
        self.companyLogoUrl    = d.companyLogoUrl
        self.companyLegal      = d.companyLegal
        self.companyFreeTitle  = d.companyFreeTitle
        self.companyFreeValue  = d.companyFreeValue
        self.ownerFirstName    = d.ownerFirstName
        self.ownerLastName     = d.ownerLastName
        self.ownerEmail        = d.ownerEmail
        self.ownerAddress      = d.ownerAddress
        self.ownerPhone        = d.ownerPhone
        self.ownerDOB          = d.ownerDOB
        self.ownerSiren        = d.ownerSiren
        self.propAddress       = d.propAddress
        self.propType          = d.propType
        self.propCapacity      = d.propCapacity
        self.minStay           = d.minStay
        self.maxStay           = d.maxStay
        self.animals           = d.animals
        self.smoking           = d.smoking
        self.parties           = d.parties
        self.checkinTime       = d.checkinTime
        self.checkoutTime      = d.checkoutTime
        self.missions          = d.missions
        self.urgenceLimit      = d.urgenceLimit
        self.extrasFacturables = d.extrasFacturables
        self.remuType          = d.remuType
        self.commissionRate    = d.commissionRate
        self.commissionBase    = d.commissionBase
        self.forfaitMensuel    = d.forfaitMensuel
        self.forfaitResa       = d.forfaitResa
        self.mixteRate         = d.mixteRate
        self.mixteForfait      = d.mixteForfait
        self.tva               = d.tva
        self.tarifPreavis      = d.tarifPreavis
        self.reversement       = d.reversement
        self.dureeType         = d.dureeType
        self.dateDebut         = d.dateDebut
        self.dureeMois         = d.dureeMois
        self.renouvellement    = d.renouvellement
        self.preavis           = d.preavis
        self.exclusivite       = d.exclusivite
        self.respPlafond       = d.respPlafond
        self.juridiction       = d.juridiction
        self.confidentialite   = d.confidentialite
        self.clausesPersonnalisees = d.clausesPersonnalisees
        self.signatureData     = d.signatureData
        self.signatureDate     = d.signatureDate
    }
}

// MARK: - POST /api/mandat/send — réponse

struct MandatSendResponse: Decodable {
    let success: Bool
    let message: String?
    let contractId: String?

    init(from decoder: Decoder) throws {
        let c      = try decoder.container(keyedBy: CodingKeys.self)
        success    = (try? c.decodeIfPresent(Bool.self,   forKey: .success)) ?? false
        message    = try? c.decodeIfPresent(String.self,  forKey: .message)
        contractId = c.flexString(forKey: .contractId)
    }

    private enum CodingKeys: CodingKey { case success, message, contractId }
}
