import SwiftUI
import QuickLook

// MARK: - Écran principal

struct AttestationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AttestationViewModel()

    @State private var showClientPicker   = false
    @State private var showSignatureSheet = false
    @State private var emitterExpanded    = false
    @State private var monthlyExpanded    = false
    @State private var customLabelLines: Set<UUID> = []

    @State private var pdfURL:          URL?    = nil
    @State private var generateError:   String? = nil
    @State private var sendError:       String? = nil
    @State private var successMessage:  String? = nil
    @State private var showSuccessAlert = false

    private static let commonLabels = [
        "Ménage", "Repassage", "Jardinage",
        "Petit bricolage", "Garde d'animaux", "Assistance administrative",
    ]

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch vm.loadState {
                case .loading:       loadingView
                case .featureBlocked: featureBlockedView
                case .error(let m):  errorView(m)
                case .ready:         readyContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .numericKeyboardBar()
        .task { await vm.load() }
        .sheet(isPresented: $showClientPicker) {
            AttestationClientPickerSheet(
                clients:  vm.selectableClients,
                selected: vm.selectedClient,
                onSelect: { c in vm.selectClient(c); showClientPicker = false },
                onCancel: { showClientPicker = false }
            )
        }
        .sheet(isPresented: $showSignatureSheet) {
            let clientEmail = vm.selectedClient?.email ?? ""
            SignatureSheet(
                signerName: vm.draft.emitterCompany,
                ownerEmail: clientEmail,
                footerText: "L'attestation sera envoyée à \(clientEmail.isEmpty ? "l'adresse du bénéficiaire" : clientEmail). Ce document ne sera pas conservé — enregistrez-en une copie si nécessaire.",
                isSending:  vm.sendState == .loading,
                onSign:     { data in vm.draft.signatureData = data },
                onSendTap:  { Task { await sendAttestation() } },
                onCancel:   { showSignatureSheet = false }
            )
        }
        .quickLookPreview($pdfURL)
        .alert("Erreur de génération", isPresented: Binding(
            get: { generateError != nil }, set: { if !$0 { generateError = nil } }
        )) {
            Button("OK") { generateError = nil }
        } message: { Text(generateError ?? "") }
        .alert("Erreur d'envoi", isPresented: Binding(
            get: { sendError != nil }, set: { if !$0 { sendError = nil } }
        )) {
            Button("OK") { sendError = nil }
        } message: { Text(sendError ?? "") }
        .alert("Attestation envoyée", isPresented: $showSuccessAlert) {
            Button("Télécharger une copie") { Task { await downloadAndDismiss() } }
            Button("Fermer", role: .cancel) { dismiss() }
        } message: {
            Text("\(successMessage ?? "")\n\nCe document n'est pas conservé sur nos serveurs. Téléchargez-en une copie avant de quitter si nécessaire.")
        }
    }

    // MARK: - Barre de navigation en verre

    private var navBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 38, height: 38)
                    .glassEffect(in: .circle)
                    .specularEdge(cornerRadius: 19)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Documents")
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Attestation fiscale")
                    .bhGrandTitre()
            }
            .padding(.leading, 12)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - États de chargement

    private var loadingView: some View {
        VStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
    }

    private var featureBlockedView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "lock.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color.bhAttenue)
            Text("Fonctionnalité non incluse")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
            Text("L'attestation fiscale n'est pas incluse dans votre abonnement actuel.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await vm.load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Contenu principal

    private var readyContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    beneficiaireSection
                    anneeLieuSection
                    prestataireSection
                    prestationsSection
                    detailMensuelSection
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            actionBar
        }
    }

    // MARK: - 1. Bloc BÉNÉFICIAIRE

    private var beneficiaireSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Bénéficiaire")
            ListCard {
                if let client = vm.selectedClient {
                    CardRow(showSeparator: clientAddress(client) != nil) {
                        HStack(spacing: 12) {
                            ProfileAvatarView(
                                logoUrl:   nil,
                                firstName: client.firstName,
                                lastName:  client.lastName,
                                company:   client.companyName,
                                size:      40
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.bhEncre)
                                if let email = client.email, !email.isEmpty {
                                    Text(email)
                                        .font(.bhMeta)
                                        .foregroundStyle(Color.bhAttenue)
                                }
                            }
                            Spacer()
                            Button { showClientPicker = true } label: {
                                Text("Modifier")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .glassEffect(in: .rect(cornerRadius: 10))
                                    .specularEdge(cornerRadius: 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let addr = clientAddress(client) {
                        CardRow(showSeparator: false) {
                            HStack {
                                Text("Adresse")
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhAttenue)
                                Spacer(minLength: 8)
                                Text(addr)
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhEncre)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else {
                    CardRow(showSeparator: false) {
                        Button { showClientPicker = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                Text("Choisir un bénéficiaire")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.bhVert)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let msg = vm.beneficiaireMessage {
                inlineHint(msg)
            }
        }
    }

    private func clientAddress(_ c: OwnerClient) -> String? {
        let parts = [c.address, c.postalCode, c.city]
            .compactMap { v in v.flatMap { $0.isEmpty ? nil : $0 } }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // MARK: - 2. Bloc ANNÉE ET LIEU

    private var anneeLieuSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Année et lieu")
            ListCard {
                CardRow(showSeparator: true) {
                    HStack {
                        Text("Année")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        Picker("Année", selection: $vm.draft.year) {
                            ForEach(vm.draft.availableYears, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.bhAttenue)
                    }
                }
                CardRow(showSeparator: true) {
                    HStack(spacing: 8) {
                        Text("Ville")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                            .frame(minWidth: 80, alignment: .leading)
                        Spacer(minLength: 4)
                        TextField("Ville", text: $vm.draft.ville)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.trailing)
                    }
                }
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Date")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        DatePicker("", selection: $vm.draft.date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.bhVert)
                    }
                }
            }
        }
    }

    // MARK: - 3. Bloc PRESTATAIRE (replié par défaut)

    private var prestataireSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Prestataire")
            ListCard {
                CardRow(showSeparator: emitterExpanded) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { emitterExpanded.toggle() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.draft.emitterCompany.isEmpty ? "Conciergerie" : vm.draft.emitterCompany)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(vm.draft.emitterCompany.isEmpty ? Color.bhAttenue : Color.bhEncre)
                                Text("Informations issues du profil")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer()
                            Image(systemName: emitterExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if emitterExpanded {
                    emitterField("Raison sociale",  text: $vm.draft.emitterCompany)
                    emitterField("Adresse",          text: $vm.draft.emitterAddress)
                    emitterField("Code postal",      text: $vm.draft.emitterPostalCode, keyboard: .numberPad)
                    emitterField("Ville",            text: $vm.draft.emitterCity)
                    emitterField("SIRET",            text: $vm.draft.emitterSiret,      keyboard: .numberPad)
                    emitterField("Email",            text: $vm.draft.emitterEmail,      keyboard: .emailAddress, separator: false)
                }
            }
            Text("Les valeurs affichées proviennent du profil du compte. Elles peuvent différer du profil émetteur personnalisé utilisé sur le web.")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.bhAttenue)
                .padding(.horizontal, 2)
        }
    }

    private func emitterField(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        separator: Bool = true
    ) -> some View {
        CardRow(showSeparator: separator) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                    .frame(minWidth: 100, alignment: .leading)
                Spacer(minLength: 4)
                TextField(label, text: text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
            }
        }
    }

    // MARK: - 4. Bloc PRESTATIONS

    private var prestationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Prestations")
            ListCard {
                ForEach(vm.draft.lines.indices, id: \.self) { i in
                    lineRow(index: i)
                }
                CardRow(showSeparator: false) {
                    Button { vm.draft.lines.append(AttestationLine()) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.bhVert)
                            Text("Ajouter une prestation")
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhVert)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            // Total annuel
            HStack {
                Spacer()
                Text("Total annuel")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.bhAttenue)
                Text(frenchAmount(vm.draft.grandTotalDecimal))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 2)
            if let msg = vm.prestationsMessage {
                inlineHint(msg)
            }
        }
    }

    @ViewBuilder
    private func lineRow(index i: Int) -> some View {
        CardRow(showSeparator: true) {
            VStack(alignment: .leading, spacing: 10) {
                // Libellé + suppression
                HStack(spacing: 8) {
                    labelPicker(index: i)
                    Spacer(minLength: 4)
                    if vm.draft.lines.count > 1 {
                        Button {
                            customLabelLines.remove(vm.draft.lines[i].id)
                            vm.draft.lines.remove(at: i)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.bhAttenue.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Heures × taux = total
                HStack(spacing: 6) {
                    TextField("0", text: Binding(
                        get: { vm.draft.lines[i].heures },
                        set: { vm.draft.lines[i].heures = $0 }
                    ))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 52)

                    Text("h")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)

                    Text("×")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)

                    TextField("0", text: Binding(
                        get: { vm.draft.lines[i].taux },
                        set: { vm.draft.lines[i].taux = $0 }
                    ))
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 52)

                    Text("€/h")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)

                    Spacer()

                    if let total = vm.draft.lines[i].totalDecimal {
                        Text("= \(frenchAmount(total))")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func labelPicker(index i: Int) -> some View {
        let lineId    = vm.draft.lines[i].id
        let isCustom  = customLabelLines.contains(lineId)
        let current   = vm.draft.lines[i].label

        if isCustom {
            HStack(spacing: 6) {
                TextField("Service*", text: Binding(
                    get: { vm.draft.lines[i].label },
                    set: { vm.draft.lines[i].label = $0 }
                ))
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)

                Button {
                    customLabelLines.remove(lineId)
                    vm.draft.lines[i].label = ""
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                }
                .buttonStyle(.plain)
            }
        } else {
            Menu {
                ForEach(Self.commonLabels, id: \.self) { opt in
                    Button {
                        vm.draft.lines[i].label = opt
                        customLabelLines.remove(lineId)
                    } label: {
                        if current == opt { Label(opt, systemImage: "checkmark") }
                        else { Text(opt) }
                    }
                }
                Divider()
                Button("Saisie libre…") {
                    vm.draft.lines[i].label = ""
                    customLabelLines.insert(lineId)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(current.isEmpty ? "Choisir un service*" : current)
                        .font(.system(size: 14.5))
                        .foregroundStyle(current.isEmpty ? Color.bhTerracotta : Color.bhEncre)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.bhAttenue.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 5. Bloc DÉTAIL MENSUEL (optionnel, replié)

    private var detailMensuelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { monthlyExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("DÉTAIL MENSUEL".uppercased())
                        .font(.bhIntertitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("(optionnel)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.bhAttenue)
                    Spacer()
                    Image(systemName: monthlyExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            .buttonStyle(.plain)

            if monthlyExpanded {
                ListCard {
                    ForEach(vm.draft.monthlyRows.indices, id: \.self) { i in
                        monthlyRow(index: i)
                    }
                    CardRow(showSeparator: false) {
                        Button { vm.draft.monthlyRows.append(AttestationMonthRow()) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.bhVert)
                                Text("Ajouter un mois")
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhVert)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    if vm.draft.monthlyExceedsAnnual {
                        Label("Cumul mensuel supérieur au total annuel", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.bhOr)
                    }
                    Spacer()
                    Text("Cumul\u{202F}: \(frenchAmount(vm.draft.monthlyTotalDecimal))")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Color.bhAttenue)
                }
                .padding(.horizontal, 2)
            }
        }
    }

    @ViewBuilder
    private func monthlyRow(index i: Int) -> some View {
        let isLast = i == vm.draft.monthlyRows.count - 1
        CardRow(showSeparator: !isLast) {
            HStack(spacing: 8) {
                TextField("Mois", text: Binding(
                    get: { vm.draft.monthlyRows[i].mois },
                    set: { vm.draft.monthlyRows[i].mois = $0 }
                ))
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .frame(minWidth: 90)

                Spacer(minLength: 4)

                TextField("0", text: Binding(
                    get: { vm.draft.monthlyRows[i].heures },
                    set: { vm.draft.monthlyRows[i].heures = $0 }
                ))
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 44)

                Text("h")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)

                TextField("0", text: Binding(
                    get: { vm.draft.monthlyRows[i].montant },
                    set: { vm.draft.monthlyRows[i].montant = $0 }
                ))
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 56)

                Text("€")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)

                Button { vm.draft.monthlyRows.remove(at: i) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.bhAttenue.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - 6. Barre d'action basse en verre

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Aperçu PDF
            Button { Task { await generateAndPreview() } } label: {
                Group {
                    if vm.generateState == .loading {
                        ProgressView().tint(Color.bhEncreDouce)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text").imageScale(.small)
                            Text("Aperçu PDF")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.bhEncreDouce)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .glassEffect(in: .rect(cornerRadius: 15))
                .specularEdge(cornerRadius: 15)
            }
            .buttonStyle(.plain)
            .disabled(!vm.isReadyToSubmit || vm.generateState == .loading)
            .opacity(!vm.isReadyToSubmit ? 0.45 : 1)

            // Signer et envoyer
            Button { showSignatureSheet = true } label: {
                Group {
                    if vm.sendState == .loading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Signer et envoyer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    !vm.isReadyToSubmit ? Color.bhVert.opacity(0.35) : Color.bhVert,
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.isReadyToSubmit || vm.sendState == .loading)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Actions

    private func generateAndPreview() async {
        do {
            let data = try await vm.generatePDF()
            pdfURL = try writeTempPDF(data)
        } catch {
            generateError = (error as? APIError)?.userMessage ?? "Erreur lors de la génération du PDF."
        }
    }

    private func sendAttestation() async {
        do {
            let message = try await vm.send()
            showSignatureSheet = false
            successMessage = message
            showSuccessAlert = true
        } catch {
            showSignatureSheet = false
            sendError = (error as? APIError)?.userMessage ?? "Erreur lors de l'envoi."
        }
    }

    private func downloadAndDismiss() async {
        do {
            let data = try await vm.generatePDF()
            pdfURL = try writeTempPDF(data)
            // L'utilisateur partage depuis QuickLook, puis peut fermer manuellement.
        } catch {
            generateError = (error as? APIError)?.userMessage ?? "Erreur lors de la génération."
        }
    }

    private func writeTempPDF(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(component: "attestation_\(Int(Date().timeIntervalSince1970)).pdf")
        try data.write(to: url)
        return url
    }

    // MARK: - Message inline de validation

    private func inlineHint(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.bhOr)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Formatage (affichage, fr_FR)

    private func frenchAmount(_ decimal: Decimal) -> String {
        let n = NSDecimalNumber(decimal: decimal)
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let str = f.string(from: n) ?? "0,00"
        return "\(str)\u{202F}€"
    }
}

// MARK: - Sélecteur de client (feuille)

private struct AttestationClientPickerSheet: View {
    let clients:  [OwnerClient]
    let selected: OwnerClient?
    let onSelect: (OwnerClient) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Poignée
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.bhAttenue.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 12)

            // En-tête
            HStack(alignment: .firstTextBaseline) {
                Text("Bénéficiaire")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Button("Annuler") { onCancel() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if clients.isEmpty {
                Spacer()
                Text("Aucun client disponible.")
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            } else {
                List {
                    ForEach(clients) { client in
                        Button { onSelect(client) } label: {
                            HStack(spacing: 12) {
                                ProfileAvatarView(
                                    logoUrl:   nil,
                                    firstName: client.firstName,
                                    lastName:  client.lastName,
                                    company:   client.companyName,
                                    size:      40
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.bhEncre)
                                    if let email = client.email, !email.isEmpty {
                                        Text(email)
                                            .font(.bhMeta)
                                            .foregroundStyle(Color.bhAttenue)
                                    }
                                }
                                Spacer()
                                if selected?.id == client.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.bhVert)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .ignoresSafeArea()
        }
    }
}
