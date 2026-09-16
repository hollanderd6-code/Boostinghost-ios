import SwiftUI

struct ReservationDetailView: View {
    let arrivee: Arrivee

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthStore.self) private var authStore
    @Environment(CalendarViewModel.self) private var calendarVM

    private var canViewFinances: Bool { authStore.session?.can("can_view_finances") ?? true }
    @State private var vm: ReservationDetailViewModel
    @State private var writeConversation: Conversation?
    @State private var showUpsellSheet     = false
    @State private var showHosterzzSheet  = false
    @State private var showInvoiceSheet      = false
    @State private var showCreateInvoiceSheet = false
    @State private var showEditSheet      = false
    @State private var showDeleteConfirm  = false
    @State private var otaNotesExpanded   = false

    init(arrivee: Arrivee) {
        self.arrivee = arrivee
        _vm = State(initialValue: ReservationDetailViewModel(arrivee: arrivee))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerCard
                        switch vm.state {
                        case .loading:
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding(.top, 28)
                        case .loaded:
                            detailContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await vm.load() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .sheet(item: $writeConversation) {
            ConversationDetailView(conversation: $0, ownerName: authStore.session?.displayName ?? "")
        }
        .sheet(isPresented: $showInvoiceSheet) {
            ReservationInvoiceSheet(
                reservationUid: arrivee.reservationUid,
                guestName:      guestFullName,
                propertyName:   arrivee.propertyName,
                startDate:      vm.reservation?.startDate ?? "",
                endDate:        vm.reservation?.endDate   ?? ""
            )
        }
        .sheet(isPresented: $showCreateInvoiceSheet) {
            InvoiceCreationSheet(arrivee: arrivee, reservation: vm.reservation)
        }
        .sheet(isPresented: $showEditSheet) {
            if let r = vm.reservation {
                ReservationEditSheet(reservation: r) {
                    Task {
                        await vm.load()
                        await calendarVM.silentRefresh()
                    }
                }
            }
        }
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(deleteActionLabel, role: .destructive) {
                Task { await vm.delete() }
            }
        } message: {
            Text(deleteConfirmMessage)
        }
        .alert("Erreur", isPresented: Binding(
            get:  { vm.deleteError != nil },
            set:  { if !$0 { vm.clearDeleteError() } }
        )) {
            Button("OK") { vm.clearDeleteError() }
        } message: {
            Text(vm.deleteError ?? "")
        }
        .onChange(of: vm.didDelete) { _, deleted in
            if deleted {
                Task { await calendarVM.silentRefresh() }
                dismiss()
            }
        }
        .sheet(isPresented: $showUpsellSheet) {
            if let convId = arrivee.conversationId {
                UpsellSheet(conversationId: convId)
            }
        }
        .sheet(isPresented: $showHosterzzSheet) {
            HosterzzMissionSheet(
                reservationId: arrivee.reservationUid,
                propertyName:  arrivee.propertyName,
                guestName:     arrivee.guestName ?? "Voyageur",
                departureDate: vm.reservation?.endDate
            ) { statut in
                vm.hosterzzMissionCreated(statut: statut)
            }
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(arrivee.propertyName)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                Text("Réservation")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 8)

            // Bouton Modifier — masqué pour les bloquages et pour les OTA avec sous-compte
            if vm.state == .loaded, let r = vm.reservation, !r.isBlock {
                let isOTASubAccount = r.source?.lowercased() == "channex"
                    && authStore.session?.isSubAccount == true
                if !isOTASubAccount {
                    Button { showEditSheet = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                            .frame(width: 38, height: 38)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 19)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let convId = arrivee.conversationId {
                Button {
                    writeConversation = Conversation(
                        arriveeId:    convId,
                        guestName:    arrivee.guestName ?? "Voyageur",
                        platform:     arrivee.platform,
                        propertyName: arrivee.propertyName,
                        escalated:    arrivee.blocking.contains("ia_a_passe_la_main"),
                        aiDisabled:   arrivee.aiDisabled
                    )
                } label: {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)
            }
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

    // MARK: - En-tête (visible immédiatement, enrichi après chargement)
    // Téléphone et email sont dans la section Contact en dessous.

    private var headerCard: some View {
        ListCard(heroFill: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(guestFullName)
                        .font(.bhTitreLigneL)
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    PlatformBadge(platform: arrivee.platform)
                }

                HStack(spacing: 0) {
                    Image(systemName: "person.2")
                        .imageScale(.small)
                        .foregroundStyle(Color.bhAttenue)
                    Text(occupancyLabel)
                        .padding(.leading, 5)
                    if let country = countryLabel {
                        Text("  ·  \(country)")
                    }
                }
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)

                HStack(alignment: .firstTextBaseline) {
                    if canViewFinances {
                        if let total = vm.reservation?.amountTotal {
                            Text(Formatters.amount(total))
                                .font(.system(size: 22, weight: .semibold))
                                .tracking(-0.6)
                                .foregroundStyle(Color.bhEncre)
                        } else {
                            Text("—")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    Spacer()
                    if let n = arrivee.nights {
                        Text(n == 1 ? "1 nuit" : "\(n) nuits")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Contenu détaillé (après chargement)

    @ViewBuilder
    private var detailContent: some View {
        SectionLabel(text: "Logement")
        logementCard

        SectionLabel(text: "Arrivée")
        dateCard(
            date: vm.reservation?.startDate ?? "",
            time: arrivee.arrivalTime ?? vm.propertySummary?.arrivalTime
        )

        SectionLabel(text: "Départ")
        dateCard(
            date: vm.reservation?.endDate ?? "",
            time: vm.propertySummary?.departureTime
        )

        SectionLabel(text: "Ménage")
        menageCard

        if canViewFinances {
            prixDetailSection
        }

        contactSection

        if let notes = vm.reservation?.notes, !notes.isEmpty {
            SectionLabel(text: "Notes")
            notesCard(notes)
        }

        upsellSection

        hosterzzSection

        factureSection

        reservationSection

        otaNotesSection

        deleteSection
    }

    // MARK: - Bloc Logement

    private var logementCard: some View {
        ListCard {
            VStack(spacing: 0) {
                let hasTimesRow = vm.propertySummary?.arrivalTime != nil
                    || vm.propertySummary?.departureTime != nil
                    || arrivee.arrivalTime != nil

                CardRow(showSeparator: hasTimesRow) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(arrivee.propertyName)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                        if let addr = arrivee.propertyAddress, !addr.isEmpty {
                            Text(addr)
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                }

                if hasTimesRow {
                    CardRow(showSeparator: false) {
                        HStack(spacing: 24) {
                            if let arrTime = Formatters.time(
                                vm.propertySummary?.arrivalTime ?? arrivee.arrivalTime
                            ) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("ARRIVÉE").bhIntertitre()
                                    Text(arrTime)
                                        .font(.bhTitreLigne)
                                        .foregroundStyle(Color.bhEncre)
                                }
                            }
                            if let depTime = Formatters.time(vm.propertySummary?.departureTime) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("DÉPART").bhIntertitre()
                                    Text(depTime)
                                        .font(.bhTitreLigne)
                                        .foregroundStyle(Color.bhEncre)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Carte date (Arrivée / Départ)

    private func dateCard(date: String, time: String?) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack {
                    if date.isEmpty {
                        Text("—")
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhAttenue)
                    } else {
                        Text(Formatters.dayWithYear(date))
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                    }
                    Spacer()
                    if let t = Formatters.time(time) {
                        Text(t)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                    }
                }
            }
        }
    }

    // MARK: - Prix détaillé

    @ViewBuilder
    private var prixDetailSection: some View {
        if let r = vm.reservation,
           r.amountTotal != nil || r.amountRooms != nil {
            SectionLabel(text: "Prix détaillé")
            prixDetailCard(r)
        }
    }

    private func prixDetailCard(_ r: Reservation) -> some View {
        // Détection bruts/nets (app.html:9858) — portée sur les données, jamais sur la plateforme
        let isNet: Bool = {
            guard let hp = r.hostPayout,
                  let at = r.amountTotal,
                  let oc = r.otaCommission else { return false }
            return oc > 0 && abs(hp - at) < 0.01
        }()

        let displayTotal: Double?
        let displayRooms: Double?
        if isNet, let at = r.amountTotal, let oc = r.otaCommission {
            let gt = at + oc
            displayTotal = gt
            displayRooms = gt - (r.amountCleaning ?? 0) - (r.amountTaxes ?? 0)
        } else {
            displayTotal = r.amountTotal
            displayRooms = r.amountRooms
        }

        let hasMenage = r.amountCleaning != nil
        let hasOta    = r.otaCommission  != nil
        let hasTotal  = displayTotal     != nil
        let hasPayout = r.hostPayout     != nil

        return ListCard {
            VStack(spacing: 0) {
                if let v = displayRooms {
                    CardRow(showSeparator: hasMenage || hasOta || hasTotal || hasPayout) {
                        nuitsContent(grossRooms: v, breakdown: r.daysBreakdown, isNet: isNet)
                    }
                }
                if let v = r.amountCleaning {
                    CardRow(showSeparator: hasOta || hasTotal || hasPayout) {
                        prixRow("Ménage", amount: v)
                    }
                }
                if let v = r.otaCommission {
                    CardRow(showSeparator: hasTotal || hasPayout) {
                        prixRow("Commission OTA", amount: isNet ? -v : v, red: true)
                    }
                }
                if let v = displayTotal {
                    CardRow(showSeparator: hasPayout) {
                        prixRow(isNet ? "Total voyageur" : "Total", amount: v, bold: true)
                    }
                }
                if let v = r.hostPayout {
                    CardRow(showSeparator: false) {
                        prixRow("Net hôte", amount: v, bold: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nuitsContent(grossRooms: Double, breakdown: [String: Double]?, isNet: Bool) -> some View {
        // Non-net : use breakdown sum when available (amountRooms may include cleaning).
        // Net : grossRooms is already the correct total; per-night values are scaled by ratio.
        let displayNuits: Double = {
            if !isNet, let b = breakdown, !b.isEmpty { return b.values.reduce(0, +) }
            return grossRooms
        }()
        prixRow("Nuits", amount: displayNuits)
        if let breakdown, !breakdown.isEmpty {
            let sorted = breakdown.sorted { $0.key < $1.key }
            // Pre-compute per-night prices — last night absorbs rounding (app.html:9879-9893)
            let displayPrices: [Double] = {
                guard isNet else { return sorted.map(\.value) }
                let nightsSum = breakdown.values.reduce(0, +)
                let ratio = nightsSum == 0 ? 1.0 : grossRooms / nightsSum
                var result = [Double]()
                var running = 0.0
                for (i, entry) in sorted.enumerated() {
                    if i == sorted.count - 1 {
                        result.append(grossRooms - running)
                    } else {
                        let v = (entry.value * ratio * 100).rounded() / 100
                        running += v
                        result.append(v)
                    }
                }
                return result
            }()
            ForEach(Array(zip(sorted, displayPrices)), id: \.0.key) { entry, price in
                HStack {
                    Text(Formatters.dayShort(entry.key))
                        .padding(.leading, 10)
                    Spacer()
                    Text(Formatters.amountDecimal(price))
                }
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.bhAttenue)
                .padding(.top, 3)
            }
        }
    }

    private func prixRow(_ label: String, amount: Double, red: Bool = false, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .bhTitreLigne : .bhMeta)
                .foregroundStyle(Color.bhEncre)
            Spacer()
            Text(Formatters.amountDecimal(amount))
                .font(bold ? .bhTitreLigne : .bhMeta)
                .foregroundStyle(red ? Color.bhTerracotta : (bold ? Color.bhEncre : Color.bhAttenue))
        }
    }

    // MARK: - Ménage

    private var menageCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                        .foregroundStyle(Color.bhAttenue)
                    if let name = vm.cleanerName {
                        Text(name)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                    } else {
                        Text("Non assigné")
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Contact (téléphone + email groupés)

    @ViewBuilder
    private var contactSection: some View {
        let phone = phoneLabel
        let email = emailLabel
        if phone != nil || email != nil {
            SectionLabel(text: "Contact")
            ListCard {
                VStack(spacing: 0) {
                    if let phone {
                        CardRow(showSeparator: email != nil) {
                            phoneRow(phone)
                        }
                    }
                    if let email {
                        CardRow(showSeparator: false) {
                            emailRow(email)
                        }
                    }
                }
            }
        }
    }

    private func phoneRow(_ phone: String) -> some View {
        Button {
            if let url = phoneCallURL(phone) { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color.bhVert)
                Text(phone)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhVert)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                if let url = phoneCallURL(phone) { openURL(url) }
            } label: {
                Label("Appeler", systemImage: "phone")
            }
            Button {
                if let url = phoneSMSURL(phone) { openURL(url) }
            } label: {
                Label("Envoyer un SMS", systemImage: "message")
            }
            Button {
                UIPasteboard.general.string = phone
            } label: {
                Label("Copier le numéro", systemImage: "doc.on.doc")
            }
        }
    }

    private func emailRow(_ email: String) -> some View {
        Button {
            if let url = URL(string: "mailto:\(email)") { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color.bhVert)
                Text(email)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhVert)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                if let url = URL(string: "mailto:\(email)") { openURL(url) }
            } label: {
                Label("Envoyer un e-mail", systemImage: "envelope")
            }
            Button {
                UIPasteboard.general.string = email
            } label: {
                Label("Copier l'adresse", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Notes

    private func notesCard(_ text: String) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                Text(text)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhCorps)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Prestations payantes

    @ViewBuilder
    private var upsellSection: some View {
        if arrivee.conversationId != nil {
            SectionLabel(text: "Prestations payantes")
            ListCard {
                CardRow(showSeparator: false) {
                    Button { showUpsellSheet = true } label: {
                        HStack {
                            Text("Générer un lien de prestation")
                                .font(.bhTitreLigne)
                                .foregroundStyle(Color.bhEncre)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Hosterzz

    @ViewBuilder
    private var hosterzzSection: some View {
        // Hidden entirely for sub-accounts (authenticateToken only).
        if authStore.session?.isSubAccount != true {
            switch vm.hosterzzMissionState {
            case .loading:
                EmptyView()
            case .noMission:
                SectionLabel(text: "Hosterzz")
                PrimaryButton(title: "Créer la mission Hosterzz") {
                    showHosterzzSheet = true
                }
            case .missionExists(let statut):
                SectionLabel(text: "Hosterzz")
                ListCard {
                    CardRow(showSeparator: false) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.small)
                                .foregroundStyle(Color.bhVert)
                            Text("Mission créée")
                                .font(.bhTitreLigne)
                                .foregroundStyle(Color.bhEncre)
                            Spacer()
                            if let s = statut, !s.isEmpty {
                                Text(s)
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Factures

    @ViewBuilder
    private var factureSection: some View {
        if authStore.session?.can("can_manage_invoices") ?? true {
            SectionLabel(text: "Factures")
            ListCard {
                VStack(spacing: 0) {
                    CardRow(showSeparator: true) {
                        Button { showInvoiceSheet = true } label: {
                            HStack {
                                Text("Historique")
                                    .font(.bhTitreLigne)
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    CardRow(showSeparator: false) {
                        Button { showCreateInvoiceSheet = true } label: {
                            HStack {
                                Text("Générer une facture")
                                    .font(.bhTitreLigne)
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    // MARK: - Réservation (métadonnée, tout en bas)

    @ViewBuilder
    private var reservationSection: some View {
        if let created = vm.reservation?.createdAt, !created.isEmpty {
            SectionLabel(text: "Réservation")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Réservé le")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                        Text(Formatters.dayWithYear(created))
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    // MARK: - Informations de la plateforme

    private static let otaNotesPreviewLength = 320

    @ViewBuilder
    private var otaNotesSection: some View {
        if let raw = vm.reservation?.otaNotes,
           let text = cleanOtaNotes(raw), !text.isEmpty {
            SectionLabel(text: "Informations de la plateforme")
            ListCard {
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        let truncated = !otaNotesExpanded
                            && text.count > Self.otaNotesPreviewLength
                        Text(truncated
                             ? String(text.prefix(Self.otaNotesPreviewLength)) + "…"
                             : text)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhCorps)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if text.count > Self.otaNotesPreviewLength {
                            Button { otaNotesExpanded.toggle() } label: {
                                Text(otaNotesExpanded ? "Voir moins" : "Voir plus")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhVert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func cleanOtaNotes(_ raw: String) -> String? {
        let cleaned = raw
            .replacingOccurrences(
                of: #"<br\s*/?>"#,
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Suppression

    // OTA (channex) : bouton masqué — le serveur refuse avec un 403.
    @ViewBuilder
    private var deleteSection: some View {
        if let r = vm.reservation, !r.isBlock, r.source?.lowercased() != "channex" {
            SectionLabel(text: "Zone dangereuse")
            Button { showDeleteConfirm = true } label: {
                Text(r.isBhGuest ? "Annuler la réservation" : "Supprimer la réservation")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Color.bhTerracotta,
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var deleteConfirmTitle: String {
        guard let r = vm.reservation else { return "Supprimer ?" }
        return r.isBhGuest ? "Annuler la réservation ?" : "Supprimer la réservation ?"
    }

    private var deleteActionLabel: String {
        guard let r = vm.reservation else { return "Supprimer" }
        return r.isBhGuest ? "Annuler la réservation" : "Supprimer définitivement"
    }

    private var deleteConfirmMessage: String {
        guard let r = vm.reservation else { return "" }
        if r.isBhGuest {
            return "La réservation passera à l'état « annulée ». La caution éventuelle sera libérée et les assignations de ménage supprimées."
        }
        return "Cette suppression est définitive. La caution éventuelle sera libérée et les assignations de ménage supprimées."
    }

    // MARK: - Helpers

    private var guestFullName: String {
        if let r = vm.reservation {
            let first = r.guestFirstName ?? ""
            let last  = r.guestLastName  ?? ""
            let full  = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            if !full.isEmpty { return full }
            if let name = r.guestName, !name.isEmpty { return name }
        }
        return arrivee.guestName ?? "Voyageur"
    }

    private var occupancyLabel: String {
        if let r = vm.reservation, let adults = r.occupancyAdults {
            let children = r.occupancyChildren ?? 0
            let adultStr = adults == 1 ? "1 adulte" : "\(adults) adultes"
            if children > 0 {
                let childStr = children == 1 ? "1 enfant" : "\(children) enfants"
                return "\(adultStr) · \(childStr)"
            }
            return adultStr
        }
        if let total = arrivee.guests, total > 0 {
            return total == 1 ? "1 personne" : "\(total) personnes"
        }
        return "—"
    }

    private var countryLabel: String? {
        guard let code = vm.reservation?.guestCountry, !code.isEmpty else { return nil }
        return Locale(identifier: "fr_FR").localizedString(forRegionCode: code) ?? code
    }

    private var phoneLabel: String? {
        if let phone = vm.reservation?.guestPhone, !phone.isEmpty { return phone }
        if let phone = arrivee.guestPhone, !phone.isEmpty { return phone }
        return nil
    }

    private var emailLabel: String? {
        guard let email = vm.reservation?.guestEmail, !email.isEmpty else { return nil }
        return email
    }

    // MARK: - URL helpers pour téléphone

    private func normalizedPhone(_ raw: String) -> String {
        let hasPlus = raw.trimmingCharacters(in: .whitespaces).hasPrefix("+")
        let digits  = raw.filter(\.isNumber)
        if hasPlus                              { return "+\(digits)" }
        // Format local français : 0XXXXXXXXX → +33XXXXXXXXX
        if digits.hasPrefix("0"), digits.count == 10 { return "+33\(digits.dropFirst())" }
        // International sans + : "33XXXXXXXXX"
        return "+\(digits)"
    }

    private func phoneCallURL(_ raw: String) -> URL? {
        URL(string: "tel:\(normalizedPhone(raw))")
    }

    private func phoneSMSURL(_ raw: String) -> URL? {
        URL(string: "sms:\(normalizedPhone(raw))")
    }
}
