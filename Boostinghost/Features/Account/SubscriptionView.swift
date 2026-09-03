import SwiftUI

// MARK: - Abonnement et factures (lecture seule, v1)
//
// Règle App Store : aucun bouton d'achat, aucun lien vers le portail Stripe,
// aucune mention de tarif. Affiche uniquement l'état, le quota (si applicable)
// et la date de renouvellement.

struct SubscriptionView: View {
    let status: SubscriptionStatus?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let status {
                            infoCard(status: status)
                        } else {
                            ProgressView()
                                .tint(Color.bhAttenue)
                                .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Barre de navigation (retour)

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
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

            Text("Abonnement")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            Spacer()

            // Équilibre visuel du bouton retour
            Color.clear.frame(width: 90, height: 1)
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

    // MARK: - Carte d'informations

    private func infoCard(status: SubscriptionStatus) -> some View {
        ListCard {
            // Formule
            if let plan = formattedPlan(status.planType) {
                infoRow(label: "Formule", value: plan, separator: hasQuota(status) || hasRenewal(status))
            }

            // Quota — affiché uniquement si propertiesUsed > 0 (compte agence = 0, c'est juste)
            if let used = status.propertiesUsed, used > 0 {
                let limit = status.propertiesLimit
                let quotaText = limit.map { "\(used) / \($0)" } ?? "\(used)"
                infoRow(label: "Logements",
                        value: "\(quotaText) logement\(used == 1 ? "" : "s")",
                        separator: hasRenewal(status))
            }

            // Date de renouvellement
            if let raw = status.currentPeriodEnd {
                infoRow(label: "Renouvellement",
                        value: Formatters.dayWithYear(raw),
                        separator: false)
            }
        }
    }

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

    // MARK: - Helpers

    private func formattedPlan(_ type: String?) -> String? {
        switch type?.lowercased() {
        case "agency", "agence", "agence_monthly":  return "Agence"
        case "pro", "pro_monthly":                   return "Pro"
        case "pro_annual":                           return "Pro (annuel)"
        case "starter":                              return "Starter"
        default:                                     return type?.capitalized
        }
    }

    private func hasQuota(_ s: SubscriptionStatus) -> Bool {
        (s.propertiesUsed ?? 0) > 0
    }

    private func hasRenewal(_ s: SubscriptionStatus) -> Bool {
        s.currentPeriodEnd != nil
    }
}
