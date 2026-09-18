import SwiftUI

// MARK: - Bandeau d'alerte fin de trial (J-3 à J0)
// Affiché uniquement pour les comptes principaux quand shouldShowTrialBanner == true.
// Non-dismissible en V1 — l'échéance concerne l'accès à l'app entière.

struct TrialExpirationBanner: View {
    let status: SubscriptionStatus
    var onSubscribeTap: () -> Void = {}

    private var urgency: Urgency {
        switch status.daysRemaining ?? Int.max {
        case ...0: return .critical
        case 1:    return .high
        default:   return .moderate
        }
    }

    private var iconName: String {
        urgency == .moderate ? "clock" : "clock.badge.exclamationmark.fill"
    }

    private var titleText: String {
        guard let days = status.daysRemaining else {
            return status.displayMessage ?? "Votre essai se termine bientôt"
        }
        switch days {
        case ...0: return "Votre essai se termine aujourd'hui"
        case 1:    return "Plus qu'un jour d'essai"
        case 2:    return "Votre essai se termine dans 2 jours"
        default:   return "Votre essai se termine dans \(days) jours"
        }
    }

    private var subtitleText: String {
        if let days = status.daysRemaining, days <= 0 {
            return "Choisissez votre abonnement pour conserver l'accès à Boostinghost."
        }
        return "Choisissez votre abonnement pour continuer à utiliser Boostinghost."
    }

    private var borderOpacity: Double { urgency == .moderate ? 0.35 : 0.55 }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.bhOr)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.bhTitreLigne)
                    .foregroundStyle(Color.bhEncre)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitleText)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSubscribeTap) {
                HStack(spacing: 3) {
                    Text("Voir les offres")
                        .font(.system(size: 13.5, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.bhVert)
                .frame(minHeight: 44)
                .padding(.leading, 8)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.bhOrFond, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.bhOrClair.opacity(borderOpacity), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText). \(subtitleText)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Toucher pour voir les offres d'abonnement")
        .animation(.easeInOut(duration: 0.2), value: urgency)
    }

    private enum Urgency: Equatable { case moderate, high, critical }
}

// MARK: - Previews

#if DEBUG
#Preview("J-3 — attention") {
    ZStack {
        AppBackground()
        VStack(spacing: 16) {
            TrialExpirationBanner(
                status: SubscriptionStatus(status: "trial", daysRemaining: 3, showAlert: true)
            )
            TrialExpirationBanner(
                status: SubscriptionStatus(status: "trial", daysRemaining: 2, showAlert: true)
            )
        }
        .padding(.horizontal, 18)
    }
}

#Preview("J-1 — urgent") {
    ZStack {
        AppBackground()
        TrialExpirationBanner(
            status: SubscriptionStatus(status: "trial", daysRemaining: 1, showAlert: true)
        )
        .padding(.horizontal, 18)
    }
}

#Preview("J0 — aujourd'hui") {
    ZStack {
        AppBackground()
        TrialExpirationBanner(
            status: SubscriptionStatus(status: "trial", daysRemaining: 0, showAlert: true)
        )
        .padding(.horizontal, 18)
    }
}

#Preview("J-7 — bannière absente") {
    ZStack {
        AppBackground()
        VStack {
            let s = SubscriptionStatus(status: "trial", daysRemaining: 7, showAlert: false)
            if s.shouldShowTrialBanner {
                TrialExpirationBanner(status: s)
            } else {
                Text("Aucune bannière (trial J-7)")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
        }
        .padding(.horizontal, 18)
    }
}

#Preview("Active — bannière absente") {
    ZStack {
        AppBackground()
        VStack {
            let s = SubscriptionStatus(status: "active", daysRemaining: nil, showAlert: false)
            if s.shouldShowTrialBanner {
                TrialExpirationBanner(status: s)
            } else {
                Text("Aucune bannière (abonnement actif)")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
        }
        .padding(.horizontal, 18)
    }
}
#endif
