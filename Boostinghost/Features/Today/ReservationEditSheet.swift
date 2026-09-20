import SwiftUI

// MARK: - Feuille de modification d'une réservation
//
// Trois modes, dictés par ce que le backend accepte réellement :
//
//  • manual  → PUT /api/reservations/manual/:uid
//              logement, dates, voyageur, nationalité, 5 montants, plateforme, notes
//  • bhGuest → POST /api/guest/modify-reservation
//              logement, dates, voyageurs, montant total, notes
//              (l'identité du voyageur vient du parcours de paiement : non modifiable)
//  • otaOnly → PATCH /api/reservations/:uid/note
//              notes seulement — le reste appartient à la plateforme
//
// ⚠️ Le changement de logement est vérifié côté serveur (409 si les dates sont
// déjà prises sur le logement cible) et déplace la conversation associée.

struct ReservationEditSheet: View {
    let reservation: Reservation
    let properties:  [PropertySummary]
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving     = false
    @State private var errorMessage: String? = nil

    // Champs communs
    @State private var propertyId: String
    @State private var notes: String
    @State private var startDate: Date
    @State private var endDate:   Date

    // Champs manuel / direct
    @State private var guestName: String
    @State private var adultsStr: String
    @State private var phone:     String
    @State private var email:     String
    @State private var country:   String
    @State private var platform:  String
    @State private var priceStr:    String
    @State private var roomsStr:    String
    @State private var cleaningStr: String
    @State private var taxesStr:    String
    @State private var otaCommStr:  String

    // Champs BHGuest supplémentaires
    @State private var guestsStr:       String
    @State private var amountTotalStr:  String

    // MARK: - Mode dérivé de la source

    enum Mode { case manual, bhGuest, otaOnly }

    var mode: Mode {
        if reservation.source?.lowercased() == "channex" { return .otaOnly }
        if reservation.isBhGuest { return .bhGuest }
        return .manual
    }

    // Le sélecteur n'a de sens qu'avec au moins deux logements, et jamais en OTA
    // (la réservation appartient au calendrier de la plateforme).
    private var canMoveProperty: Bool {
        mode != .otaOnly && properties.count > 1
    }

    private var propertyChanged: Bool {
        propertyId != reservation.propertyId
    }

    // MARK: - Init

