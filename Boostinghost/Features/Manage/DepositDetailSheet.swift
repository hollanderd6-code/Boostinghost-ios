import SwiftUI

// MARK: - Feuille de détail d'une caution

struct DepositDetailSheet: View {
    let deposit: ReservationWithDeposit
    let vm: DepositsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmittingRelease = false
    @State private var showReleaseConfirm  = false
    @State private var showCaptureSheet    = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if deposit.expiresWithin48h, let hours = deposit.hoursUntilAuthExpiry {
                            expiryWarning(hours: hours)
                                .padding(.top, 16)
                                .padding(.horizontal, 18)
                        }

                        sectionLabel("Statut")
                            .padding(.top, 20)
                            .padding(.horizontal, 18)
                        ListCard {
                            CardRow(showSeparator: false) {
                                HStack {
                                    Text("État")
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundStyle(Color.bhEncre)
                                    Spacer()
                                    StatusPill(text: deposit.statusLabel, style: deposit.statusPillStyle)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 18)

                        sectionLabel("Montants")
                            .padding(.top, 20)
                            .padding(.horizontal, 18)
                        ListCard {
                            CardRow(showSeparator: false) {
                                HStack {
                                    Text("Caution")
                                        .font(.system(size: 14.5, weight: .medium))
                                        .foregroundStyle(Color.bhEncre)
                                    Spacer()
                                    Text(deposit.depositAmount.map { Formatters.amount($0) } ?? "—")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.bhEncre)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 18)

                        sectionLabel("Informations")
                            .padding(.top, 20)
                            .padding(.horizontal, 18)
                        ListCard {
                            let showCreated = deposit.depositCreatedAt != nil
                            let showExpiry  = deposit.authExpiryDate != nil
                            let showLink    = deposit.checkoutUrl != nil

                            CardRow(showSeparator: showCreated || showExpiry || showLink) {
                                infoRow("Identifiant", monoValue: deposit.depositId.isEmpty ? "—" : deposit.depositId)
                            }
                            if let raw = deposit.depositCreatedAt {
                                CardRow(showSeparator: showExpiry || showLink) {
                                    infoRow("Créée le", Formatters.day(String(raw.prefix(10))))
                                }
                            }
                            if let expiry = deposit.authExpiryDate {
                                CardRow(showSeparator: showLink) {
                                    infoRow("Expire le", Formatters.day(expiry))
                                }
                            }
                            if let url = deposit.checkoutUrl {
                                CardRow(showSeparator: false) {
                                    paymentLinkRow(url)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, 18)

                        if deposit.canAct {
                            actionButtons
                                .padding(.top, 28)
                                .padding(.horizontal, 18)
                        } else if deposit.isAuthExpired {
                            expiredNotice
                                .padding(.top, 20)
                                .padding(.horizontal, 18)
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Erreur", isPresented: errorPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert(releaseTitle, isPresented: $showReleaseConfirm) {
            Button("Libérer", role: .destructive) { performRelease() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(releaseMessage)
        }
        .sheet(isPresented: $showCaptureSheet) {
            CaptureAmountSheet(deposit: deposit, vm: vm, onDismiss: { dismiss() })
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    if let name = deposit.propertyName {
                        Text(name)
                            .font(.bhSurTitre)
                            .foregroundStyle(Color.bhAttenue)
                            .lineLimit(1)
                    }
                    Text("Caution")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Alerte expiration < 48 h

    private func expiryWarning(hours: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text("L'autorisation expire dans \(hours)\u{00A0}h — dernière chance de retenir.")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Color.bhTerracotta)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bhTerracottaFond, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Rows d'info

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, monoValue: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 96, alignment: .leading)
            Text(monoValue)
                .font(.system(size: 13).monospaced())
                .foregroundStyle(Color.bhAttenue)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func paymentLinkRow(_ url: String) -> some View {
        HStack(spacing: 12) {
            Text("Lien")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 96, alignment: .leading)
            Text(url)
                .font(.system(size: 13))
                .foregroundStyle(Color.bhAttenue)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = url
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 36, height: 36)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 18)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Boutons d'action

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { showReleaseConfirm = true } label: {
                releaseLabel
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(.white)
                    .background(Color.bhOccupe, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmittingRelease)

            Button { showCaptureSheet = true } label: {
                Text("Retenir")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color.bhTerracotta)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.bhTerracottaFond)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.bhTerracotta.opacity(0.20), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .disabled(isSubmittingRelease)
        }
    }

    @ViewBuilder private var releaseLabel: some View {
        if isSubmittingRelease {
            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8)
        } else {
            Text("Libérer (tout ok)")
                .font(.system(size: 16, weight: .semibold))
        }
    }

    // MARK: - Notice expirée

    private var expiredNotice: some View {
        Text("L'autorisation Stripe a expiré : la caution ne peut plus être débitée ni libérée.")
            .font(.bhMeta)
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers visuels

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.bhSurTitre)
            .foregroundStyle(Color.bhAttenue)
            .textCase(.uppercase)
            .tracking(1.495)
    }

    // MARK: - Alerts

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var releaseTitle: String { "Restituer la caution ?" }
    private var releaseMessage: String {
        let name = deposit.guestName ?? "ce voyageur"
        let amt  = deposit.depositAmount.map { Formatters.amount($0) } ?? "—"
        return "La caution de \(amt) sera restituée à \(name). Cette action est irréversible."
    }

    // MARK: - Action réseau : libérer

    private func performRelease() {
        guard !isSubmittingRelease, !deposit.depositId.isEmpty else { return }
        isSubmittingRelease = true
        Task {
            do {
                try await APIClient.shared.postVoid(Endpoint.releaseDeposit(deposit.depositId), body: EmptyBody())
                await vm.load()
                dismiss()
            } catch {
                errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
            }
            isSubmittingRelease = false
        }
    }
}

// MARK: - Feuille de saisie du montant à retenir

private struct CaptureAmountSheet: View {
    let deposit: ReservationWithDeposit
    let vm: DepositsViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText   = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var maxAmount: Double { deposit.depositAmount ?? 0 }
    private var enteredAmount: Double? { Double(amountText.replacingOccurrences(of: ",", with: ".")) }
    private var isValid: Bool {
        guard let v = enteredAmount else { return false }
        return v > 0 && v <= maxAmount
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetHandle
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, 20)
                            .padding(.horizontal, 20)

