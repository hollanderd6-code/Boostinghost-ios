import Foundation

// MARK: - JSONB complet (mandat + contrat de location, tous champs optionnels)

struct ContractDetailData: Decodable {
    let contractType: String?

    // Conciergerie (mandat)
    let companyName: String?
    let companyEmail: String?
    let companyPhone: String?
    let companySiret: String?
    let companyRep: String?
    let companyAddress: String?
    let companyLogoUrl: String?
    let companyLegal: String?
    let companyFreeTitle: String?
    let companyFreeValue: String?

    // Propriétaire / bailleur — communs aux deux types (clés identiques en JSON)
    let ownerFirstName: String?
    let ownerLastName: String?
    let ownerEmail: String?
    let ownerAddress: String?
    let ownerPhone: String?
    // mandat uniquement
    let ownerDOB: String?
    let ownerSiren: String?

    // Bien — mandat (clés propType, propAddress, propCapacity…)
    let propAddress: String?
    let propType: String?
    let propCapacity: String?
    let minStay: String?
    let maxStay: String?
    let animals: String?
    let smoking: String?
    let parties: String?
    let checkinTime: String?
    let checkoutTime: String?

    // Missions (mandat)
    let missions: [String]?
    let urgenceLimit: String?
    let extrasFacturables: [String]?

    // Honoraires — tous String (mandat)
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

    // Conditions durée (mandat)
    let dureeType: String?
    let dateDebut: String?
    let dureeMois: String?
    let renouvellement: String?
    let preavis: String?
    let exclusivite: String?
    let respPlafond: String?
    let juridiction: String?
    let confidentialite: String?
    let clausesPersonnalisees: [String]?

    // Signature (commun)
    let signatureDate: String?

    // ── Contrat de location ──────────────────────────────────────────────────

    // Voyageur
    let guestFirstName: String?
    let guestLastName: String?
    let guestEmail: String?
    let guestPhone: String?
    let guestAddress: String?
    let guestDOB: String?
    let guestCount: String?
    let guestNationality: String?
    let guestIDNumber: String?

    // Bien (clés différentes du mandat : propertyName/propertyAddress/propertyType vs propAddress/propType)
    let propertyName: String?
    let propertyAddress: String?
    // ⚠️ propertyType and propType are different JSON keys for location vs mandat
    let propertyType: String?

    // Dates de séjour
    let checkin: String?
    let checkout: String?

    // Tarifs (tous String — cohérent avec le formulaire web qui envoie .value.trim())
    let totalPrice: String?
    let acompte: String?
    let acompteDate: String?
    let deposit: String?
    let cleaningFee: String?
    let depositReturnDays: String?
    let paymentMethod: String?
    let priceNotes: String?

    // Annulation
    let cancelPct1: String?
    let cancelDays1: String?
    let cancelPct2: String?
    let cancelDays2: String?

    // Clauses / options (Bool en JSON — décodage séparé)
    let inclEDL: Bool?
    let inclAssurance: Bool?
    let inclAnnulation: Bool?
    let inclObligations: Bool?
    let obligationsExtra: String?
    let regles: [String]?

    // MARK: init tolérant

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        contractType           = try? c.decodeIfPresent(String.self,   forKey: .contractType)

        companyName            = try? c.decodeIfPresent(String.self,   forKey: .companyName)
        companyEmail           = try? c.decodeIfPresent(String.self,   forKey: .companyEmail)
        companyPhone           = try? c.decodeIfPresent(String.self,   forKey: .companyPhone)
        companySiret           = try? c.decodeIfPresent(String.self,   forKey: .companySiret)
        companyRep             = try? c.decodeIfPresent(String.self,   forKey: .companyRep)
        companyAddress         = try? c.decodeIfPresent(String.self,   forKey: .companyAddress)
        companyLogoUrl         = try? c.decodeIfPresent(String.self,   forKey: .companyLogoUrl)
        companyLegal           = try? c.decodeIfPresent(String.self,   forKey: .companyLegal)
        companyFreeTitle       = try? c.decodeIfPresent(String.self,   forKey: .companyFreeTitle)
        companyFreeValue       = try? c.decodeIfPresent(String.self,   forKey: .companyFreeValue)

        ownerFirstName         = try? c.decodeIfPresent(String.self,   forKey: .ownerFirstName)
        ownerLastName          = try? c.decodeIfPresent(String.self,   forKey: .ownerLastName)
        ownerEmail             = try? c.decodeIfPresent(String.self,   forKey: .ownerEmail)
        ownerAddress           = try? c.decodeIfPresent(String.self,   forKey: .ownerAddress)
        ownerPhone             = try? c.decodeIfPresent(String.self,   forKey: .ownerPhone)
        ownerDOB               = try? c.decodeIfPresent(String.self,   forKey: .ownerDOB)
        ownerSiren             = try? c.decodeIfPresent(String.self,   forKey: .ownerSiren)