    init(reservation: Reservation, properties: [PropertySummary] = [], onSaved: @escaping () -> Void) {
        self.reservation = reservation
        self.properties  = properties
        self.onSaved     = onSaved

        let s = Self.localDate(from: reservation.startDate) ?? Date()
        let e = Self.localDate(from: reservation.endDate)   ?? Date()

        _propertyId     = State(initialValue: reservation.propertyId)
        _notes          = State(initialValue: reservation.notes ?? "")
        _startDate      = State(initialValue: s)
        _endDate        = State(initialValue: e)
        _guestName      = State(initialValue: reservation.guestName ?? "")
        _adultsStr      = State(initialValue: reservation.occupancyAdults.map(String.init) ?? "")
        _phone          = State(initialValue: reservation.guestPhone ?? "")
        _email          = State(initialValue: reservation.guestEmail ?? "")
        _country        = State(initialValue: reservation.guestCountry ?? "")
        _platform       = State(initialValue: reservation.platform ?? "MANUEL")
        _priceStr       = State(initialValue: Self.fmtD(reservation.amountTotal))
        _roomsStr       = State(initialValue: Self.fmtD(reservation.amountRooms))
        _cleaningStr    = State(initialValue: Self.fmtD(reservation.amountCleaning))
        _taxesStr       = State(initialValue: Self.fmtD(reservation.amountTaxes))
        _otaCommStr     = State(initialValue: Self.fmtD(reservation.otaCommission))
        _guestsStr      = State(initialValue: reservation.occupancyAdults.map(String.init) ?? "")
        _amountTotalStr = State(initialValue: Self.fmtD(reservation.amountTotal))
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                sheetNavBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        switch mode {
                        case .otaOnly: otaContent
                        case .bhGuest: bhGuestContent
                        case .manual:  manualContent
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhTerracotta)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4)
                        }

                        PrimaryButton(title: isSaving ? "Enregistrement…" : "Enregistrer") {
                            Task { await save() }
                        }
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Barre

    private var sheetNavBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(reservation.guestName ?? "Réservation")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                    Text("Modifier")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Bloc Logement (manuel + BHGuest)

    @ViewBuilder
    private var logementSection: some View {
        if canMoveProperty {
            SectionLabel(text: "Logement")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: propertyChanged) {
                        HStack {
                            Text("Logement")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhAttenue)
                            Spacer(minLength: 8)
                            Picker("Logement", selection: $propertyId) {
                                ForEach(properties) { p in
                                    Text(p.displayName).tag(p.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .tint(Color.bhVert)
                        }
                    }
                    if propertyChanged {
                        CardRow(showSeparator: false) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .imageScale(.small)
                                    .foregroundStyle(Color.bhTerracotta)
                                    .padding(.top, 1)
                                Text("La réservation change de logement. La conversation du voyageur suit, et le ménage devra être réassigné.")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Contenu OTA (note uniquement)

    private var otaContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.fill")
                            .imageScale(.small)
                            .foregroundStyle(Color.bhAttenue)
                            .padding(.top, 1)
                        Text("Les dates, le logement et les montants viennent de la plateforme et ne peuvent pas être modifiés depuis l'app.")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            SectionLabel(text: "Notes")
            notesField
        }
    }

    // MARK: - Contenu BHGuest

    private var bhGuestContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            logementSection

            SectionLabel(text: "Séjour")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        DatePicker("Arrivée", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 15))
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                    }
                    CardRow(showSeparator: true) {
                        DatePicker("Départ", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 15))
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                    }
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Voyageurs")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            TextField("—", text: $guestsStr)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                        }
                    }
                    CardRow(showSeparator: false) {
                        amountRowContent("Montant total", $amountTotalStr)
                    }
                }
            }

            ListCard {
                CardRow(showSeparator: false) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .imageScale(.small)
                            .foregroundStyle(Color.bhAttenue)
                            .padding(.top, 1)
                        Text("Le nom et les coordonnées viennent du parcours de réservation BHGuest. Modifier le montant ne modifie pas le paiement déjà encaissé.")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SectionLabel(text: "Notes")
            notesField
        }
    }

    // MARK: - Contenu Manuel / Direct

    private var manualContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            logementSection

            SectionLabel(text: "Séjour")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        DatePicker("Arrivée", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 15))
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                    }
                    CardRow(showSeparator: false) {
                        DatePicker("Départ", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.system(size: 15))
                            .environment(\.locale, Locale(identifier: "fr_FR"))
                    }
                }
            }

            SectionLabel(text: "Voyageur")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        TextField("Nom", text: $guestName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                    }
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Adultes")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhAttenue)
                            Spacer()
                            TextField("—", text: $adultsStr)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                        }
                    }
                    CardRow(showSeparator: true) {
                        TextField("Téléphone", text: $phone)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                            .keyboardType(.phonePad)
                    }
                    CardRow(showSeparator: true) {
                        TextField("E-mail", text: $email)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                    // Nationalité : le serveur écrase guest_country à chaque
                    // UPDATE. Sans ce champ, la valeur saisie sur le web était
                    // effacée à la première modification depuis l'app.
                    CardRow(showSeparator: false) {
                        HStack {
                            Text("Nationalité")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhAttenue)
                            Spacer(minLength: 8)
                            TextField("FR", text: $country)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.bhEncre)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .frame(width: 70)
                        }
                    }
                }
            }

            SectionLabel(text: "Prix")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true)  { amountRowContent("Total",          $priceStr)    }
                    CardRow(showSeparator: true)  { amountRowContent("Nuits",          $roomsStr)    }
                    CardRow(showSeparator: true)  { amountRowContent("Ménage",         $cleaningStr) }
                    CardRow(showSeparator: true)  { amountRowContent("Taxes",          $taxesStr)    }
                    CardRow(showSeparator: false) { amountRowContent("Commission OTA", $otaCommStr)  }
                }
            }

            SectionLabel(text: "Notes")
            notesField

            SectionLabel(text: "Plateforme")
            ListCard {
                CardRow(showSeparator: false) {
                    TextField("MANUEL", text: $platform)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                        .textInputAutocapitalization(.characters)
                }
            }
        }
    }

    // MARK: - Composants réutilisables

    @ViewBuilder
    private func amountRowContent(_ label: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
            Spacer()
            TextField("—", text: text)
                .font(.system(size: 15))
                .foregroundStyle(Color.bhEncre)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 90)
            Text("€")
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
        }
    }

    private var notesField: some View {
        ListCard {
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Notes internes…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhAttenue.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Sauvegarde

    private func save() async {
        errorMessage = nil

        guard endDate > startDate else {
            errorMessage = "Le départ doit être après l'arrivée."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let uid = reservation.uid ?? reservation.id

        do {
            switch mode {
            case .otaOnly:
                try await APIClient.shared.patchVoid(
                    Endpoint.reservationNote(uid),
                    body: OTANoteBody(notes: notes.isEmpty ? nil : notes)
                )

            case .bhGuest:
                let body = BHGuestModifyBody(
                    uid:         uid,
                    propertyId:  propertyChanged ? propertyId : nil,
                    checkin:     Self.isoDate(startDate),
                    checkout:    Self.isoDate(endDate),
                    guests:      Int(guestsStr),
                    notes:       notes,
                    amountTotal: parseD(amountTotalStr)
                )
                try await APIClient.shared.postVoid(Endpoint.guestModifyReservation, body: body)

            case .manual:
                let body = ManualEditBody(
                    propertyId:      propertyId,
                    start:           Self.isoDate(startDate),
                    end:             Self.isoDate(endDate),
                    guestName:       guestName,
                    notes:           notes,
                    phone:           phone,
                    email:           email,
                    guestCountry:    country.trimmingCharacters(in: .whitespaces).uppercased(),
                    platform:        platform.isEmpty ? "MANUEL" : platform,
                    price:           parseD(priceStr),
                    occupancyAdults: Int(adultsStr),
                    amountRooms:     parseD(roomsStr),
                    amountCleaning:  parseD(cleaningStr),
                    amountTaxes:     parseD(taxesStr),
                    otaCommission:   parseD(otaCommStr)
                )
                try await APIClient.shared.putVoid(
                    Endpoint.reservationManual(uid),
                    body: body,
                    agencyAll: true
                )
            }

            onSaved()
            dismiss()

        } catch {
            errorMessage = saveErrorMessage(error)
        }
    }

    // Le 409 du serveur est le cas le plus fréquent quand on déplace une
    // réservation : le dire en clair plutôt que de renvoyer un code.
    private func saveErrorMessage(_ error: Error) -> String {
        if let api = error as? APIError, case .server(let status, let msg) = api {
            if status == 409 {
                let cible = properties.first { $0.id == propertyId }?.displayName
                return propertyChanged && cible != nil
                    ? "Ces dates sont déjà prises sur \(cible!)."
                    : "Ces dates sont déjà prises."
            }
            if let msg, !msg.isEmpty { return msg }
        }
        return (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    // MARK: - Helpers

    // Utilise le fuseau local pour que le DatePicker affiche la bonne date.
    private static let localFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func localDate(from iso: String) -> Date? {
        localFmt.date(from: String(iso.prefix(10)))
    }

    private static func isoDate(_ d: Date) -> String {
        localFmt.string(from: d)
    }

    private static func fmtD(_ v: Double?) -> String {
        guard let v else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.2f", v)
    }

    private func parseD(_ s: String) -> Double? {
        s.isEmpty ? nil : Double(s.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Corps des requêtes

private struct OTANoteBody: Encodable {
    let notes: String?
}

// propertyId n'est envoyé que s'il change : la route ne touche à la colonne
// (et ne déplace la conversation) que lorsque la clé est présente.
private struct BHGuestModifyBody: Encodable {
    let uid: String
    let propertyId: String?
    let checkin: String
    let checkout: String
    let guests: Int?
    let notes: String
    let amountTotal: Double?

    enum CodingKeys: String, CodingKey {
        case uid, propertyId, checkin, checkout, guests, notes
        case amountTotal = "amount_total"
    }
}

// Le serveur met toujours à jour tous les champs dans un UPDATE complet.
// Les types String non-optionnels garantissent que les champs existants
// ne sont pas effacés si l'utilisateur ne les modifie pas.
//
// ⚠️ guest_address et guest_zip restent absents de ce corps : l'app ne les
// connaît pas. Sans le COALESCE côté serveur (voir SERVEUR-RESA.md), ils sont
// remis à NULL à chaque enregistrement depuis iOS.
private struct ManualEditBody: Encodable {
    let propertyId: String
    let start: String
    let end: String
    let guestName: String
    let notes: String
    let phone: String
    let email: String
    let guestCountry: String
    let platform: String
    let price: Double?
    let occupancyAdults: Int?
    let amountRooms: Double?
    let amountCleaning: Double?
    let amountTaxes: Double?
    let otaCommission: Double?

    enum CodingKeys: String, CodingKey {
        case propertyId, start, end, guestName, notes, phone, email, platform, price
        case guestCountry    = "guest_country"
        case occupancyAdults = "occupancy_adults"
        case amountRooms     = "amount_rooms"
        case amountCleaning  = "amount_cleaning"
        case amountTaxes     = "amount_taxes"
        case otaCommission   = "ota_commission"
    }
}
