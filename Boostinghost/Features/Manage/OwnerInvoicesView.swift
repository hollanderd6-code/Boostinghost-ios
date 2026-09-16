import SwiftUI

struct OwnerInvoicesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = OwnerInvoicesViewModel()

    @State private var listAlert: ListAlert? = nil

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
        .alert(listAlertTitle, isPresented: Binding(
            get: { listAlert != nil },
            set: { if !$0 { listAlert = nil } }
        ), actions: {
            Button("Annuler", role: .cancel) {}
            if let action = listAlert {
                switch action {
                case .finalize(let inv):
                    Button("Valider") { Task { await vm.finalize(invoiceId: inv.id) } }
                case .sendFromDraft(let inv):
                    Button("Envoyer") { Task { await vm.send(invoiceId: inv.id) } }
                case .sendFromInvoiced(let inv):
                    Button("Envoyer") { Task { await vm.send(invoiceId: inv.id) } }
                case .delete(let inv):
                    Button("Supprimer", role: .destructive) { Task { await vm.delete(invoiceId: inv.id) } }
                }
            }
        }, message: {
            Text(listAlertMessage)
        })
        .alert("Erreur", isPresented: Binding(
            get: { vm.actionError != nil },
            set: { if !$0 { vm.actionError = nil } }
        )) {
            Button("OK") { vm.actionError = nil }
        } message: {
            Text(vm.actionError ?? "")
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
                Text("Factures propriétaires")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer(minLength: 12)
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
                ForEach(OwnerInvoiceFilter.allCases, id: \.self) { f in
                    Button { vm.filter = f } label: {
                        HStack(spacing: 5) {
                            Text(f.label)
                                .font(.system(size: 14.5, weight: vm.filter == f ? .semibold : .regular))
                                .foregroundStyle(vm.filter == f ? Color.white : Color.bhAttenue)
                            let n = vm.count(for: f)
                            if n > 0 && f != .all {
                                Text("\(n)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(vm.filter == f ? Color.white.opacity(0.8) : Color.bhAttenue)
                            }
                        }
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
            .padding(.vertical, 12)
        }
        .contentMargins(.horizontal, 18, for: .scrollContent)
    }

    // MARK: - Contenu

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
                if vm.filteredInvoices.isEmpty {
                    emptyView
                } else {
                    invoicesCard
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .refreshable { await vm.reload() }
    }

    // MARK: - Carte de liste

    private var invoicesCard: some View {
        ListCard {
            ForEach(Array(vm.filteredInvoices.enumerated()), id: \.element.id) { idx, invoice in
                CardRow(showSeparator: idx < vm.filteredInvoices.count - 1) {
                    NavigationLink {
                        OwnerInvoiceDetailView(invoiceId: invoice.id) {
                            Task { await vm.reload() }
                        }
                    } label: {
                        invoiceRow(invoice)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenuItems(for: invoice) }
                }
            }
        }
    }

    private func invoiceRow(_ invoice: OwnerInvoice) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(invoice.invoiceNumber ?? "Brouillon")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(invoice.invoiceNumber == nil ? Color.bhAttenue : Color.bhEncre)
                        .lineLimit(1)
                    if invoice.isCreditNote == true {
                        Text("avoir")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.bhOr)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                if let name = invoice.clientName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                StatusPill(text: invoice.statusLabel, style: invoice.statusPillStyle)
                HStack(spacing: 6) {
                    if let amount = invoice.totalTtc {
                        Text(Formatters.amount(amount))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                    }
                    if let date = invoice.issueDate {
                        Text(Formatters.day(date))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(minHeight: 44)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuItems(for invoice: OwnerInvoice) -> some View {
        if invoice.status == "draft" {
            Button("Valider la facture") {
                listAlert = .finalize(invoice)
            }
        }

        if invoice.status == "draft" || invoice.status == "invoiced" {
            Button("Envoyer") {
                listAlert = invoice.status == "draft"
                    ? .sendFromDraft(invoice)
                    : .sendFromInvoiced(invoice)
            }
        }

        if invoice.status == "invoiced" || invoice.status == "sent" {
            Button("Marquer payée") {
                Task { await vm.markPaid(invoiceId: invoice.id) }
            }
        }

        if invoice.status == "draft" {
            Button("Supprimer", role: .destructive) {
                listAlert = .delete(invoice)
            }
        }
    }

    // MARK: - Alertes de confirmation (liste)

    private enum ListAlert: Identifiable {
        case finalize(OwnerInvoice)
        case sendFromDraft(OwnerInvoice)
        case sendFromInvoiced(OwnerInvoice)
        case delete(OwnerInvoice)

        var id: String {
            switch self {
            case .finalize(let inv):        return "finalize-\(inv.id)"
            case .sendFromDraft(let inv):   return "sendDraft-\(inv.id)"
            case .sendFromInvoiced(let inv):return "sendInvoiced-\(inv.id)"
            case .delete(let inv):          return "delete-\(inv.id)"
            }
        }
    }

    private var listAlertTitle: String {
        switch listAlert {
        case .finalize:                    return "Valider cette facture ?"
        case .sendFromDraft, .sendFromInvoiced: return "Envoyer cette facture ?"
        case .delete:                      return "Supprimer ce brouillon ?"
        case nil:                          return ""
        }
    }

    private var listAlertMessage: String {
        switch listAlert {
        case .finalize:        return "Un numéro définitif sera attribué et la facture ne pourra plus être modifiée."
        case .sendFromDraft:   return "La facture sera validée et envoyée au client par email."
        case .sendFromInvoiced:return "La facture sera envoyée au client par email."
        case .delete:          return "Cette action est définitive."
        case nil:              return ""
        }
    }

    // MARK: - États vide / erreur

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("Aucune facture")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text("Aucune facture \(emptyFilterLabel) pour le moment.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyFilterLabel: String {
        switch vm.filter {
        case .all:      return ""
        case .draft:    return "en brouillon"
        case .invoiced: return "finalisée"
        case .sent:     return "envoyée"
        case .paid:     return "payée"
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