        propAddress            = try? c.decodeIfPresent(String.self,   forKey: .propAddress)
        propType               = try? c.decodeIfPresent(String.self,   forKey: .propType)
        propCapacity           = try? c.decodeIfPresent(String.self,   forKey: .propCapacity)
        minStay                = try? c.decodeIfPresent(String.self,   forKey: .minStay)
        maxStay                = try? c.decodeIfPresent(String.self,   forKey: .maxStay)
        animals                = try? c.decodeIfPresent(String.self,   forKey: .animals)
        smoking                = try? c.decodeIfPresent(String.self,   forKey: .smoking)
        parties                = try? c.decodeIfPresent(String.self,   forKey: .parties)
        checkinTime            = try? c.decodeIfPresent(String.self,   forKey: .checkinTime)
        checkoutTime           = try? c.decodeIfPresent(String.self,   forKey: .checkoutTime)

        missions               = try? c.decodeIfPresent([String].self, forKey: .missions)
        urgenceLimit           = try? c.decodeIfPresent(String.self,   forKey: .urgenceLimit)
        extrasFacturables      = try? c.decodeIfPresent([String].self, forKey: .extrasFacturables)

        remuType               = try? c.decodeIfPresent(String.self,   forKey: .remuType)
        commissionRate         = try? c.decodeIfPresent(String.self,   forKey: .commissionRate)
        commissionBase         = try? c.decodeIfPresent(String.self,   forKey: .commissionBase)
        forfaitMensuel         = try? c.decodeIfPresent(String.self,   forKey: .forfaitMensuel)
        forfaitResa            = try? c.decodeIfPresent(String.self,   forKey: .forfaitResa)
        mixteRate              = try? c.decodeIfPresent(String.self,   forKey: .mixteRate)
        mixteForfait           = try? c.decodeIfPresent(String.self,   forKey: .mixteForfait)
        tva                    = try? c.decodeIfPresent(String.self,   forKey: .tva)
        tarifPreavis           = try? c.decodeIfPresent(String.self,   forKey: .tarifPreavis)
        reversement            = try? c.decodeIfPresent(String.self,   forKey: .reversement)

        dureeType              = try? c.decodeIfPresent(String.self,   forKey: .dureeType)
        dateDebut              = try? c.decodeIfPresent(String.self,   forKey: .dateDebut)
        dureeMois              = try? c.decodeIfPresent(String.self,   forKey: .dureeMois)
        renouvellement         = try? c.decodeIfPresent(String.self,   forKey: .renouvellement)
        preavis                = try? c.decodeIfPresent(String.self,   forKey: .preavis)
        exclusivite            = try? c.decodeIfPresent(String.self,   forKey: .exclusivite)
        respPlafond            = try? c.decodeIfPresent(String.self,   forKey: .respPlafond)
        juridiction            = try? c.decodeIfPresent(String.self,   forKey: .juridiction)
        confidentialite        = try? c.decodeIfPresent(String.self,   forKey: .confidentialite)
        clausesPersonnalisees  = try? c.decodeIfPresent([String].self, forKey: .clausesPersonnalisees)

        signatureDate          = try? c.decodeIfPresent(String.self,   forKey: .signatureDate)

        guestFirstName         = try? c.decodeIfPresent(String.self,   forKey: .guestFirstName)
        guestLastName          = try? c.decodeIfPresent(String.self,   forKey: .guestLastName)
        guestEmail             = try? c.decodeIfPresent(String.self,   forKey: .guestEmail)
        guestPhone             = try? c.decodeIfPresent(String.self,   forKey: .guestPhone)
        guestAddress           = try? c.decodeIfPresent(String.self,   forKey: .guestAddress)
        guestDOB               = try? c.decodeIfPresent(String.self,   forKey: .guestDOB)
        guestCount             = try? c.decodeIfPresent(String.self,   forKey: .guestCount)
        guestNationality       = try? c.decodeIfPresent(String.self,   forKey: .guestNationality)
        guestIDNumber          = try? c.decodeIfPresent(String.self,   forKey: .guestIDNumber)

        propertyName           = try? c.decodeIfPresent(String.self,   forKey: .propertyName)
        propertyAddress        = try? c.decodeIfPresent(String.self,   forKey: .propertyAddress)
        propertyType           = try? c.decodeIfPresent(String.self,   forKey: .propertyType)

        checkin                = try? c.decodeIfPresent(String.self,   forKey: .checkin)
        checkout               = try? c.decodeIfPresent(String.self,   forKey: .checkout)

        totalPrice             = try? c.decodeIfPresent(String.self,   forKey: .totalPrice)
        acompte                = try? c.decodeIfPresent(String.self,   forKey: .acompte)
        acompteDate            = try? c.decodeIfPresent(String.self,   forKey: .acompteDate)
        deposit                = try? c.decodeIfPresent(String.self,   forKey: .deposit)
        cleaningFee            = try? c.decodeIfPresent(String.self,   forKey: .cleaningFee)
        depositReturnDays      = try? c.decodeIfPresent(String.self,   forKey: .depositReturnDays)
        paymentMethod          = try? c.decodeIfPresent(String.self,   forKey: .paymentMethod)
        priceNotes             = try? c.decodeIfPresent(String.self,   forKey: .priceNotes)

