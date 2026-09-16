import SwiftUI

// MARK: - Corps JSON de création (duplication)
// "JSON suffit sans photo" — spec.
// Ne copie PAS : accessCode (PIN), icalUrls (iCal), channexEnabled (diffusion).

private struct PropertyDuplicateBody: Encodable {
    let name: String
    let internalName: String
    let color: String?
    let address: String?
    let maxGuests: Int?
    let bedrooms: Int?
    let beds: Int?
    let bathrooms: Int?
    let arrivalTime: String?
    let departureTime: String?
    let minNights: Int?
    let basePrice: Double?
    let weekendPrice: Double?
    let cleaningFee: Double?
    let touristTaxPerNight: Double?
    let depositAmount: Double?
    let depositReleaseDays: Int?
    let conciergePct: Double?
    let airbnbCommissionPct: Double?
    let bookingCommissionPct: Double?
    let accessInstructions: String?
    let wifiName: String?
    let wifiPassword: String?
    let ownerId: String?
    let autoResponsesEnabled: Bool?
    let arrivalMessage: String?
    let lateCheckoutEnabled: Bool?
    let lateCheckoutToleranceMinutes: Int?
    let lateCheckoutPricePerHour: Double?
    let lateCheckoutMaxMinutes: Int?
    let earlyCheckinEnabled: Bool?
    let earlyCheckinToleranceMinutes: Int?
    let earlyCheckinPricePerHour: Double?
    let earlyCheckinMaxMinutes: Int?
    let welcomeBasketEnabled: Bool?
    let welcomeBasketPrice: Double?
    let welcomeBasketDescription: String?
    let externalPricing: Bool?

    init(source: Property, internalName: String, publicName: String) {
        name                         = publicName
        self.internalName            = internalName
        color                        = source.color
        address                      = source.address
        maxGuests                    = source.maxGuests
        bedrooms                     = source.bedrooms
        beds                         = source.beds
        bathrooms                    = source.bathrooms
        arrivalTime                  = source.arrivalTime
        departureTime                = source.departureTime
        minNights                    = source.minNights
        basePrice                    = source.basePrice
        weekendPrice                 = source.weekendPrice
        cleaningFee                  = source.cleaningFee
        touristTaxPerNight           = source.touristTax
        depositAmount                = source.depositAmount
        depositReleaseDays           = source.depositReleaseDays
        conciergePct                 = source.conciergePct
        airbnbCommissionPct          = source.airbnbCommissionPct
        bookingCommissionPct         = source.bookingCommissionPct
        accessInstructions           = source.accessInstructions
        wifiName                     = source.wifiName
        wifiPassword                 = source.wifiPassword
        ownerId                      = source.ownerId?.isEmpty == false ? source.ownerId : nil
        autoResponsesEnabled         = source.autoResponsesEnabled
        arrivalMessage               = source.arrivalMessage
        lateCheckoutEnabled          = source.lateCheckoutEnabled
        lateCheckoutToleranceMinutes = source.lateCheckoutToleranceMinutes
        lateCheckoutPricePerHour     = source.lateCheckoutPricePerHour
        lateCheckoutMaxMinutes       = source.lateCheckoutMaxMinutes
        earlyCheckinEnabled          = source.earlyCheckinEnabled
        earlyCheckinToleranceMinutes = source.earlyCheckinToleranceMinutes
        earlyCheckinPricePerHour     = source.earlyCheckinPricePerHour
        earlyCheckinMaxMinutes       = source.earlyCheckinMaxMinutes
        welcomeBasketEnabled         = source.welcomeBasketEnabled
        welcomeBasketPrice           = source.welcomeBasketPrice
        welcomeBasketDescription     = source.welcomeBasketDescription
        externalPricing              = source.externalPricing
    }
}

// MARK: - Feuille de duplication

struct DuplicatePropertySheet: View {
    @Environment(\.dismiss) private var dismiss

    let source: Property
    let onSuccess: () -> Void

    @State private var internalName: String
    @State private var publicName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var created = false

    init(source: Property, onSuccess: @escaping () -> Void) {
        self.source    = source
        self.onSuccess = onSuccess
        _internalName  = State(initialValue: (source.internalName ?? source.name) + " (copie)")
    }

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
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                VStack(spacing: 1) {
                    Text("Dupliquer")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text(source.internalName ?? source.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 96)
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

    // MARK: - Sections

    private var formSection: some View {
        VStack(spacing: 16) {
            fieldsCard
            infoCard
            if let err = errorMessage {
                errorCard(message: err)
            }
            createButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

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
                            Text(internalName)
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
                        Text("Ce logement n'est pas encore diffusé. Connectez-le à la diffusion depuis sa nouvelle fiche.")
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
                    .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Cards

    private var fieldsCard: some View {
        ListCard {
            VStack(spacing: 0) {
                CardRow(showSeparator: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nom interne")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhAttenue)
                        TextField("Nom interne", text: $internalName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                    }
                }
                CardRow(showSeparator: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text("Nom public")
                                .font(.system(size: 12.5))
                                .foregroundStyle(Color.bhAttenue)
                            Text("obligatoire")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(Color.bhOr)
                        }
                        TextField("À saisir", text: $publicName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.bhEncre)
                    }
                }
            }
        }
    }

    private var infoCard: some View {
        ListCard {
            CardRow(showSeparator: false) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .padding(.top, 1)
                    Text("Les URLs de calendrier, identifiants de diffusion et code PIN ne sont pas copiés.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
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
        let trimmed = publicName.trimmingCharacters(in: .whitespaces)
        let enabled = !trimmed.isEmpty && !isCreating
        return Button {
            Task { await create() }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView().tint(.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "doc.on.doc").font(.system(size: 14))
                }
                Text(isCreating ? "Création…" : "Créer le duplicata")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color.bhVert.opacity(enabled ? 1 : 0.45),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Action

    private func create() async {
        let trimmed = publicName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        let body = PropertyDuplicateBody(source: source, internalName: internalName, publicName: trimmed)
        do {
            // Succès si le serveur répond 2xx, quel que soit le format de réponse.
            try await APIClient.shared.postVoid(Endpoint.properties, body: body, agencyAll: true)
            onSuccess()
            created = true
        } catch let err as APIError {
            if case .server(409, let msg) = err {
                errorMessage = msg ?? "Un logement portant un identifiant similaire existe déjà. Modifiez le nom public."
            } else {
                errorMessage = err.userMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
