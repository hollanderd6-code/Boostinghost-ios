import SwiftUI

// MARK: - Section « Synchronisation par lien »

struct PropertyICalSectionView: View {
    let property: Property
    let connectedChannels: [ConnectedChannel]
    let onReload: () -> Void

    @State private var showAddSheet      = false
    @State private var editingEntry: ICalEntry? = nil
    @State private var deleteConfirm: ICalEntry? = nil
    @State private var isSyncing         = false
    @State private var syncMessage: String? = nil
    @State private var actionError: String? = nil

    private var icalUrls: [ICalEntry] { property.icalUrls ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Synchronisation par lien")

            coexistenceWarning

            fluxCard

            syncFooter

            addButton

            syncButton
        }
        .sheet(isPresented: $showAddSheet) {
            ICalFluxSheet(
                property: property,
                editing: nil,
                existingUrls: icalUrls,
                connectedChannels: connectedChannels,
                onDone: { onReload() }
            )
        }
        .sheet(item: $editingEntry) { entry in
            ICalFluxSheet(
                property: property,
                editing: entry,
                existingUrls: icalUrls,
                connectedChannels: connectedChannels,
                onDone: { onReload() }
            )
        }
        .alert("Supprimer ce lien ?", isPresented: Binding(
            get: { deleteConfirm != nil },
            set: { if !$0 { deleteConfirm = nil } }
        )) {
            Button("Supprimer", role: .destructive) {
                if let entry = deleteConfirm {
                    Task { await deleteEntry(entry) }
                }
            }
            Button("Annuler", role: .cancel) { deleteConfirm = nil }
        } message: {
            Text("Le lien « \(deleteConfirm?.platform ?? "") » sera retiré de ce logement.")
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
            get: { syncMessage != nil },
            set: { if !$0 { syncMessage = nil } }
        )) {
            Button("OK", role: .cancel) { syncMessage = nil }
        } message: {
            Text(syncMessage ?? "")
        }
    }

    // MARK: - Correspondance plateforme ↔ canal actif

    // Normalise : minuscules, supprime espaces / points / tirets / underscores.
    private static func normPlatform(_ s: String) -> String {
        s.lowercased().components(separatedBy: .init(charactersIn: " .-_")).joined()
    }

    // Heuristique conservative : retourne false en cas de doute.
    // Règle : égalité exacte normalisée, OU l'input est un préfixe du canal (≥ 5 chars).
    static func platformMatches(_ input: String, channel: ConnectedChannel) -> Bool {
        let n = normPlatform(input)
        guard n.count >= 4 else { return false }
        for ref in [normPlatform(channel.channel), normPlatform(channel.title)] {
            if n == ref { return true }
            if ref.hasPrefix(n) && n.count >= 5 { return true }
        }
        return false
    }

    // Vrai si au moins un flux iCal configuré correspond à un canal actif.
    private var hasRealOverlap: Bool {
        icalUrls.contains { entry in
            connectedChannels.contains { PropertyICalSectionView.platformMatches(entry.platform, channel: $0) }
        }
    }

    // MARK: - Bandeau coexistence

    @ViewBuilder
    private var coexistenceWarning: some View {
        if hasRealOverlap {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhOr)
                    .padding(.top, 1)
                Text("Ce logement est à la fois diffusé et synchronisé par lien. Une même réservation peut arriver par les deux chemins ; si les dates diffèrent d'un jour entre les sources, elle peut apparaître en double dans le calendrier.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhOr)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.bhOr.opacity(0.35), lineWidth: 1)
            }
        }
    }

    // MARK: - Carte des flux

    private var fluxCard: some View {
        ListCard {
            if icalUrls.isEmpty {
                CardRow(showSeparator: false) {
                    Text("Aucun lien configuré.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(Array(icalUrls.enumerated()), id: \.element.id) { idx, entry in
                    CardRow(showSeparator: idx < icalUrls.count - 1) {
                        fluxRow(entry)
                    }
                }
            }
        }
    }

    private func fluxRow(_ entry: ICalEntry) -> some View {
        let status = property.icalSyncStatus?[entry.url]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(entry.platform)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)

                Spacer(minLength: 4)

                syncStatusBadge(for: status)

                Menu {
                    Button {
                        editingEntry = entry
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteConfirm = entry
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            Text(entry.url)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.bhAttenue)
                .lineLimit(1)
                .truncationMode(.middle)

            if let status, status.ok == false, let err = status.error, !err.isEmpty {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.bhTerracotta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func syncStatusBadge(for status: ICalSyncInfo?) -> some View {
        if let status {
            if status.ok == true {
                let count = status.events ?? 0
                StatusPill(
                    text: "\(count) réservation\(count == 1 ? "" : "s")",
                    style: .vert
                )
            } else {
                StatusPill(text: "Erreur", style: .terracotta)
            }
        } else {
            Text("Jamais synchronisé")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
        }
    }

    // MARK: - Pied de synchronisation

    private var syncFooter: some View {
        Text(lastSyncLabel)
            .font(.system(size: 12.5))
            .foregroundStyle(Color.bhAttenue)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastSyncLabel: String {
        guard let iso = property.lastIcalSyncAt, !iso.isEmpty else {
            return "Jamais synchronisé"
        }
        if let rel = relativeTime(from: iso) {
            return "Dernière synchronisation \(rel)"
        }
        return "Dernière synchronisation inconnue"
    }

    // MARK: - Boutons

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                Text("Ajouter un lien")
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
    }

    private var syncButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await syncIcal() }
            } label: {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .tint(Color.bhAttenue)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                    }
                    Text(isSyncing ? "Synchronisation en cours…" : "Synchroniser maintenant")
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
            .disabled(isSyncing)

            Text("La synchronisation porte sur tous vos logements, pas seulement celui-ci. Le cron passe toutes les heures — vous n'avez pas à le déclencher manuellement.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.bhAttenue)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions réseau

    private func deleteEntry(_ entry: ICalEntry) async {
        let remaining = icalUrls.filter { $0.url != entry.url }
        struct Patch: Encodable { let icalUrls: [ICalEntry] }
        do {
            let resp: ICalPatchResponse = try await APIClient.shared.patch(
                Endpoint.property(property.id),
                body: Patch(icalUrls: remaining),
                agencyAll: true
            )
            onReload()
            if let warn = resp.avertissement {
                actionError = warn
            }
        } catch let err as APIError {
            actionError = err.userMessage
        } catch {
            actionError = error.localizedDescription
        }
        deleteConfirm = nil
    }

    private func syncIcal() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let resp: SyncIcalResponse = try await APIClient.shared.post(
                Endpoint.syncIcal, agencyAll: true, timeout: 120
            )
            onReload()
            syncMessage = resp.message ?? "Synchronisation lancée."
        } catch let err as APIError {
            actionError = err.userMessage
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Date relative

    private func relativeTime(from isoString: String) -> String? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: isoString)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: isoString)
        }
        guard let date else { return nil }

        let diff = Date().timeIntervalSince(date)
        if diff < 60    { return "il y a moins d'une minute" }
        if diff < 3600  {
            let m = Int(diff / 60)
            return "il y a \(m) minute\(m > 1 ? "s" : "")"
        }
        if diff < 86400 {
            let h = Int(diff / 3600)
            return "il y a \(h) heure\(h > 1 ? "s" : "")"
        }
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "fr_FR")
        dateFmt.dateFormat = "EEEE d MMMM"
        return "le \(dateFmt.string(from: date).lowercased())"
    }
}