                        amountField
                            .padding(.top, 24)
                            .padding(.horizontal, 20)

                        confirmButton
                            .padding(.top, 28)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .alert("Erreur", isPresented: errorPresented) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            amountText = deposit.depositAmount.map { String(format: "%.2f", $0) } ?? ""
        }
    }

    private var sheetHandle: some View {
        Capsule()
            .fill(Color.bhAttenue.opacity(0.3))
            .frame(width: 38, height: 5)
            .padding(.top, 10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Retenir la caution")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.bhEncre)
            Text("Saisissez le montant à débiter. Plafond : \(maxAmount > 0 ? Formatters.amount(maxAmount) : "—").")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Montant à débiter")
                .font(.bhSurTitre)
                .foregroundStyle(Color.bhAttenue)
                .textCase(.uppercase)
                .tracking(1.495)
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(spacing: 8) {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                            .multilineTextAlignment(.trailing)
                        Text("€")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
            if let v = enteredAmount, v > maxAmount {
                Text("Le montant dépasse le plafond autorisé (\(Formatters.amount(maxAmount))).")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhTerracotta)
            }
        }
    }

    private var confirmButton: some View {
        Button {
            guard isValid, let v = enteredAmount else { return }
            performCapture(amountCents: Int(v * 100))
        } label: {
            Group {
                if isSubmitting {
                    ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(0.8)
                } else {
                    Text(confirmLabel)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(isValid ? Color.bhTerracotta : Color.bhAttenue)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isValid ? Color.bhTerracottaFond : Color.bhAttenue.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke((isValid ? Color.bhTerracotta : Color.bhAttenue).opacity(0.20), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isValid || isSubmitting)
    }

    private var confirmLabel: String {
        guard let v = enteredAmount, isValid else { return "Retenir" }
        return "Retenir \(Formatters.amount(v))"
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func performCapture(amountCents: Int) {
        guard !isSubmitting, !deposit.depositId.isEmpty else { return }
        isSubmitting = true
        Task {
            do {
                struct CaptureBody: Encodable { let amountCents: Int }
                try await APIClient.shared.postVoid(
                    Endpoint.captureDeposit(deposit.depositId),
                    body: CaptureBody(amountCents: amountCents)
                )
                await vm.load()
                dismiss()
                onDismiss()
            } catch {
                errorMessage = (error as? APIError)?.userMessage ?? error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
