import SwiftUI
import PDFKit

struct ContractDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ContractDetailViewModel
    var onDeleted: (() -> Void)? = nil

    @State private var pdfData: Data?       = nil
    @State private var showPdf              = false
    @State private var isPdfLoading         = false
    @State private var pdfError: String?    = nil

    @State private var partiesExpanded      = false
    @State private var missionsExpanded     = false
    @State private var honExpanded          = false
    @State private var condExpanded         = false

    @State private var voyageurExpanded     = false
    @State private var bienExpanded         = false
    @State private var tarifsExpanded       = false
    @State private var condRentalExpanded   = false

    @State private var resendError: String?    = nil
    @State private var showDeleteConfirm       = false
    @State private var deleteError: String?    = nil

    init(contractId: String, onDeleted: (() -> Void)? = nil) {
        _vm = State(initialValue: ContractDetailViewModel(contractId: contractId))
        self.onDeleted = onDeleted
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch vm.loadState {
                case .loading:
                    Spacer()
                    ProgressView().tint(Color.bhAttenue)
                    Spacer()
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    if let detail = vm.detail { loadedContent(detail) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .sheet(isPresented: $showPdf) {
            if let data = pdfData {
                PdfSheetView(data: data, contractId: vm.contractId)
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { resendError != nil },
            set: { if !$0 { resendError = nil } }
        )) {
            Button("OK") { resendError = nil }
        } message: {
            Text(resendError ?? "")
        }
        .alert("Erreur PDF", isPresented: Binding(
            get: { pdfError != nil },
            set: { if !$0 { pdfError = nil } }
        )) {
            Button("OK") { pdfError = nil }
        } message: {
            Text(pdfError ?? "")
        }
        .alert("Supprimer ce contrat ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) { Task { await doDelete() } }
        } message: {
            Text("Cette action est définitive. Le contrat et son PDF seront supprimés.")
        }
        .alert("Erreur", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(statusSuperTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text(vm.detail?.typeLabel ?? "Contrat")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            Button {
                Task { await openPdf() }
            } label: {
                Group {
                    if isPdfLoading {
                        ProgressView()
                            .tint(Color.bhVert)
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                    }
                }
                .frame(width: 38, height: 38)
                .glassEffect(in: .circle)
                .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)
            .disabled(isPdfLoading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var statusSuperTitle: String {
        switch vm.detail?.status {
        case "sent":    return "En attente"
        case "signed":  return "Signé"
        case "expired": return "Expiré"
        default:        return " "
        }
    }

    // MARK: - Contenu chargé

    private func loadedContent(_ detail: ContractDetail) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    signerCard(detail)

                    if detail.isMandat {
                        HStack(spacing: 8) {
                            summaryBlock(value: vm.commissionSummary, label: "Rémunération", accent: true)
                            summaryBlock(value: vm.dureeSummary,      label: "Durée",        accent: false)
                            summaryBlock(value: vm.preavisSummary,    label: "Préavis",      accent: false)
                        }
                    } else {
                        HStack(spacing: 8) {
                            summaryBlock(value: vm.rentalPriceSummary,   label: "Total",   accent: true)
                            summaryBlock(value: vm.rentalStaySummary,    label: "Durée",   accent: false)
                            summaryBlock(value: vm.rentalDepositSummary, label: "Caution", accent: false)
                        }
                    }

                    contractBody(detail)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            actionBar(detail)
        }
    }

    // MARK: - Carte signataire

    private func signerCard(_ detail: ContractDetail) -> some View {
        HStack(spacing: 14) {
            ProfileAvatarView(
                logoUrl:   nil,
                firstName: detail.signerFirstName,
                lastName:  detail.signerLastName,
                company:   nil,
                size:      52
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.signerDisplayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                let addr = detail.propertySubtitle
                if !addr.isEmpty {
                    Text(addr)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(16)
        .background { GlassCardBackground(cornerRadius: 18) }
    }

    // MARK: - Trois blocs chiffres (même style que Step5View)

    private func summaryBlock(value: String, label: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent ? Color.bhVert : Color.bhEncre)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background { GlassCardBackground(cornerRadius: 18, fillOpacity: 0.66) }
    }

    // MARK: - Corps du contrat

    private func contractBody(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        let built = VStack(alignment: .leading, spacing: 0) {
            Text(detail.typeLabel.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 14)

            if detail.isMandat {
                let partiesBuilt = partiesContent(detail)
                sectionCard("Parties et bien", isExpanded: $partiesExpanded) { partiesBuilt }

                dividerLine

                let missionsBuilt = missionsContent(detail)
                let missionCount  = (d?.missions ?? []).count
                sectionCard("Missions", count: missionCount, isExpanded: $missionsExpanded) { missionsBuilt }

                dividerLine

                let honBuilt = honorairesContent(detail)
                let honCount = (d?.remuType ?? "").isEmpty ? 0 : nil
                sectionCard("Honoraires", count: honCount, isExpanded: $honExpanded) { honBuilt }

                dividerLine

                let condBuilt = conditionsContent(detail)
                sectionCard("Conditions", isExpanded: $condExpanded) { condBuilt }
            } else {
                let voyageurBuilt = voyageurContent(detail)
                sectionCard("Voyageur", isExpanded: $voyageurExpanded) { voyageurBuilt }

                dividerLine

                let bienBuilt = bienRentalContent(detail)
                sectionCard("Bien et propriétaire", isExpanded: $bienExpanded) { bienBuilt }

                dividerLine

                let tarifsBuilt = tarifsContent(detail)
                sectionCard("Tarifs", isExpanded: $tarifsExpanded) { tarifsBuilt }

                dividerLine

                let condRentalBuilt = conditionsRentalContent(detail)
                let reglesCount = (d?.regles ?? []).count
                sectionCard("Conditions", count: reglesCount > 0 ? reglesCount : nil,
                            isExpanded: $condRentalExpanded) { condRentalBuilt }
            }
        }
        .padding(18)

        return built
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .shadow(
                        color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.08),
                        radius: 22, x: 0, y: 8
                    )
            )
    }

    private var dividerLine: some View {
        Rectangle().fill(Color.white.opacity(0.30)).frame(height: 0.5)
            .padding(.horizontal, -18)
    }

    // MARK: - Section card helper (pattern Cas A — appel anticipé avant la fermeture escaping)

    private func sectionCard<Content: View>(
        _ title: String,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let built = content()
        return DisclosureGroup(isExpanded: isExpanded) {
            Divider().padding(.top, 8).padding(.bottom, 4)
            built
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                if let n = count {
                    Text("\(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(n > 0 ? Color.bhVert : Color.bhAttenue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(n > 0 ? Color.bhMentheFond : Color.bhAttenue.opacity(0.12)))
                }
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Section Parties et bien

    private func partiesContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        return VStack(spacing: 0) {
            detailRow("Propriétaire",
                value: [d?.ownerFirstName, d?.ownerLastName]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
            if let e = d?.ownerEmail,  !e.isEmpty { detailRow("Email",    value: e) }
            if let a = d?.ownerAddress, !a.isEmpty { detailRow("Adresse propriétaire", value: a) }
            if let a = d?.propAddress, !a.isEmpty  { detailRow("Adresse du bien", value: a) }
            if let t = d?.propType,    !t.isEmpty  { detailRow("Type de bien", value: propTypeLabel(t)) }
            if let c = d?.propCapacity, !c.isEmpty { detailRow("Capacité",   value: "\(c)\u{202F}pers.") }
            if let s = d?.minStay,     !s.isEmpty  { detailRow("Séjour min", value: "\(s)\u{202F}nuits") }
            if let s = d?.maxStay,     !s.isEmpty  { detailRow("Séjour max", value: "\(s)\u{202F}nuits") }
            if let v = d?.animals               { detailRow("Animaux",  value: animalsLabel(v)) }
            if let v = d?.smoking               { detailRow("Fumeur",   value: smokingLabel(v)) }
            if let v = d?.parties               { detailRow("Fêtes",    value: partiesLabel(v)) }
            if let v = d?.checkinTime,  !v.isEmpty { detailRow("Arrivée", value: Formatters.time(v) ?? v) }
            if let v = d?.checkoutTime, !v.isEmpty { detailRow("Départ",  value: Formatters.time(v) ?? v, separator: false) }
        }
    }

    // MARK: - Section Missions

    private func missionsContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        let missions = d?.missions ?? []
        let extras   = d?.extrasFacturables ?? []
        let urgence  = d?.urgenceLimit ?? ""

        return VStack(spacing: 0) {
            if missions.isEmpty && extras.isEmpty && urgence.isEmpty {
                Text("Aucune mission ni extra.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(missions.enumerated()), id: \.offset) { _, m in
                    detailItem(m)
                }
                if !urgence.isEmpty {
                    detailRow("Plafond urgence",
                        value: "\(urgence)\u{202F}€ TTC",
                        separator: !extras.isEmpty)
                }
                ForEach(Array(extras.enumerated()), id: \.offset) { idx, e in
                    detailItem(e, separator: idx < extras.count - 1)
                }
            }
        }
    }

    // MARK: - Section Honoraires

    @ViewBuilder
    private func honorairesContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        if (d?.remuType ?? "").isEmpty {
            Text("Aucun type de rémunération.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                detailRow("Type", value: remuTypeLabel(d?.remuType ?? ""))
                switch d?.remuType ?? "" {
                case "commission":
                    if let r = d?.commissionRate, !r.isEmpty {
                        detailRow("Taux",       value: "\(r)\u{202F}%")
                    }
                    detailRow("Base de calcul", value: commissionBaseLabel(d?.commissionBase ?? "ht"))
                case "forfait_mensuel":
                    if let f = d?.forfaitMensuel, !f.isEmpty {
                        detailRow("Forfait",    value: "\(f)\u{202F}€/mois")
                    }
                case "forfait_resa":
                    if let f = d?.forfaitResa, !f.isEmpty {
                        detailRow("Forfait / rés.", value: "\(f)\u{202F}€")
                    }
                case "mixte":
                    if let r = d?.mixteRate,    !r.isEmpty { detailRow("Taux",    value: "\(r)\u{202F}%") }
                    if let f = d?.mixteForfait, !f.isEmpty { detailRow("Forfait", value: "\(f)\u{202F}€/mois") }
                default:
                    EmptyView()
                }
                if let v = d?.tva          { detailRow("TVA",           value: tvaLabel(v)) }
                if let v = d?.tarifPreavis, !v.isEmpty { detailRow("Délai préavis", value: "\(v)\u{202F}jours") }
                if let v = d?.reversement  { detailRow("Reversement",   value: reversementLabel(v), separator: false) }
            }
        }
    }

    // MARK: - Section Conditions

    private func conditionsContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        let clauses = d?.clausesPersonnalisees ?? []

        return VStack(spacing: 0) {
            if let v = d?.dureeType {
                detailRow("Durée", value: dureeTypeLabel(v))
                if v == "determinee" {
                    if let s = d?.dateDebut,  !s.isEmpty { detailRow("Date de début",  value: formatDateISO(s)) }
                    if let s = d?.dureeMois,  !s.isEmpty { detailRow("Durée (mois)",   value: "\(s)\u{202F}mois") }
                    if let r = d?.renouvellement         { detailRow("Renouvellement", value: renouvellementLabel(r)) }
                }
            }
            if let v = d?.preavis      { detailRow("Préavis résiliation", value: preavisLabel(v)) }
            if let v = d?.exclusivite  { detailRow("Exclusivité",         value: exclusiviteLabel(v)) }
            if let v = d?.respPlafond  { detailRow("Responsabilité",      value: respPlafondLabel(v)) }
            if let v = d?.juridiction  { detailRow("Juridiction",         value: juridictionLabel(v)) }
            if let v = d?.confidentialite {
                detailRow("Confidentialité", value: confidentialiteLabel(v), separator: !clauses.isEmpty)
            }
            ForEach(Array(clauses.enumerated()), id: \.offset) { idx, c in
                detailItem(c, separator: idx < clauses.count - 1)
            }
        }
    }

    // MARK: - Section Voyageur (contrat de location)

    private func voyageurContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        return VStack(spacing: 0) {
            let name = [d?.guestFirstName, d?.guestLastName]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !name.isEmpty { detailRow("Voyageur", value: name) }
            if let v = d?.guestCount,       !v.isEmpty { detailRow("Nb voyageurs",   value: "\(v)\u{202F}pers.") }
            if let v = d?.guestEmail,        !v.isEmpty { detailRow("Email",          value: v) }
            if let v = d?.guestPhone,        !v.isEmpty { detailRow("Téléphone",      value: v) }
            if let v = d?.guestAddress,      !v.isEmpty { detailRow("Adresse",        value: v) }
            if let v = d?.guestNationality,  !v.isEmpty { detailRow("Nationalité",    value: v) }
            if let v = d?.guestIDNumber,     !v.isEmpty { detailRow("Pièce d'identité", value: v) }
            if let v = d?.guestDOB,          !v.isEmpty { detailRow("Date de naissance", value: formatDateISO(v), separator: false) }
        }
    }

    // MARK: - Section Bien et propriétaire (contrat de location)

    private func bienRentalContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        return VStack(spacing: 0) {
            if let v = d?.propertyName,    !v.isEmpty { detailRow("Bien",          value: v) }
            if let v = d?.propertyAddress, !v.isEmpty { detailRow("Adresse",       value: v) }
            if let v = d?.propertyType,    !v.isEmpty { detailRow("Type",          value: propTypeLabel(v)) }
            if let v = d?.checkin,         !v.isEmpty { detailRow("Arrivée",       value: formatDateISO(v)) }
            if let v = d?.checkout,        !v.isEmpty { detailRow("Départ",        value: formatDateISO(v)) }
            if let v = d?.checkinTime,     !v.isEmpty { detailRow("Heure arrivée", value: Formatters.time(v) ?? v) }
            if let v = d?.checkoutTime,    !v.isEmpty { detailRow("Heure départ",  value: Formatters.time(v) ?? v) }
            let ownerName = [d?.ownerFirstName, d?.ownerLastName]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            if !ownerName.isEmpty { detailRow("Propriétaire",         value: ownerName) }
            if let v = d?.ownerAddress, !v.isEmpty { detailRow("Adresse propriétaire", value: v) }
            if let v = d?.ownerEmail,   !v.isEmpty { detailRow("Email propriétaire",   value: v, separator: false) }
        }
    }

    // MARK: - Section Tarifs (contrat de location)

    private func tarifsContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        return VStack(spacing: 0) {
            if let v = d?.totalPrice,        !v.isEmpty { detailRow("Total séjour",     value: "\(v)\u{202F}€") }
            if let v = d?.acompte,           !v.isEmpty { detailRow("Acompte",          value: "\(v)\u{202F}€") }
            if let v = d?.acompteDate,       !v.isEmpty { detailRow("Date acompte",     value: formatDateISO(v)) }
            if let v = d?.deposit,           !v.isEmpty { detailRow("Caution",          value: "\(v)\u{202F}€") }
            if let v = d?.depositReturnDays, !v.isEmpty { detailRow("Retour caution",   value: "\(v)\u{202F}jours") }
            if let v = d?.cleaningFee,       !v.isEmpty { detailRow("Frais ménage",     value: "\(v)\u{202F}€") }
            if let v = d?.paymentMethod,     !v.isEmpty { detailRow("Paiement",         value: paymentMethodLabel(v)) }
            if let v = d?.priceNotes,        !v.isEmpty { detailRow("Notes",            value: v, separator: false) }
        }
    }

    // MARK: - Section Conditions (contrat de location)

    private func conditionsRentalContent(_ detail: ContractDetail) -> some View {
        let d = detail.contractData
        let regles = d?.regles ?? []
        return VStack(spacing: 0) {
            let hasCancels = (d?.cancelPct1 ?? "").isEmpty == false || (d?.cancelPct2 ?? "").isEmpty == false
            if hasCancels {
                if let p = d?.cancelPct1, !p.isEmpty {
                    let days = d?.cancelDays1 ?? ""
                    detailRow("Annulation tranche 1",
                        value: days.isEmpty ? "\(p)\u{202F}%" : "\(p)\u{202F}% · \(days)\u{202F}j")
                }
                if let p = d?.cancelPct2, !p.isEmpty {
                    let days = d?.cancelDays2 ?? ""
                    detailRow("Annulation tranche 2",
                        value: days.isEmpty ? "\(p)\u{202F}%" : "\(p)\u{202F}% · \(days)\u{202F}j")
                }
            }
            if let v = d?.inclEDL        { detailRow("État des lieux",         value: v ? "Inclus" : "Non inclus") }
            if let v = d?.inclAssurance  { detailRow("Assurance",              value: v ? "Incluse" : "Non incluse") }
            if let v = d?.inclAnnulation { detailRow("Assurance annulation",   value: v ? "Incluse" : "Non incluse") }
            if let v = d?.inclObligations {
                let hasMore = !(d?.obligationsExtra ?? "").isEmpty || !regles.isEmpty
                detailRow("Obligations voyageur", value: v ? "Oui" : "Non", separator: hasMore)
            }
            if let v = d?.obligationsExtra, !v.isEmpty {
                detailRow("Précisions obligations", value: v, separator: !regles.isEmpty)
            }
            ForEach(Array(regles.enumerated()), id: \.offset) { idx, r in
                detailItem(r, separator: idx < regles.count - 1)
            }
        }
    }

    // MARK: - Barre d'action

    @ViewBuilder
    private func actionBar(_ detail: ContractDetail) -> some View {
        VStack(spacing: 6) {
            switch detail.status ?? "" {
            case "sent":
                PrimaryButton(title: vm.resendState == .sending ? "Envoi…" : "Renvoyer le lien") {
                    Task { await doResend() }
                }
                .disabled(vm.resendState == .sending)
                .opacity(vm.resendState == .sending ? 0.55 : 1)

                if vm.resendState == .done {
                    Text("Lien renvoyé")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhVert)
                } else if let d = detail.createdAt, !d.isEmpty {
                    Text("Envoyé le \(Formatters.day(d))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                }

            case "signed":
                PrimaryButton(title: isPdfLoading ? "Chargement…" : "Voir le PDF") {
                    Task { await openPdf() }
                }
                .disabled(isPdfLoading)
                .opacity(isPdfLoading ? 0.55 : 1)

                if let d = detail.guestSignedAt, !d.isEmpty {
                    Text("Signé le \(Formatters.day(d))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                }

            case "expired":
                PrimaryButton(title: vm.resendState == .sending ? "Envoi…" : "Renvoyer le lien") {
                    Task { await doResend() }
                }
                .disabled(vm.resendState == .sending)
                .opacity(vm.resendState == .sending ? 0.55 : 1)

                if vm.resendState == .done {
                    Text("Lien renvoyé")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhVert)
                } else if let d = detail.signTokenExpiresAt, !d.isEmpty {
                    Text("Lien expiré le \(Formatters.day(d))")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                }

            default:
                EmptyView()
            }
            if (detail.status ?? "") != "signed" && (detail.guestSignedAt ?? "").isEmpty {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Group {
                        if vm.deleteState == .deleting {
                            ProgressView()
                                .tint(Color.bhTerracotta)
                                .scaleEffect(0.8)
                        } else {
                            Text("Supprimer le contrat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.bhTerracotta)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(vm.deleteState == .deleting)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Actions

    private func openPdf() async {
        isPdfLoading = true
        defer { isPdfLoading = false }
        if let data = await vm.fetchPdf() {
            pdfData = data
            showPdf = true
        } else {
            pdfError = "Impossible de charger le PDF."
        }
    }

    private func doResend() async {
        do {
            try await vm.resend()
        } catch {
            resendError = (error as? APIError)?.userMessage ?? "Erreur lors du renvoi."
        }
    }

    private func doDelete() async {
        let deleted = await vm.delete()
        if deleted {
            onDeleted?()
            dismiss()
        } else if case .error(let msg) = vm.deleteState {
            deleteError = msg
        }
        // .idle means 409 race: vm reloaded the detail — no error alert needed
    }

    // MARK: - État erreur

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await vm.load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Composants de ligne

    private func detailRow(_ label: String, value: String, separator: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.top, 1)
                Spacer()
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    private func detailItem(_ text: String, separator: Bool = true) -> some View {
        VStack(spacing: 0) {
            Text("·\u{202F}\(text)")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhEncre)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    // MARK: - Convertisseurs valeur → libellé (identiques à Step5View)

    private func propTypeLabel(_ v: String) -> String {
        switch v {
        case "appartement": return "Appartement"
        case "maison":      return "Maison"
        case "studio":      return "Studio"
        case "villa":       return "Villa"
        case "chambre":     return "Chambre"
        case "gite":        return "Gîte / Chalet"
        case "autre":       return "Autre"
        default:            return v
        }
    }
    private func animalsLabel(_ v: String) -> String {
        switch v {
        case "non":        return "Non admis"
        case "oui":        return "Admis"
        case "conditions": return "Sous conditions"
        default:           return v
        }
    }
    private func smokingLabel(_ v: String) -> String {
        switch v {
        case "non":       return "Interdit"
        case "exterieur": return "Extérieur seulement"
        case "oui":       return "Autorisé"
        default:          return v
        }
    }
    private func partiesLabel(_ v: String) -> String {
        switch v {
        case "non":        return "Interdits"
        case "conditions": return "Sous conditions"
        case "oui":        return "Autorisés"
        default:           return v
        }
    }
    private func remuTypeLabel(_ v: String) -> String {
        switch v {
        case "commission":      return "% sur revenus"
        case "forfait_mensuel": return "Forfait mensuel"
        case "forfait_resa":    return "Par réservation"
        case "mixte":           return "Mixte"
        case "carte":           return "À la carte"
        default:                return v
        }
    }
    private func commissionBaseLabel(_ v: String) -> String {
        switch v {
        case "ht":  return "Sur revenus HT"
        case "ttc": return "Sur revenus TTC"
        default:    return v
        }
    }
    private func tvaLabel(_ v: String) -> String {
        switch v {
        case "franchise": return "Auto-entrepreneur, sans TVA"
        case "ht":        return "HT — TVA en sus"
        case "ttc":       return "TTC toutes taxes comprises"
        default:          return v
        }
    }
    private func reversementLabel(_ v: String) -> String {
        switch v {
        case "par_resa":            return "À chaque réservation"
        case "hebdo":               return "Hebdomadaire"
        case "mensuel":             return "Mensuel"
        case "encaissement_direct": return "Encaissement direct par le propriétaire"
        default:                    return v
        }
    }
    private func dureeTypeLabel(_ v: String) -> String {
        switch v {
        case "indeterminee": return "Indéterminée"
        case "determinee":   return "Déterminée"
        default:             return v
        }
    }
    private func renouvellementLabel(_ v: String) -> String {
        switch v {
        case "tacite": return "Tacite reconduction"
        case "expres": return "Renouvellement exprès"
        default:       return v
        }
    }
    private func exclusiviteLabel(_ v: String) -> String {
        switch v {
        case "non":       return "Sans exclusivité"
        case "totale":    return "Exclusivité totale"
        case "partielle": return "Exclusivité partielle, sur les plateformes"
        default:          return v
        }
    }
    private func respPlafondLabel(_ v: String) -> String {
        switch v {
        case "oui": return "Limitée aux honoraires perçus"
        case "non": return "Responsabilité de droit commun"
        default:    return v
        }
    }
    private func juridictionLabel(_ v: String) -> String {
        switch v {
        case "domicile_defendeur": return "Domicile du défendeur"
        case "lieu_bien":          return "Lieu du bien"
        case "commerce":           return "Tribunal de commerce, si 2 sociétés"
        default:                   return v
        }
    }
    private func preavisLabel(_ v: String) -> String {
        if v == "0" { return "Aucun préavis" }
        return v.isEmpty ? "—" : "\(v)\u{202F}jours"
    }
    private func confidentialiteLabel(_ v: String) -> String {
        v.isEmpty ? "—" : "\(v)\u{202F}ans"
    }
    private func paymentMethodLabel(_ v: String) -> String {
        switch v {
        case "virement": return "Virement bancaire"
        case "cheque":   return "Chèque"
        case "especes":  return "Espèces"
        case "carte":    return "Carte bancaire"
        default:         return v
        }
    }

    private func formatDateISO(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        guard let date = f.date(from: s) else { return s }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "fr_FR")
        return df.string(from: date)
    }
}

// MARK: - Feuille PDF

private struct PdfSheetView: View {
    let data: Data
    let contractId: String

    @Environment(\.dismiss) private var dismiss

    private var tempURL: URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("contrat-\(contractId).pdf")
        try? data.write(to: url)
        return url
    }

    var body: some View {
        NavigationStack {
            PDFKitView(data: data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Contrat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Fermer") { dismiss() }
                            .foregroundStyle(Color.bhVert)
                    }
                    if let url = tempURL {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            ShareLink(
                                item: url,
                                preview: SharePreview("Contrat.pdf", image: Image(systemName: "doc.pdf"))
                            )
                            .foregroundStyle(Color.bhVert)
                        }
                    }
                }
        }
    }
}

// MARK: - Visionneuse PDFKit

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let doc = PDFDocument(data: data) {
            pdfView.document = doc
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
