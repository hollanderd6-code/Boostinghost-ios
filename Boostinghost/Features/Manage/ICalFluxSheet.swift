import SwiftUI

// MARK: - Feuille d'ajout / modification d'un lien iCal

struct ICalFluxSheet: View {
    @Environment(\.dismiss) private var dismiss

    let property: Property
    let editing: ICalEntry?          // nil = ajout, non-nil = édition
    let existingUrls: [ICalEntry]
    let connectedChannels: [ConnectedChannel]
    let onDone: () -> Void

    @State private var platform  = ""
    @State private var urlStr    = ""
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Bandeau Or : uniquement si la plateforme saisie est déjà diffusée
                        if showCoexistenceWarning {
                            coexistenceWarning
                        }

                        // Formulaire
                        ListCard {
                            CardRow(showSeparator: true) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Plateforme")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.bhAttenue)
                                    TextField("Airbnb, Booking.com, Abritel…", text: $platform)
                                        .font(.system(size: 15.5))
                                        .foregroundStyle(Color.bhEncre)
                                        .autocorrectionDisabled()
                                }
                            }
                            CardRow(showSeparator: false) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("URL du lien")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.bhAttenue)
                                    TextField("https://…", text: $urlStr)
                                        .font(.system(size: 15.5))
                                        .foregroundStyle(Color.bhEncre)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                }
                            }
                        }

                        // Erreur (validation locale ou réseau) — saisie conservée
                        if let err = saveError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhTerracotta)
                                    .padding(.top, 1)
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.bhTerracotta)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.bhTerracottaFond,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.bhTerracotta.opacity(0.3), lineWidth: 1)
                            }
                        }

                        // Bouton Enregistrer
                        Button {
                            Task { await save() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white).scaleEffect(0.85)
                                }
                                Text(isSaving ? "Enregistrement…" : "Enregistrer")
                                    .font(.system(size: 16.5, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Color.bhVert,
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Modifier le lien" : "Ajouter un lien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Color.bhVert)
                        .disabled(isSaving)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if let e = editing {
                platform = e.platform
                urlStr   = e.url
            }
        }
    }

    // MARK: - Correspondance plateforme ↔ canal actif (même logique que PropertyICalSectionView)

    private static func normPlatform(_ s: String) -> String {
        s.lowercased().components(separatedBy: .init(charactersIn: " .-_")).joined()
    }

    private static func platformMatches(_ input: String, channel: ConnectedChannel) -> Bool {
        let n = normPlatform(input)
        guard n.count >= 4 else { return false }
        for ref in [normPlatform(channel.channel), normPlatform(channel.title)] {
            if n == ref { return true }
            if ref.hasPrefix(n) && n.count >= 5 { return true }
        }
        return false
    }

    // Réactif à la saisie : vrai dès que la plateforme tapée correspond à un canal actif.
    private var showCoexistenceWarning: Bool {
        let trimmed = platform.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return connectedChannels.contains { ICalFluxSheet.platformMatches(trimmed, channel: $0) }
    }

    // MARK: - Bandeau coexistence

    private var coexistenceWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.bhOr)
                .padding(.top, 1)
            Text("Cette plateforme est déjà diffusée sur ce logement. En ajoutant ce lien, les mêmes réservations peuvent arriver deux fois — une fois par la diffusion, une fois par le calendrier importé.")
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

    // MARK: - Sauvegarde

    private func save() async {
        saveError = nil

        let trimPlatform = platform.trimmingCharacters(in: .whitespaces)
        let trimUrl      = urlStr.trimmingCharacters(in: .whitespaces)

        guard !trimPlatform.isEmpty else {
            saveError = "Veuillez saisir le nom de la plateforme."
            return
        }
        guard !trimUrl.isEmpty else {
            saveError = "Veuillez saisir l'URL du lien."
            return
        }
        guard URL(string: trimUrl) != nil,
              trimUrl.lowercased().hasPrefix("http://") || trimUrl.lowercased().hasPrefix("https://") else {
            saveError = "L'URL doit être valide et commencer par http:// ou https://."
            return
        }

        // Éviter les doublons d'URL (hors modification de la même entrée)
        let isDuplicate = existingUrls.contains { $0.url == trimUrl && $0.url != editing?.url }
        if isDuplicate {
            saveError = "Cette URL est déjà configurée pour ce logement."
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Construire la liste complète — le tableau REMPLACE entièrement l'existant côté serveur
        var newList = existingUrls.filter { isEditing ? $0.url != editing!.url : true }
        newList.append(ICalEntry(url: trimUrl, platform: trimPlatform))

        struct Patch: Encodable { let icalUrls: [ICalEntry] }
        do {
            let _: ICalPatchResponse = try await APIClient.shared.patch(
                Endpoint.property(property.id),
                body: Patch(icalUrls: newList),
                agencyAll: true
            )
            // Tout succès (200) — y compris si le serveur joint un avertissement — ferme la feuille.
            // Le bandeau Or de la section iCal s'affiche automatiquement après rechargement
            // si le logement est à la fois diffusé et synchronisé par lien.
            onDone()
            NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
            dismiss()
        } catch let err as APIError {
            saveError = err.userMessage
        } catch {
            saveError = error.localizedDescription
        }
    }
}
