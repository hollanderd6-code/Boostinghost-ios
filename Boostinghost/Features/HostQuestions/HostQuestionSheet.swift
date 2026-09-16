import SwiftUI

// MARK: - Feuille d'arbitrage hôte

struct HostQuestionSheet: View {
    let question: HostQuestion

    @State private var isSubmitting = false
    @State private var showNonInput = false
    @State private var nonText = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    contextBlock
                        .padding(.top, 20)
                    questionBlock
                        .padding(.top, 20)
                    if showNonInput {
                        nonInputBlock
                            .padding(.top, 16)
                    }
                    actionButtons
                        .padding(.top, 24)
                    footer
                        .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Question d'un voyageur")
                .font(.bhSurTitre)
                .foregroundStyle(Color.bhAttenue)
                .textCase(.uppercase)
                .tracking(1.495)
            Text(question.guestName ?? "—")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.bhEncre)
        }
    }

    // MARK: - Bloc contexte

    private var contextBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Logement
            if let name = question.meta?.propertyName {
                Label(name, systemImage: "house")
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhEncre)
            }
            // Dates du séjour
            let dateRange = stayDateRange
            if !dateRange.isEmpty {
                Label(dateRange, systemImage: "calendar")
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhEncre)
            }
            // Nuits adjacentes
            Divider()
                .overlay(Color.white.opacity(0.50))
            VStack(alignment: .leading, spacing: 6) {
                adjacentNightRow(
                    label: "Avant l'arrivée",
                    text: beforeText,
                    icon: "arrow.left.to.line"
                )
                adjacentNightRow(
                    label: "Après le départ",
                    text: afterText,
                    icon: "arrow.right.to.line"
                )
            }
            // Bloc schedule
            if question.kind == "schedule" {
                if let meta = question.meta {
                    Divider()
                        .overlay(Color.white.opacity(0.50))
                    scheduleBlock(meta: meta)
                }
            }
        }
        .padding(16)
        .background { GlassCardBackground(cornerRadius: 18, fillOpacity: 0.72) }
    }

    // MARK: - Ligne nuit adjacente

    private func adjacentNightRow(label: String, text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(occupiedColor(text: text))
            }
        }
    }

    private func occupiedColor(text: String) -> Color {
        let lower = text.lowercased()
        if lower.contains("loué") || lower.contains("occupé") { return Color.bhTerracotta }
        return Color.bhOccupeFonce
    }

    // MARK: - Bloc schedule

    private func scheduleBlock(meta: HostQuestionMeta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            let typeLabel = meta.type == "early_checkin" ? "Arrivée anticipée" : "Départ tardif"
            Text(typeLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bhOr)
            if let req = meta.reqLabel {
                HStack(spacing: 6) {
                    Text("Demandé")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    Text(req)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bhEncre)
                }
            }
            if let ref = meta.refLabel {
                HStack(spacing: 6) {
                    Text("Standard")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    Text(ref)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
        }
    }

    // MARK: - Bloc question

    private var questionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Le voyageur demande")
                .font(.bhSurTitre)
                .foregroundStyle(Color.bhAttenue)
                .textCase(.uppercase)
                .tracking(1.495)
            Text(question.question ?? question.guestMessage ?? "—")
                .font(.system(size: 16))
                .foregroundStyle(Color.bhEncre)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Champ texte optionnel pour Non

    private var nonInputBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Précision (optionnelle)")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
            TextField("Ex\u{00A0}: « Nous pouvons arranger ça à partir de… »", text: $nonText, axis: .vertical)
                .font(.bhCorps)
                .foregroundStyle(Color.bhEncre)
                .lineLimit(3...6)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.50), lineWidth: 1)
                        }
                }
        }
    }

    // MARK: - Boutons d'action

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Non
                Button {
                    if showNonInput {
                        submitAnswer("no")
                    } else {
                        withAnimation(.easeInOut(duration: 0.18)) { showNonInput = true }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting && showNonInput {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.bhTerracotta)
                                .scaleEffect(0.8)
                        }
                        Text(showNonInput ? "Confirmer Non" : "Non")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.bhTerracotta)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(red: 253/255, green: 240/255, blue: 236/255).opacity(0.90))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.bhTerracotta.opacity(0.20), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                // Oui
                Button { submitAnswer("yes") } label: {
                    HStack(spacing: 6) {
                        if isSubmitting && !showNonInput {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                        Text("Oui")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.bhOccupe)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }

            if showNonInput {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showNonInput = false
                        nonText = ""
                    }
                } label: {
                    Text("Annuler")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            } else {
                // Je réponds moi-même
                Button { submitSelf() } label: {
                    Text("Je réponds moi-même")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncreDouce)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.40))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                                }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
    }

    // MARK: - Pied de feuille

    private var footer: some View {
        Text("L'IA transmettra votre réponse au voyageur dans sa langue.")
            .font(.bhMeta)
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func submitAnswer(_ answer: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        let id = question.id
        let text = answer == "no" ? nonText : nil
        Task {
            do {
                try await HostQuestionManager.shared.answer(id, answer: answer, text: text)
            } catch {
                errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func submitSelf() {
        guard !isSubmitting else { return }
        isSubmitting = true
        let id = question.id
        let convId = question.conversationId
        Task {
            do {
                try await HostQuestionManager.shared.answer(id, answer: "self")
                NotificationRouter.shared.pendingConversationId = convId
                NotificationRouter.shared.pendingTab = .messages
            } catch {
                errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    // MARK: - Calculs contexte

    // Fidèle à bh-host-questions.js:54 — prevCheckout vs checkin, fallback freeBefore
    private var beforeText: String {
        let prevCO = question.prevCheckout.map { String($0.prefix(10)) }
        let checkin = question.meta?.checkin.map { String($0.prefix(10)) }
        if let p = prevCO, let c = checkin, !p.isEmpty, p == c {
            return "Loué la veille — départ le jour de l'arrivée"
        }
        if let fb = question.meta?.freeBefore {
            return fb ? "Libre avant l'arrivée" : "Loué avant l'arrivée"
        }
        return "Disponibilité inconnue"
    }

    private var afterText: String {
        let nextCI = question.nextCheckin.map { String($0.prefix(10)) }
        let checkout = question.meta?.checkout.map { String($0.prefix(10)) }
        if let n = nextCI, let c = checkout, !n.isEmpty, n == c {
            return "Loué le lendemain — arrivée le jour du départ"
        }
        if let fa = question.meta?.freeAfter {
            return fa ? "Libre après le départ" : "Loué après le départ"
        }
        return "Disponibilité inconnue"
    }

    private var stayDateRange: String {
        guard let ci = question.meta?.checkin, !ci.isEmpty else { return "" }
        let from = Formatters.dayShort(ci)
        guard let co = question.meta?.checkout, !co.isEmpty else { return from }
        let to = Formatters.dayShort(co)
        return "\(from) → \(to)"
    }
}
