import SwiftUI

// MARK: - Corps de connexion

private struct ChannexConnectBody: Encodable {
    let propertyId: String

    private enum CodingKeys: String, CodingKey {
        case propertyId = "property_id"
    }
}


// MARK: - Feuille de connexion à la diffusion

struct PropertyChannexSheet: View {
    @Environment(\.dismiss) private var dismiss

    let property: Property
    let onConnected: () -> Void

    @State private var isConnecting  = false
    @State private var failedMessage: String? = nil

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if missingBasePrice {
                            basePriceWarningCard
                        }
                        if let msg = failedMessage {
                            failedCard(message: msg)
                        }
                        connectButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .interactiveDismissDisabled(isConnecting)
    }

    private var missingBasePrice: Bool { (property.basePrice ?? 0) == 0 }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                VStack(spacing: 1) {
                    Text("Connecter à la diffusion")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text(property.internalName ?? property.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 96)
                HStack {
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.bhAttenue)
                        .disabled(isConnecting)
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

    // MARK: - Cards

    private var basePriceWarningCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhOr)
                        .padding(.top, 1)
                    Text("Ce logement n'a pas de tarif de base. La fiche sera créée chez le prestataire de diffusion mais restera fermée à la vente. Renseignez le bloc Argent avant de connecter.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhOr)
                }
            }
        }
    }

    private func failedCard(message: String) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhTerracotta)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.bhTerracotta)
                        Text("Une fiche partielle a peut-être été créée chez le prestataire de diffusion. Vérifiez-y avant de retenter la connexion pour éviter les doublons.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    private var connectButton: some View {
        Button {
            Task { await connect() }
        } label: {
            HStack(spacing: 8) {
                if isConnecting {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14))
                }
                Text(isConnecting ? "Connexion en cours…" : "Connecter à la diffusion")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.bhVert.opacity(isConnecting ? 0.45 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
    }

    // MARK: - Action

    private func connect() async {
        // Print inconditionnelle en première ligne — prouve que la fonction est appelée.
        print("[channex-connect] ▶ connect() appelé — property: \(property.id)")
        isConnecting = true
        failedMessage = nil
        let body = ChannexConnectBody(propertyId: property.id)

        #if DEBUG
        print("[channex-connect] → POST \(Endpoint.channexConnect)?agency=all")
        if let encoded = try? JSONEncoder().encode(body) {
            print("[channex-connect] → body: \(String(data: encoded, encoding: .utf8) ?? "(err)")")
        }
        #endif

        do {
            let responseData = try await APIClient.shared.postData(Endpoint.channexConnect, body: body, agencyAll: true)
            #if DEBUG
            print("[channex-connect] ← 2xx: \(String(data: responseData, encoding: .utf8) ?? "(non-UTF8)")")
            #endif
            isConnecting = false
            onConnected()
            dismiss()
        } catch let err as APIError {
            #if DEBUG
            print("[channex-connect] ← APIError: \(err)")
            #endif
            isConnecting = false
            failedMessage = err.userMessage
        } catch {
            #if DEBUG
            print("[channex-connect] ← erreur: \(error)")
            #endif
            isConnecting = false
            failedMessage = error.localizedDescription
        }
    }
}
