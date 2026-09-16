import SwiftUI
import QuickLook

struct ContractsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = ContractsViewModel()
    @State private var pdfURL: URL?           = nil
    @State private var actionAlert: String?   = nil
    @State private var pendingDelete: Contract? = nil
    // TODO: remplacer par le bouton "Créer un mandat" de la fiche propriétaire
    // quand cet écran sera livré (point d'entrée temporaire).
    @State private var showNewMandat = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                filterBar
                scrollContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.reload() }
        .quickLookPreview($pdfURL)
        .sheet(isPresented: $showNewMandat) {
            ClientPickerSheet {
                showNewMandat = false
                Task { await vm.reload() }
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { actionAlert != nil },
            set: { if !$0 { actionAlert = nil } }
        )) {
            Button("OK") { actionAlert = nil }
        } message: {
            Text(actionAlert ?? "")
        }
        .confirmationDialog(
            "Supprimer ce contrat ?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let contract = pendingDelete {
                    pendingDelete = nil
                    Task {
                        do {
                            try await vm.delete(contract)
                        } catch {
                            actionAlert = (error as? APIError)?.userMessage
                                ?? "Impossible de supprimer ce contrat."
                        }
                    }
                }
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Cette action est définitive. Le contrat et son PDF seront supprimés.")
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
                Text(vm.superTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Contrats")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)

            Button { showNewMandat = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)
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

    // MARK: - Filtre

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ContractFilter.allCases, id: \.self) { f in
                    Button { vm.filter = f } label: {
                        Text(f.label)
                            .font(.system(size: 14.5, weight: vm.filter == f ? .semibold : .regular))
                            .foregroundStyle(vm.filter == f ? Color.white : Color.bhAttenue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(vm.filter == f ? Color.bhVert : Color.white.opacity(0.30))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.18), value: vm.filter)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Contenu selon état

    @ViewBuilder
    private var scrollContent: some View {
        switch vm.loadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .error(let msg):
            errorView(msg)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if vm.contracts.isEmpty {
                    emptyView
                } else {
                    contractsCard
                }
                if vm.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView().tint(Color.bhAttenue)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.reload() }
    }

    // MARK: - Carte de liste

    private var contractsCard: some View {
        ListCard {
            ForEach(Array(vm.contracts.enumerated()), id: \.element.id) { idx, contract in
                CardRow(showSeparator: idx < vm.contracts.count - 1) {
                    NavigationLink {
                        ContractDetailView(contractId: contract.id) {
                            vm.removeLocally(id: contract.id)
                        }
                    } label: {
                        contractRow(contract)
                    }
                    .buttonStyle(.plain)
                }
                .onAppear {
                    if idx == vm.contracts.count - 1 {
                        Task { await vm.loadMore() }
                    }
                }
            }
        }
    }

    private func contractRow(_ contract: Contract) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                logoUrl:   nil,
                firstName: contract.signerFirstName,
                lastName:  contract.signerLastName,
                company:   nil,
                size:      42
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(contract.signerDisplayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                Text(contractSubtitle(contract))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.bhAttenue)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                StatusPill(text: pillText(contract), style: pillStyle(contract))
                let ds = dateString(contract)
                if !ds.isEmpty {
                    Text(ds)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }
        }
        .frame(minHeight: 44)
        .contextMenu {
            Button {
                Task {
                    pdfURL = await vm.downloadPdf(contract)
                }
            } label: {
                Label("Voir le PDF", systemImage: "doc.text")
            }
            if contract.status != "signed" {
                Button {
                    Task {
                        do {
                            try await vm.resend(contract)
                            await vm.reload()
                        } catch {
                            actionAlert = (error as? APIError)?.userMessage
                                ?? "Erreur lors du renvoi."
                        }
                    }
                } label: {
                    Label("Renvoyer le lien", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    pendingDelete = contract
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
    }

    private func contractSubtitle(_ c: Contract) -> String {
        var parts = [c.typeLabel]
        if let p = c.propertyName, !p.isEmpty { parts.append(p) }
        return parts.joined(separator: " · ")
    }

    private func pillText(_ c: Contract) -> String {
        switch c.status {
        case "sent":    return "en attente"
        case "signed":  return "signé"
        case "expired": return "expiré"
        default:        return c.status ?? "—"
        }
    }

    private func pillStyle(_ c: Contract) -> PillStyle {
        switch c.status {
        case "sent":    return .or
        case "signed":  return .vert
        case "expired": return .terracotta
        default:        return .neutre
        }
    }

    private func dateString(_ c: Contract) -> String {
        switch c.status {
        case "sent", "expired":
            if let d = c.createdAt  { return "envoyé le \(Formatters.day(d))" }
        case "signed":
            if let d = c.guestSignedAt { return "signé le \(Formatters.day(d))" }
        default: break
        }
        return ""
    }

    // MARK: - États vide / erreur

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("Aucun contrat")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text("Aucun contrat \(emptyFilterLabel) pour le moment.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyFilterLabel: String {
        switch vm.filter {
        case .sent:    return "en attente"
        case .signed:  return "signé"
        case .expired: return "expiré"
        }
    }

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
            Button("Réessayer") { Task { await vm.reload() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sélecteur de client (point d'entrée temporaire du mandat)
// TODO: remplacer par le bouton "Créer un mandat" de la fiche propriétaire.
// Filtre : is_agency_client exclus — un clientId "agency_client_*" est écrit
// null par le serveur, le mandat serait orphelin.

private struct ClientPickerSheet: View {
    let onMandatSent: () -> Void

    @State private var clients: [OwnerClient] = []
    @State private var isLoading = true
    @State private var errorMsg: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    sheetHeader
                    switch (isLoading, errorMsg) {
                    case (true, _):
                        Spacer()
                        ProgressView().tint(Color.bhAttenue)
                        Spacer()
                    case (_, let msg?):
                        errorView(msg)
                    default:
                        clientList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await loadClients() }
    }

    // MARK: En-tête feuille

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.bhAttenue.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 12)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nouveau mandat")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Choisir un propriétaire")
                        .bhGrandTitre()
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
        }
    }

    // MARK: Liste des clients (is_agency_client déjà exclus)

    private var clientList: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if clients.isEmpty {
                    Text("Aucun client disponible.")
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ListCard {
                        ForEach(Array(clients.enumerated()), id: \.element.id) { idx, client in
                            CardRow(showSeparator: idx < clients.count - 1) {
                                NavigationLink {
                                    MandatCreationView(client: client, onSuccess: onMandatSent)
                                } label: {
                                    clientRow(client)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await loadClients() }
    }

    private func clientRow(_ client: OwnerClient) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                logoUrl:   nil,
                firstName: client.firstName,
                lastName:  client.lastName,
                company:   client.companyName,
                size:      42
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                if let email = client.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.bhAttenue.opacity(0.55))
        }
        .frame(minHeight: 44)
    }

    // MARK: Chargement

    private func loadClients() async {
        isLoading = true
        errorMsg = nil
        do {
            let resp: OwnerClientsResponse = try await APIClient.shared.get(Endpoint.ownerClients)
            clients = resp.clients.filter { $0.isAgencyClient != true }
        } catch {
            errorMsg = (error as? APIError)?.userMessage ?? "Impossible de charger les clients."
        }
        isLoading = false
    }

    // MARK: Erreur

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
            Button("Réessayer") { Task { await loadClients() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
