import SwiftUI

// MARK: - Feuille de création d'un logement

struct NewPropertySheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSuccess: () -> Void

    @State private var publicName = ""
    @State private var internalName = ""
    @State private var selectedColor = Color(hex: "#2E8B62")
    @State private var selectedOwnerId: String? = nil

    @State private var clients: [OwnerClient] = []
    @State private var clientsLoaded = false
    @State private var isCreating = false
    @State private var showNameError = false
    @State private var errorMessage: String?
    @State private var created = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetHeader
                ScrollView(showsIndicators: false) {
                    if created {
                        successSection
                    } else {
                        formSection
                    }
                }
            }
        }
        .interactiveDismissDisabled(isCreating)
        .task { await loadClients() }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                Text("Nouveau logement")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                HStack {
                    Spacer()
                    Button(created ? "Fermer" : "Annuler") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.bhAttenue)
                        .disabled(isCreating)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Formulaire

    private var formSection: some View {
        VStack(spacing: 16) {
            namesCard
            colorCard
            ownerCard
            if let err = errorMessage {
                errorCard(message: err)
            }
            createButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    private var namesCard: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(showSeparator: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text("Nom public")
                                .font(.system(size: 12.5))
                                .foregroundStyle(showNameError ? Color.bhTerracotta : Color.bhAttenue)
                            Text("obligatoire")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.bhOr)
                        }
                        TextField("Nom visible par les voyageurs", text: $publicName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                            .onChange(of: publicName) { _, _ in showNameError = false }
                        if showNameError {
                            Text("Ce champ est obligatoire.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.bhTerracotta)
                        }
                    }
                }
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nom interne")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                        TextField("Optionnel — pour votre usage", text: $internalName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                    }
                }
            }
        }
    }

    private var colorCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text("Couleur")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.bhAttenue)
                            Text("obligatoire")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.bhOr)
                        }
                        Text("Point coloré dans le classement des revenus")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bhAttenue)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(selectedColor)
                        .frame(width: 4, height: 36)
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
        }
    }

    private var ownerCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                if !clientsLoaded {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Chargement…")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhAttenue)
                    }
                } else {
                    HStack {
                        Text("Propriétaire")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                        Spacer()
                        Picker("Propriétaire", selection: $selectedOwnerId) {
                            Text("Aucun").tag(String?.none)
                            ForEach(clients) { c in
                                Text(c.displayName).tag(Optional(c.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.bhEncre)
                    }
                }
            }
        }
    }

    private func errorCard(message: String) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhTerracotta)
                        .padding(.top, 1)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhTerracotta)
                }
            }
        }
    }

    private var createButton: some View {
        Button {
            let trimmed = publicName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                showNameError = true
                return
            }
            Task { await create() }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "plus").font(.system(size: 14))
                }
                Text(isCreating ? "Création…" : "Créer le logement")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.bhVert.opacity(isCreating ? 0.55 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }

    // MARK: - Succès

    private var successSection: some View {
        VStack(spacing: 16) {
            ListCard {
                CardRow(showSeparator: false) {
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.bhOccupe)
                        VStack(spacing: 4) {
                            Text("Logement créé")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.bhEncre)
                            let displayName = internalName.trimmingCharacters(in: .whitespaces)
                            Text(displayName.isEmpty
                                 ? publicName.trimmingCharacters(in: .whitespaces)
                                 : displayName)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.bhAttenue)
                            .padding(.top, 1)
                        Text("Ce logement n'est pas encore diffusé. Connectez-le à la diffusion depuis sa fiche.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
            Button { dismiss() } label: {
                Text("Fermer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.bhVert,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Données

    private func loadClients() async {
        guard !clientsLoaded else { return }
        if let r: OwnerClientsResponse = try? await APIClient.shared.get(Endpoint.ownerClients) {
            clients = r.clients
        }
        clientsLoaded = true
    }

    // MARK: - Création

    private func create() async {
        let trimmed = publicName.trimmingCharacters(in: .whitespaces)
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        var fields: [(String, String)] = [
            ("name",  trimmed),
            ("color", selectedColor.hexString),
        ]
        let intTrimmed = internalName.trimmingCharacters(in: .whitespaces)
        if !intTrimmed.isEmpty { fields.append(("internalName", intTrimmed)) }
        if let oid = selectedOwnerId, !oid.isEmpty { fields.append(("ownerId", oid)) }

        do {
            let _: PropertyCreateResponse = try await APIClient.shared.postMultipartWithFile(
                Endpoint.properties,
                fields: fields,
                agencyAll: true
            )
            onSuccess()
            created = true
        } catch let err as APIError {
            errorMessage = errorText(for: err)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func errorText(for err: APIError) -> String {
        switch err {
        case .server(403, _), .subscriptionRequired:
            return "Le plan Starter est limité à 3 logements. Passez au plan Pro pour créer des logements supplémentaires."
        case .server(402, _):
            return "La facturation du logement supplémentaire a échoué. Vérifiez votre moyen de paiement."
        case .server(409, let msg):
            return msg ?? "Un logement porte déjà ce nom, choisissez-en un autre."
        default:
            return err.userMessage
        }
    }
}
