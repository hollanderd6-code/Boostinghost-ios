import SwiftUI

// Carte inline d'arbitrage hôte — intégrée dans le fil de la conversation.
// Affiche l'état pending (Oui/Non/self) ou résolu (accepted/refused/self).
// Délègue le réseau au ConversationDetailViewModel pour garder un point unique de vérité.

struct HostQuestionCard: View {
    let question: HostQuestion
    let onAnswer: (_ answer: String, _ text: String?) async throws -> Void

    @State private var isSubmitting = false
    @State private var showNonInput = false
    @State private var nonText = ""
    @State private var submitError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if question.isPending {
                pendingCard
            } else {
                resolvedCard
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityCardLabel)
    }

    // MARK: - Carte pending

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader(icon: "sparkles", label: scheduleTitle, color: Color.bhOr)

            if question.kind == "schedule", let meta = question.meta {
                scheduleDetails(meta: meta)
                    .padding(.bottom, 4)
            }

            Text(question.question ?? question.guestMessage ?? "—")
                .font(.system(size: 14))
                .foregroundStyle(Color.bhEncre)
                .fixedSize(horizontal: false, vertical: true)

            if showNonInput {
                TextField("Précision (optionnelle)",
                          text: $nonText, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.60))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            actionRow
        }
        .padding(14)
        .background { pendingBackground }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Erreur", isPresented: Binding(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("OK") { submitError = nil }
        } message: { Text(submitError ?? "") }
    }

    // MARK: - Carte résolue

    private var resolvedCard: some View {
        HStack(spacing: 10) {
            Image(systemName: resolvedIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(resolvedIconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(resolvedIconColor)
                if let req = question.meta?.reqLabel {
                    Text(req)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhEncre)
                }
                if question.isAnsweredYes || question.isAnsweredNo {
                    Text("Réponse envoyée au voyageur")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(resolvedBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(resolvedIconColor.opacity(0.15), lineWidth: 1)
                }
        }
    }

    // MARK: - Sous-vues pending

    private func cardHeader(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func scheduleDetails(meta: HostQuestionMeta) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let req = meta.reqLabel {
                scheduleRow(label: requestedLabel, value: req)
            }
            if let ref = meta.refLabel {
                scheduleRow(label: standardLabel, value: ref)
            }
        }
    }

    private func scheduleRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.bhAttenue)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
        }
    }

    private var actionRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Non
                Button {
                    if showNonInput {
                        submit("no")
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { showNonInput = true }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isSubmitting && showNonInput {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.bhTerracotta)
                                .scaleEffect(0.7)
                        }
                        Text(showNonInput ? "Confirmer Non" : "Non")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(Color.bhTerracotta)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 253/255, green: 240/255, blue: 236/255).opacity(0.90))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.bhTerracotta.opacity(0.20), lineWidth: 1)
                            }
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel("Refuser")

                // Oui
                Button { submit("yes") } label: {
                    HStack(spacing: 4) {
                        if isSubmitting && !showNonInput {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.7)
                        }
                        Text("Oui")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.bhOccupe)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel("Accepter")
            }

            if showNonInput {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showNonInput = false
                        nonText = ""
                    }
                } label: {
                    Text("Annuler")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            } else {
                Button { submit("self") } label: {
                    Text("Je réponds moi-même")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhEncreDouce)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.30))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
                .accessibilityLabel("Je réponds moi-même")
            }
        }
    }

    // MARK: - Actions

    private func submit(_ answer: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        let text = answer == "no" ? nonText : nil
        Task {
            do {
                try await onAnswer(answer, text?.isEmpty == false ? text : nil)
            } catch {
                submitError = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    // MARK: - Computed strings

    private var scheduleTitle: String {
        guard question.kind == "schedule" else { return "Question" }
        switch question.meta?.type {
        case .early: return "Arrivée anticipée"
        case .late:  return "Départ tardif"
        default:     return "Demande horaire"
        }
    }

    private var requestedLabel: String {
        switch question.meta?.type {
        case .early: return "Demandée"
        case .late:  return "Demandé"
        default:     return "Demandé"
        }
    }

    private var standardLabel: String {
        switch question.meta?.type {
        case .early: return "Habituelle"
        case .late:  return "Habituel"
        default:     return "Standard"
        }
    }

    private var resolvedTitle: String {
        let base = scheduleTitle
        if question.isAnsweredYes  { return "\(base) acceptée" }
        if question.isAnsweredNo   { return "\(base) refusée" }
        if question.isAnsweredSelf { return "Prise en charge manuellement" }
        return base
    }

    private var resolvedIcon: String {
        if question.isAnsweredYes  { return "checkmark.circle.fill" }
        if question.isAnsweredNo   { return "xmark.circle.fill" }
        return "hand.raised.fill"
    }

    private var resolvedIconColor: Color {
        if question.isAnsweredYes  { return Color.bhOccupe }
        if question.isAnsweredNo   { return Color.bhTerracotta }
        return Color.bhAttenue
    }

    private var resolvedBackground: Color {
        if question.isAnsweredYes { return Color.bhOccupe.opacity(0.08) }
        if question.isAnsweredNo  { return Color.bhTerracotta.opacity(0.08) }
        return Color.white.opacity(0.30)
    }

    private var pendingBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(hex: "#FFF8E7").opacity(0.88))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.bhOr.opacity(0.30), lineWidth: 1)
            }
    }

    private var accessibilityCardLabel: String {
        question.isPending ? "Demande en attente : \(scheduleTitle)" : resolvedTitle
    }
}
