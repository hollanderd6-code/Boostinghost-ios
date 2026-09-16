import SwiftUI

// MARK: - Fiche logement (lecture seule)

struct PropertyDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AuthStore.self) private var authStore

    let vm: PropertiesViewModel
    @State private var property: Property

    init(property: Property, vm: PropertiesViewModel) {
        self.vm = vm
        self._property = State(initialValue: property)
    }

    private enum BlockNav: Hashable {
        case identite, sejour, argent, prestations, acces, quartier, equipements, ia, plateformes
    }
    @State private var activeBlock: BlockNav? = nil

    @State private var showDuplicateSheet  = false
    @State private var showConnectSheet    = false
    @State private var showDisconnectAlert = false
    @State private var isDisconnecting     = false
    @State private var showDeleteAlert     = false
    @State private var isDeleting          = false
    @State private var isSyncing           = false
    @State private var syncResult: String? = nil
    @State private var actionError: String? = nil

    // Diffusion section
    @State private var showDiffusionSheet   = false
    @State private var connectedChannels: [ConnectedChannel] = []
    @State private var channelsLoaded       = false
    @State private var showSyncPrompt       = false
    @State private var isSyncingDiffusion   = false
    @State private var syncDiffusionStep    = ""
    @State private var syncDiffusionResult: String? = nil

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        livretCard
                        blocksCard
                        diffusionSection
                        icalSection
                        duplicateButton
                        channexActionButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showDuplicateSheet) {
            DuplicatePropertySheet(source: property) {
                Task { await vm.load() }
            }
        }
        .sheet(isPresented: $showConnectSheet) {
            PropertyChannexSheet(property: property) {
                Task {
                    await reloadProperty()
                    await loadConnectedChannels()
                }
            }
        }
        .sheet(isPresented: $showDiffusionSheet) {
            PropertyDiffusionSheet(property: property)
        }
        .onChange(of: showDiffusionSheet) { _, new in
            guard !new else { return }
            showSyncPrompt     = true
            syncDiffusionResult = nil
            Task { await loadConnectedChannels() }
        }
        .task { await loadConnectedChannels() }
        .alert("Déconnecter la diffusion ?", isPresented: $showDisconnectAlert) {
            Button("Déconnecter quand même", role: .destructive) {
                Task { await disconnect() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les identifiants de diffusion seront supprimés de cette application, mais la fiche restera active chez le prestataire et les réservations continueront d'arriver — sans que les disponibilités soient mises à jour. Risque de double réservation.")
        }
        .alert("Erreur", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .alert("Synchronisation", isPresented: Binding(
            get: { syncResult != nil },
            set: { if !$0 { syncResult = nil } }
        )) {
            Button("OK", role: .cancel) { syncResult = nil }
        } message: {
            Text(syncResult ?? "")
        }
        .alert("Supprimer ce logement ?", isPresented: $showDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                Task { await deleteProperty() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .navigationDestination(item: $activeBlock) { block in
            switch block {
            case .identite:
                IdentiteBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .sejour:
                SejourBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .argent:
                ArgentBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .prestations:
                PrestationsBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .acces:
                AccesBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .quartier:
                QuartierBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .equipements:
                EquipementsBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .ia:
                AssistantIABlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            case .plateformes:
                PlateformesBlockView(property: property) { updated in
                    property = updated
                    vm.updateProperty(updated)
                }
            }
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        ZStack {
            VStack(spacing: 1) {
                Text(surTitre)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(property.internalName ?? property.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 96)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 36, height: 36)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 18)
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button {
                        showDuplicateSheet = true
                    } label: {
                        Label("Dupliquer", systemImage: "doc.on.doc")
                    }

                    Button {
                        Task { await syncProperty() }
                    } label: {
                        Label(isSyncing ? "Synchronisation…" : "Resynchroniser",
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isSyncing)

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 36, height: 36)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 18)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var surTitre: String {
        var parts: [String] = []
        if let g = vm.groupName(for: property) { parts.append(g) }
        if let a = property.address, !a.isEmpty { parts.append(a) }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    // MARK: - Carte Livret d'accueil

    private var livretCard: some View {
        let filled = livretFilled
        return ListCard {
            CardRow(showSeparator: false) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.bhMentheFond)
                            .frame(width: 44, height: 44)
                        Image(systemName: "book")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Color.bhVert)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Livret d'accueil")
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                                Text("\(filled) bloc\(filled == 1 ? "" : "s") sur 3 rempli\(filled == 1 ? "" : "s")")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer()
                            Button { openWelcomeBook() } label: {
                                Text("Voir")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.bhVert)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .glassEffect(in: .rect(cornerRadius: 12))
                                    .specularEdge(cornerRadius: 12)
                            }
                            .buttonStyle(.plain)
                        }

                        // Barre de progression 5px
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(Color.white.opacity(0.4))
                                if filled > 0 {
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(Color.bhOccupe)
                                        .frame(width: geo.size.width * CGFloat(filled) / 3.0)
                                }
                            }
                        }
                        .frame(height: 5)

                        Text("Il se remplit à partir des blocs Accès, Le quartier et Équipements & règles. Rien à ressaisir.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private var livretFilled: Int {
        var n = 0
        if property.accessCode?.isEmpty == false || property.wifiName?.isEmpty == false
            || property.accessInstructions?.isEmpty == false { n += 1 }
        if property.practicalInfo?.hasAny == true { n += 1 }
        if property.amenities?.hasAny == true { n += 1 }
        return n
    }

    private func openWelcomeBook() {
        guard let urlStr = property.welcomeBookUrl, !urlStr.isEmpty,
              let url = URL(string: urlStr) else { return }
        openURL(url)
    }

    // MARK: - Les 9 blocs

    private var blocksCard: some View {
        ListCard {
            VStack(spacing: 0) {
                blockRow(icon: "person.text.rectangle", title: "Identité",
                         summary: identiteSummary, status: identiteStatus,
                         showSeparator: true, action: { activeBlock = .identite })
                blockRow(icon: "clock", title: "Séjour",
                         summary: sejourSummary, status: sejourStatus,
                         showSeparator: true, action: { activeBlock = .sejour })
                blockRow(icon: "eurosign.circle", title: "Argent",
                         summary: argentSummary, status: argentStatus,
                         showSeparator: true, action: { activeBlock = .argent })
                blockRow(icon: "gift", title: "Prestations payantes",
                         summary: prestationsSummary, status: prestationsStatus,
                         showSeparator: true, action: { activeBlock = .prestations })
                blockRow(icon: "key.fill", title: "Accès",
                         summary: accesSummary, status: accesStatus, isLivret: true,
                         showSeparator: true, action: { activeBlock = .acces })
                blockRow(icon: "map", title: "Le quartier",
                         summary: quartierSummary, status: quartierStatus, isLivret: true,
                         showSeparator: true, action: { activeBlock = .quartier })
                blockRow(icon: "list.bullet", title: "Équipements & règles",
                         summary: equipSummary, status: equipStatus, isLivret: true,
                         showSeparator: true, action: { activeBlock = .equipements })
                blockRow(icon: "sparkles", title: "Assistant IA",
                         summary: iaSummary, status: iaStatus,
                         showSeparator: true, action: { activeBlock = .ia })
                blockRow(icon: "antenna.radiowaves.left.and.right", title: "Plateformes & prix",
                         summary: plateformesSummary, status: plateformesStatus,
                         showSeparator: false, action: { activeBlock = .plateformes })
            }
        }
    }

    // MARK: - Block row

    private enum BlockStatus { case complete, toFill, inactive }

    private func blockRow(icon: String, title: String, summary: String,
                          status: BlockStatus, isLivret: Bool = false,
                          showSeparator: Bool, action: (() -> Void)? = nil) -> some View {
        CardRow(showSeparator: showSeparator) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.bhMentheFond)
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        if isLivret {
                            Text("LIVRET")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(Color.bhOccupeFonce)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Color.bhMentheFond,
                                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                                )
                        }
                    }
                    Text(summary)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 4)

                blockStatusView(status)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
            .contentShape(Rectangle())
            .onTapGesture { action?() }
        }
    }

    @ViewBuilder
    private func blockStatusView(_ status: BlockStatus) -> some View {
        switch status {
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color.bhOccupe)
        case .toFill:
            StatusPill(text: "à remplir", style: .or)
        case .inactive:
            StatusPill(text: "inactif", style: .neutre)
        }
    }

    // MARK: - Block summaries & statuses

    private var identiteSummary: String {
        property.address.flatMap { $0.isEmpty ? nil : $0 } ?? "—"
    }
    private var identiteStatus: BlockStatus {
        property.address?.isEmpty == false ? .complete : .toFill
    }

    private var sejourSummary: String {
        var parts: [String] = []
        if let a = Formatters.time(property.arrivalTime),
           let d = Formatters.time(property.departureTime) {
            parts.append("\(a) → \(d)")
        }
        if let g = property.maxGuests { parts.append("\(g) pers.") }
        if let n = property.minNights, n > 0 { parts.append("\(n) nuit\(n == 1 ? "" : "s") min") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    private var sejourStatus: BlockStatus {
        property.arrivalTime != nil || property.maxGuests != nil ? .complete : .toFill
    }

    private var argentSummary: String {
        guard let base = property.basePrice, base > 0 else { return "—" }
        var parts = [Formatters.amount(base)]
        if let fee = property.cleaningFee, fee > 0 { parts.append("ménage \(Formatters.amount(fee))") }
        if let tax = property.touristTax,  tax > 0 { parts.append("taxe \(Formatters.amount(tax)) p.nuit") }
        return parts.joined(separator: " · ")
    }
    private var argentStatus: BlockStatus {
        (property.basePrice ?? 0) > 0 ? .complete : .toFill
    }

    private var prestationsSummary: String {
        var parts: [String] = []
        if property.lateCheckoutEnabled  == true { parts.append("départ tardif") }
        if property.earlyCheckinEnabled  == true { parts.append("arrivée anticipée") }
        if property.welcomeBasketEnabled == true { parts.append("panier") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    private var prestationsStatus: BlockStatus {
        let flags = [property.lateCheckoutEnabled, property.earlyCheckinEnabled,
                     property.welcomeBasketEnabled]
        if flags.contains(true)              { return .complete }
        if flags.allSatisfy({ $0 == false }) { return .inactive }
        return .toFill
    }

    private var accesSummary: String {
        var parts: [String] = []
        if let c = property.accessCode, !c.isEmpty { parts.append("code \(c)") }
        if let w = property.wifiName,  !w.isEmpty  { parts.append("wifi \(w)") }
        if parts.isEmpty, let i = property.accessInstructions, !i.isEmpty {
            parts.append(String(i.prefix(40)))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    private var accesStatus: BlockStatus {
        let p = property
        return (p.accessCode?.isEmpty == false || p.wifiName?.isEmpty == false
                || p.accessInstructions?.isEmpty == false) ? .complete : .toFill
    }

    private var quartierSummary: String { property.practicalInfo?.summary ?? "—" }
    private var quartierStatus: BlockStatus {
        property.practicalInfo?.hasAny == true ? .complete : .toFill
    }

    private var equipSummary: String { property.amenities?.summary ?? "—" }
    private var equipStatus: BlockStatus {
        property.amenities?.hasAny == true ? .complete : .toFill
    }

    private var iaSummary: String {
        var parts: [String] = []
        switch property.autoResponsesEnabled {
        case .some(true):  parts.append("actif")
        case .some(false): parts.append("inactif")
        case .none:        break
        }
        if let n = property.customAutoResponses?.count, n > 0 {
            parts.append("\(n) Q&R")
        }
        if let n = property.quickReplies?.count, n > 0 {
            parts.append("\(n) raccourci\(n == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    private var iaStatus: BlockStatus {
        switch property.autoResponsesEnabled {
        case .some(true):  return .complete
        case .some(false): return .inactive
        case .none:        return .toFill
        }
    }

    private var plateformesSummary: String {
        var parts: [String] = []
        if property.channexEnabled == true {
            if channelsLoaded {
                let n = connectedChannels.count
                if n > 0 {
                    parts.append("diffusé sur \(n) plateforme\(n > 1 ? "s" : "")")
                } else {
                    parts.append("connecté · aucune diffusion")
                }
            } else {
                // loading in progress — avoid transient "aucune diffusion"
                parts.append("connecté")
            }
        }
        let icalCount = property.icalUrls?.count ?? 0
        if icalCount > 0 { parts.append("\(icalCount) iCal") }
        return parts.isEmpty ? "non connecté" : parts.joined(separator: " · ")
    }
    private var plateformesStatus: BlockStatus {
        let hasIcal = (property.icalUrls?.count ?? 0) > 0
        if hasIcal { return .complete }
        guard property.channexEnabled == true else { return .toFill }
        // loading: on sait que c'est connecté, pas encore combien de canaux
        if !channelsLoaded { return .complete }
        return connectedChannels.isEmpty ? .toFill : .complete
    }

    // MARK: - Actions secondaires (bas de fiche)

    private var duplicateButton: some View {
        Button { showDuplicateSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                Text("Dupliquer ce logement")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.30))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.40), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var channexActionButton: some View {
        if property.channexEnabled == true {
            Button {
                showDisconnectAlert = true
            } label: {
                HStack(spacing: 8) {
                    if isDisconnecting {
                        ProgressView()
                            .tint(Color.bhTerracotta)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 14))
                    }
                    Text(isDisconnecting ? "Déconnexion…" : "Déconnecter la diffusion")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.bhTerracotta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.40), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisconnecting)
        } else {
            Button { showConnectSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14))
                    Text("Connecter à la diffusion")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.40), lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section Diffusion (comptes principaux uniquement)

    @ViewBuilder
    private var diffusionSection: some View {
        if authStore.session?.isSubAccount != true {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Diffusion")

                channelsCard

                Button {
                    showDiffusionSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                        Text("Gérer la diffusion")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Color.bhVert)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.bhMentheFond)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.bhVert.opacity(0.22), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)

                if showSyncPrompt {
                    syncCard
                }
            }
        }
    }

    private var channelsCard: some View {
        ListCard {
            if !channelsLoaded {
                CardRow(showSeparator: false) {
                    HStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
                }
            } else if connectedChannels.isEmpty {
                CardRow(showSeparator: false) {
                    Text("Ce logement n'est diffusé sur aucune plateforme.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(Array(connectedChannels.enumerated()), id: \.element.id) { idx, ch in
                    CardRow(showSeparator: idx < connectedChannels.count - 1) {
                        channelRow(ch)
                    }
                }
            }
        }
    }

    private func channelRow(_ channel: ConnectedChannel) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.platform(channel.channel))
                .frame(width: 8, height: 8)
            Text(channel.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhEncre)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(Color.bhOccupe)
        }
    }

    @ViewBuilder
    private var syncCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                if let result = syncDiffusionResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Synchronisation terminée")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        Text(result)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bhAttenue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if isSyncingDiffusion {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Color.bhAttenue)
                            .scaleEffect(0.85)
                        Text(syncDiffusionStep)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                    }
                } else {
                    Button {
                        Task { await syncDiffusion() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                            Text("Synchroniser")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(Color.bhVert)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section Synchronisation par lien (tous comptes)

    private var icalSection: some View {
        PropertyICalSectionView(
            property: property,
            connectedChannels: connectedChannels
        ) {
            Task { await reloadProperty() }
        }
    }

    // MARK: - Async helpers

    private func reloadProperty() async {
        #if DEBUG
        do {
            let raw = try await APIClient.shared.getData(Endpoint.property(property.id), agencyAll: true)
            print("[reloadProperty] raw: \(String(data: raw, encoding: .utf8) ?? "(non-UTF8)")")
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            let updated = try dec.decode(Property.self, from: raw)
            print("[reloadProperty] channexEnabled = \(String(describing: updated.channexEnabled))")
            property = updated
            vm.updateProperty(updated)
        } catch {
            print("[reloadProperty] erreur: \(error)")
        }
        #else
        if let updated: Property = try? await APIClient.shared.get(Endpoint.property(property.id), agencyAll: true) {
            property = updated
            vm.updateProperty(updated)
        }
        #endif
    }

    private func disconnect() async {
        isDisconnecting = true
        defer { isDisconnecting = false }
        struct DisconnectBody: Encodable {
            let propertyId: String
            private enum CodingKeys: String, CodingKey { case propertyId = "property_id" }
        }
        do {
            #if DEBUG
            print("[disconnect] POST \(Endpoint.channexDisconnect.absoluteString)?agency=all  property_id=\(property.id)")
            #endif
            // postData logs URL + corps + statut + réponse brute en DEBUG
            _ = try await APIClient.shared.postData(Endpoint.channexDisconnect, body: DisconnectBody(propertyId: property.id), agencyAll: true)
            #if DEBUG
            print("[disconnect] POST OK")
            #endif
            await reloadProperty()
            await loadConnectedChannels()
        } catch let err as APIError {
            #if DEBUG
            print("[disconnect] erreur APIError: \(err)")
            #endif
            actionError = err.userMessage
        } catch {
            #if DEBUG
            print("[disconnect] erreur: \(error)")
            #endif
            actionError = error.localizedDescription
        }
    }

    private func syncProperty() async {
        isSyncing = true
        defer { isSyncing = false }

        async let icalTask: SyncIcalResponse = APIClient.shared.post(Endpoint.syncIcal, agencyAll: true, timeout: 120)
        async let diffDataTask: Data         = APIClient.shared.postData(Endpoint.syncDiffusion, agencyAll: true)

        let ical     = try? await icalTask
        let diffData = try? await diffDataTask

        #if DEBUG
        if let d = diffData {
            print("[sync-all] \(String(data: d, encoding: .utf8) ?? "(non-UTF8)")")
        } else {
            print("[sync-all] échec — pas de réponse")
        }
        #endif

        Task { await reloadProperty() }

        switch (ical != nil, diffData != nil) {
        case (true, true):   syncResult = "Synchronisation lancée."
        case (false, true):  syncResult = "Diffusion synchronisée — calendriers iCal non atteints."
        case (true, false):  syncResult = "Calendriers iCal synchronisés — diffusion non atteinte."
        case (false, false): syncResult = "Synchronisation échouée."
        }
    }

    private func deleteProperty() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await APIClient.shared.delete(Endpoint.property(property.id), agencyAll: true)
            vm.removeProperty(id: property.id)
            dismiss()
        } catch let err as APIError {
            actionError = err.userMessage
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadConnectedChannels() async {
        guard authStore.session?.isSubAccount != true else { return }
        channelsLoaded = false
        do {
            let resp: ConnectedChannelsResponse = try await APIClient.shared.get(
                Endpoint.channexConnectedChannels(property.id), agencyAll: true
            )
            connectedChannels = resp.channels
        } catch {
            connectedChannels = []
        }
        channelsLoaded = true
    }

    private func syncDiffusion() async {
        guard !isSyncingDiffusion else { return }
        isSyncingDiffusion   = true
        syncDiffusionResult  = nil
        var parts: [String]  = []

        syncDiffusionStep = "Récupération des réservations…"
        do {
            _ = try await APIClient.shared.postData(
                Endpoint.channexPullBookings(property.id), agencyAll: true
            )
            parts.append("✓ Réservations récupérées")
        } catch {
            parts.append("✗ Récupération des réservations échouée")
        }

        // Délai imposé par le serveur — sync-bookings appelé trop tôt importe une liste incomplète
        syncDiffusionStep = "Attente de traitement…"
        try? await Task.sleep(for: .seconds(8))

        syncDiffusionStep = "Synchronisation des réservations…"
        do {
            _ = try await APIClient.shared.postData(
                Endpoint.channexSyncBookings(property.id), agencyAll: true
            )
            parts.append("✓ Réservations synchronisées")
        } catch {
            parts.append("✗ Synchronisation des réservations échouée")
        }

        syncDiffusionStep = "Envoi des disponibilités…"
        do {
            _ = try await APIClient.shared.postData(
                Endpoint.channexPushAvailability(property.id), agencyAll: true
            )
            parts.append("✓ Disponibilités envoyées")
        } catch {
            parts.append("✗ Envoi des disponibilités échoué")
        }

        isSyncingDiffusion  = false
        syncDiffusionStep   = ""
        syncDiffusionResult = parts.joined(separator: "\n")
    }
}
