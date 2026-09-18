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
            if status.isTrial {
                trialRows(status: status)
            } else {
                activeRows(status: status)
            }
        }
    }

    // Rows pour un trial actif
    @ViewBuilder
    private func trialRows(status: SubscriptionStatus) -> some View {
        let showQuota = (status.propertiesUsed ?? 0) > 0
        let showDate  = status.trialEndDate != nil

        infoRow(label: "Période",
                value: "Essai gratuit",
                separator: showDate || showQuota)

        if let endDate = status.trialEndDate {
            let daysLine: String = {
                guard let d = status.daysRemaining else { return Formatters.dayWithYear(endDate) }
                if d <= 0 { return "Aujourd'hui — \(Formatters.dayWithYear(endDate))" }
                let unit = d == 1 ? "jour" : "jours"
                return "\(d) \(unit) — \(Formatters.dayWithYear(endDate))"
            }()
            infoRow(label: "Fin d'essai",
                    value: daysLine,
                    separator: showQuota)
        }

        if let used = status.propertiesUsed, used > 0 {
            let limit = status.propertiesLimit
            let quotaText = limit.map { "\(used) / \($0)" } ?? "\(used)"
            infoRow(label: "Logements",
                    value: "\(quotaText) logement\(used == 1 ? "" : "s")",
                    separator: false)
        }
    }

    // Rows pour un abonnement actif (comportement original conservé)
    @ViewBuilder
    private func activeRows(status: SubscriptionStatus) -> some View {
        // Formule
        if let plan = formattedPlan(status.planType) {
            infoRow(label: "Formule", value: plan, separator: hasQuota(status) || true)
        }

        // Quota — affiché uniquement si propertiesUsed > 0 (compte agence = 0, c'est juste)
        // BACKEND: propertiesUsed ignore les délégations, corrigé côté serveur plus tard
        if let used = status.propertiesUsed, used > 0 {
            let limit = status.propertiesLimit
            let quotaText = limit.map { "\(used) / \($0)" } ?? "\(used)"
            infoRow(label: "Logements",
                    value: "\(quotaText) logement\(used == 1 ? "" : "s")",
                    separator: true)
        }

        // Renouvellement — null en base si abonnement créé hors Stripe ; affiche "—" dans ce cas
        infoRow(label: "Renouvellement",
                value: status.currentPeriodEnd.map { Formatters.dayWithYear($0) } ?? "—",
                separator: false)
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
}
