import SwiftUI

// MARK: - Profil et entreprise (lecture seule, v1)
//
// Source : GET /api/user/profile — docs/releves/mon-compte.md §1
// Écriture : PUT /api/user/profile (multipart) — non implémentée en v1.

struct ProfileView: View {
    let profile: UserProfile?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    if let p = profile {
                        VStack(spacing: 20) {
                            profileSection(p)
                            companySection(p)
                            addressSection(p)
                            billingSection(p)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    } else {
                        ProgressView()
                            .tint(Color.bhAttenue)
                            .padding(.top, 60)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Barre de navigation (retour)

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Mon compte")
                        .font(.system(size: 16.5, weight: .semibold))
                }
                .foregroundStyle(Color.bhVert)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Profil et entreprise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            Spacer()

            Color.clear.frame(width: 110, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func profileSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Profil")
            ListCard {
                let parts = [p.firstName, p.lastName].compactMap { s -> String? in
                    guard let s, !s.isEmpty else { return nil }
                    return s
                }
                let fullName = parts.isEmpty ? "—" : parts.joined(separator: " ")
                infoRow(label: "Nom",       value: fullName,           separator: true)
                infoRow(label: "E-mail",    value: p.email    ?? "—",  separator: true)
                infoRow(label: "Téléphone", value: p.phone    ?? "—",  separator: true)
                infoRow(label: "Site web",  value: p.website  ?? "—",  separator: false)
            }
        }
    }

    @ViewBuilder
    private func companySection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Entreprise")
            ListCard {
                infoRow(label: "Société",          value: p.company   ?? "—", separator: true)
                infoRow(label: "Forme juridique",  value: p.legalForm ?? "—", separator: true)
                infoRow(label: "SIRET",            value: p.siret     ?? "—", separator: false)
            }
        }
    }

    @ViewBuilder
    private func addressSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Adresse")
            ListCard {
                infoRow(label: "Adresse",     value: p.address    ?? "—", separator: true)
                infoRow(label: "Code postal", value: p.postalCode ?? "—", separator: true)
                infoRow(label: "Ville",       value: p.city       ?? "—", separator: false)
            }
        }
    }

    @ViewBuilder
    private func billingSection(_ p: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Facturation")
            ListCard {
                infoRow(label: "Email de facturation", value: p.invoiceEmail ?? "—", separator: true)
                infoRow(label: "Régime TVA",           value: p.vatRegime    ?? "—", separator: true)
                infoRow(label: "Numéro de TVA",        value: p.vatNumber    ?? "—", separator: false)
            }
        }
    }

    // MARK: - Ligne label / valeur

    @ViewBuilder
    private func infoRow(label: String, value: String, separator: Bool) -> some View {
        CardRow(showSeparator: separator) {
            HStack {
                Text(label)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                Spacer(minLength: 8)
                Text(value)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
