import Foundation
import SwiftUI

// MARK: - ProfileViewModel
// Gère le chargement et la sauvegarde de GET/PUT /api/user/profile
// et le bascule PATCH /api/user/profile { use_bh_stripe }.

@Observable
@MainActor
final class ProfileViewModel {

    var profile:     UserProfile? = nil
    var isLoading    = false
    var isSaving     = false
    var saveError:   String? = nil

    // Champs du formulaire
    var firstName    = ""
    var lastName     = ""
    var company      = ""
    var accountType: AccountType = .individual
    var address      = ""
    var postalCode   = ""
    var city         = ""
    var siret        = ""
    var phone        = ""
    var invoiceEmail = ""
    var website      = ""
    var vatRegime    = ""
    var vatNumber    = ""
    var legalForm    = ""

    // Stripe — toggle immédiat (PATCH)
    var useBhStripe      = false
    var isTogglingStripe = false

    // Logo sélectionné depuis la bibliothèque
    var pendingLogoData:    Data?  = nil
    var pendingLogoMime:    String? = nil
    var pendingLogoPreview: Image? = nil

    // MARK: - Chargement

    func load(initial: UserProfile?) async {
        if let p = initial {
            populate(from: p)
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let p: UserProfile = try await APIClient.shared.get(Endpoint.userProfile)
            populate(from: p)
        } catch {
            saveError = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func populate(from p: UserProfile) {
        profile     = p
        firstName   = p.firstName    ?? ""
        lastName    = p.lastName     ?? ""
        company     = p.company      ?? ""
        accountType = p.accountType  ?? .individual
        address     = p.address      ?? ""
        postalCode  = p.postalCode   ?? ""
        city        = p.city         ?? ""
        siret       = p.siret        ?? ""
        phone       = p.phone        ?? ""
        invoiceEmail = p.invoiceEmail ?? ""
        website     = p.website      ?? ""
        vatRegime   = p.vatRegime    ?? ""
        vatNumber   = p.vatNumber    ?? ""
        legalForm   = p.legalForm    ?? ""
        useBhStripe = p.useBhStripe
    }

    // MARK: - Sauvegarde (PUT multipart)

    // Retourne le profil mis à jour si succès, nil sinon.
    func save() async -> UserProfile? {
        // Validation client avant envoi
        if accountType == .business {
            let digits = siret.filter(\.isNumber)
            if !digits.isEmpty && digits.count != 14 {
                saveError = "Le numéro SIRET doit contenir exactement 14 chiffres."
                return nil
            }
        }
        if let data = pendingLogoData, data.count > 10 * 1024 * 1024 {
            saveError = "Le logo ne doit pas dépasser 10 Mo."
            return nil
        }

        isSaving  = true
        saveError = nil
        defer { isSaving = false }

        // Les 4 champs sans COALESCE sont TOUJOURS inclus pour éviter l'effacement.
        let fields: [(String, String)] = [
            ("firstName",    firstName),
            ("lastName",     lastName),
            ("company",      company),
            ("accountType",  accountType.rawValue),
            ("phone",        phone),
            ("invoiceEmail", invoiceEmail),
            ("website",      website),
            ("vatRegime",    vatRegime),
            ("vatNumber",    vatNumber),
            ("legalForm",    legalForm),
            ("address",      address),
            ("postalCode",   postalCode),
            ("city",         city),
            ("siret",        siret),
        ]

        do {
            let resp: UpdateProfileResponse = try await APIClient.shared.putMultipartWithFile(
                Endpoint.userProfile,
                fields: fields,
                fileField: pendingLogoData != nil ? "logo" : nil,
                fileData: pendingLogoData,
                fileName: logoFileName(),
                fileMimeType: pendingLogoMime
            )
            // La réponse PUT ne contient pas useBhStripe ni createdAt — préserver les valeurs.
            var updated          = resp.profile
            updated.useBhStripe  = profile?.useBhStripe ?? useBhStripe
            updated.createdAt    = profile?.createdAt

            pendingLogoData    = nil
            pendingLogoMime    = nil
            pendingLogoPreview = nil
            populate(from: updated)
            return updated
        } catch let err as APIError {
            saveError = err.userMessage
        } catch {
            saveError = error.localizedDescription
        }
        return nil
    }

    // MARK: - Bascule Stripe (PATCH JSON)

    func toggleStripe(_ newValue: Bool) async {
        isTogglingStripe = true
        defer { isTogglingStripe = false }
        do {
            let resp: PatchStripeResponse = try await APIClient.shared.patch(
                Endpoint.userProfile,
                body: StripeBody(useBhStripe: newValue)
            )
            useBhStripe = resp.useBhStripe
            profile?.useBhStripe = resp.useBhStripe
            NotificationCenter.default.post(name: .setupShouldRefresh, object: nil)
        } catch let err as APIError {
            useBhStripe = !newValue   // annulation optimiste
            saveError = err.userMessage
        } catch {
            useBhStripe = !newValue
        }
    }

    // MARK: - Helpers privés

    private func logoFileName() -> String {
        switch pendingLogoMime {
        case "image/png":       return "logo.png"
        case "image/webp":      return "logo.webp"
        case "image/gif":       return "logo.gif"
        case "image/heic":      return "logo.heic"
        case "image/heif":      return "logo.heif"
        case "application/pdf": return "logo.pdf"
        default:                return "logo.jpg"
        }
    }

    // MARK: - Réponses privées

    private struct UpdateProfileResponse: Decodable {
        let profile: UserProfile
    }

    // Clé snake_case envoyée en JSON brut (JSONEncoder sans stratégie de conversion).
    private struct StripeBody: Encodable {
        let useBhStripe: Bool
        private enum CodingKeys: String, CodingKey {
            case useBhStripe = "use_bh_stripe"
        }
    }

    // convertFromSnakeCase mappe "use_bh_stripe" → "useBhStripe" sans CodingKeys.
    private struct PatchStripeResponse: Decodable {
        let success:    Bool
        let useBhStripe: Bool
    }
}