        cancelPct1             = try? c.decodeIfPresent(String.self,   forKey: .cancelPct1)
        cancelDays1            = try? c.decodeIfPresent(String.self,   forKey: .cancelDays1)
        cancelPct2             = try? c.decodeIfPresent(String.self,   forKey: .cancelPct2)
        cancelDays2            = try? c.decodeIfPresent(String.self,   forKey: .cancelDays2)

        inclEDL                = try? c.decodeIfPresent(Bool.self,     forKey: .inclEDL)
        inclAssurance          = try? c.decodeIfPresent(Bool.self,     forKey: .inclAssurance)
        inclAnnulation         = try? c.decodeIfPresent(Bool.self,     forKey: .inclAnnulation)
        inclObligations        = try? c.decodeIfPresent(Bool.self,     forKey: .inclObligations)
        obligationsExtra       = try? c.decodeIfPresent(String.self,   forKey: .obligationsExtra)
        regles                 = try? c.decodeIfPresent([String].self, forKey: .regles)
    }

    private enum CodingKeys: CodingKey {
        case contractType
        case companyName, companyEmail, companyPhone, companySiret, companyRep
        case companyAddress, companyLogoUrl, companyLegal, companyFreeTitle, companyFreeValue
        case ownerFirstName, ownerLastName, ownerEmail, ownerAddress, ownerPhone, ownerDOB, ownerSiren
        case propAddress, propType, propCapacity, minStay, maxStay
        case animals, smoking, parties, checkinTime, checkoutTime
        case missions, urgenceLimit, extrasFacturables
        case remuType, commissionRate, commissionBase, forfaitMensuel, forfaitResa
        case mixteRate, mixteForfait, tva, tarifPreavis, reversement
        case dureeType, dateDebut, dureeMois, renouvellement, preavis
        case exclusivite, respPlafond, juridiction, confidentialite, clausesPersonnalisees
        case signatureDate
        // contrat de location
        case guestFirstName, guestLastName, guestEmail, guestPhone, guestAddress
        case guestDOB, guestCount, guestNationality, guestIDNumber
        case propertyName, propertyAddress, propertyType
        case checkin, checkout
        case totalPrice, acompte, acompteDate, deposit, cleaningFee, depositReturnDays, paymentMethod, priceNotes
        case cancelPct1, cancelDays1, cancelPct2, cancelDays2
        case inclEDL, inclAssurance, inclAnnulation, inclObligations, obligationsExtra, regles
    }
}

// MARK: - Modèle complet (GET /api/contrats/:id)

struct ContractDetail: Decodable, Identifiable {
    let id: String
    let status: String?
    let clientId: String?
    let signTokenExpiresAt: String?
    let guestSignedAt: String?
    // ⚠️ Pas de colonne sent_at — la date d'envoi est created_at.
    let createdAt: String?
    // ⚠️ Pas de guest_first/last_name au niveau racine pour le détail (contrairement à la liste).
    //    Ces infos sont dans contractData.guestFirstName/guestLastName.
    let contractData: ContractDetailData?

    var isMandat: Bool { contractData?.contractType == "mandat" }
    var typeLabel: String { isMandat ? "Mandat de gestion" : "Contrat de location" }

    // Signataire : propriétaire pour mandat, voyageur pour contrat de location
    var signerFirstName: String? {
        isMandat ? contractData?.ownerFirstName : contractData?.guestFirstName
    }
    var signerLastName: String? {
        isMandat ? contractData?.ownerLastName : contractData?.guestLastName
    }
    var signerDisplayName: String {
        let parts = [signerFirstName, signerLastName].compactMap { $0 }.filter { !$0.isEmpty }
        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? "—" : joined
    }

    // Sous-titre de la carte signataire
    var propertySubtitle: String {
        if isMandat {
            return contractData?.propAddress ?? ""
        } else {
            // Pour un contrat de location, afficher le nom du bien
            return contractData?.propertyName ?? contractData?.propertyAddress ?? ""
        }
    }

    private enum CodingKeys: CodingKey {
        case id, status, clientId, signTokenExpiresAt, guestSignedAt, createdAt, contractData
    }

    init(from decoder: Decoder) throws {
        let c              = try decoder.container(keyedBy: CodingKeys.self)
        id                 = c.flexString(forKey: .id) ?? ""
        status             = try? c.decodeIfPresent(String.self, forKey: .status)
        clientId           = c.flexString(forKey: .clientId)
        signTokenExpiresAt = try? c.decodeIfPresent(String.self, forKey: .signTokenExpiresAt)
        guestSignedAt      = try? c.decodeIfPresent(String.self, forKey: .guestSignedAt)
        createdAt          = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        contractData       = try? c.decodeIfPresent(ContractDetailData.self, forKey: .contractData)
    }
}

// MARK: - POST /api/contrats/:id/resend-sign — réponse

struct ContractResendResponse: Decodable {
    let success: Bool?
}
