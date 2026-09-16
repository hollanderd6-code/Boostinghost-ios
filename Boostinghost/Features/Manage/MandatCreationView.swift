import SwiftUI

// MARK: - Point d'entrée

struct MandatCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: MandatViewModel
    @State private var showSignatureSheet = false
    @State private var sendError: String? = nil

    let onSuccess: () -> Void

    init(client: OwnerClient, onSuccess: @escaping () -> Void = {}) {
        _vm = State(initialValue: MandatViewModel(client: client))
        self.onSuccess = onSuccess
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                switch vm.loadState {
                case .loading:
                    Spacer()
                    ProgressView().tint(Color.bhAttenue)
                    Spacer()
                case .error(let msg):
                    loadErrorView(msg)
                case .ready:
                    readyContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .sheet(isPresented: $showSignatureSheet) {
            let ownerEmail = vm.draft.ownerEmail
            SignatureSheet(
                signerName: vm.draft.companyRep,
                ownerEmail: ownerEmail,
                footerText: "Un lien de signature partira à \(ownerEmail.isEmpty ? "l'adresse du propriétaire" : ownerEmail). Il verra ta signature déjà apposée et signera à son tour.",
                isSending:  vm.sendState == .sending,
                onSign:     { data in vm.draft.signatureData = data },
                onSendTap:  { Task { await sendMandat() } },
                onCancel:   { showSignatureSheet = false }
            )
        }
        .alert("Erreur", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("OK") { sendError = nil }
        } message: {
            Text(sendError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .bottom, spacing: 0) {
                Button {
                    if vm.currentStep > 1 { vm.prevStep() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                        .frame(width: 38, height: 38)
                        .glassEffect(in: .circle)
                        .specularEdge(cornerRadius: 19)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Étape \(vm.currentStep) sur 5")
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Nouveau mandat")
                        .bhGrandTitre()
                }
                .padding(.leading, 12)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Barre de progression

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { step in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(step <= vm.currentStep ? Color.bhVert : Color.white.opacity(0.35))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentStep)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Contenu principal

    private var readyContent: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("wizardTop")
                        progressBar
                        stepContent
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 110)
                    }
                }
                .onChange(of: vm.currentStep) { _, _ in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { proxy.scrollTo("wizardTop", anchor: .top) }
                }
            }
            actionBar
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case 1:
            Step1View(
                draft: Binding(get: { vm.draft }, set: { vm.draft = $0 }),
                hasPrefill: vm.hasPrefill,
                onResetPrefill: { vm.resetPrefill() }
            )
        case 2:
            Step2View(draft: Binding(get: { vm.draft }, set: { vm.draft = $0 }))
        case 3:
            Step3View(draft: Binding(get: { vm.draft }, set: { vm.draft = $0 }))
        case 4:
            Step4View(draft: Binding(get: { vm.draft }, set: { vm.draft = $0 }))
        case 5:
            Step5View(vm: vm, onSignTap: { showSignatureSheet = true })
        default:
            EmptyView()
        }
    }

    // MARK: - Barre d'action basse en verre

    private var actionBar: some View {
        VStack(spacing: 0) {
            let isLast = vm.currentStep == 5
            PrimaryButton(title: isLast ? "Signer le mandat" : "Suivant") {
                if isLast { showSignatureSheet = true } else { vm.nextStep() }
            }
            .disabled(!vm.isCurrentStepValid)
            .opacity(vm.isCurrentStepValid ? 1 : 0.45)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Envoi

    private func sendMandat() async {
        do {
            try await vm.send()
            showSignatureSheet = false
            onSuccess()
            dismiss()
        } catch let error as APIError {
            showSignatureSheet = false
            sendError = error.userMessage
        } catch {
            showSignatureSheet = false
            sendError = "Erreur réseau."
        }
    }

    // MARK: - État d'erreur au chargement

    private func loadErrorView(_ msg: String) -> some View {
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
}

// MARK: - Étape 1 — Parties et bien

private struct Step1View: View {
    @Binding var draft: MandatDraft
    let hasPrefill: Bool
    let onResetPrefill: () -> Void

    @State private var companyExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if hasPrefill { prefillBanner }
            companySection
            ownerSection
            propertySection
        }
    }

    // MARK: Bannière pré-remplissage

    private var prefillBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhVert)
            Text("Conditions et honoraires repris du dernier mandat.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhEncreDouce)
            Spacer(minLength: 4)
            Button("Remettre à zéro") { onResetPrefill() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.bhVert)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.bhMentheFond)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.bhVert.opacity(0.18), lineWidth: 1)
                }
        }
    }

    // MARK: Bloc conciergerie (replié par défaut)

    private var companySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Conciergerie")
            ListCard {
                CardRow(showSeparator: companyExpanded) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { companyExpanded.toggle() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(draft.companyName.isEmpty ? "Nom de la conciergerie" : draft.companyName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(draft.companyName.isEmpty ? Color.bhAttenue : Color.bhEncre)
                                Text("Informations issues du profil")
                                    .font(.bhMeta)
                                    .foregroundStyle(Color.bhAttenue)
                            }
                            Spacer()
                            Image(systemName: companyExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if companyExpanded {
                    field("Nom / raison sociale", text: $draft.companyName)
                    field("Email",                text: $draft.companyEmail,  keyboard: .emailAddress)
                    field("Téléphone",            text: $draft.companyPhone,  keyboard: .phonePad)
                    field("SIRET",                text: $draft.companySiret,  keyboard: .numberPad)
                    field("Représentant",         text: $draft.companyRep)
                    field("Adresse",              text: $draft.companyAddress)
                    field("Forme juridique",      text: $draft.companyLegal)
                    field("Titre personnalisé",   text: $draft.companyFreeTitle)
                    field("Valeur personnalisée", text: $draft.companyFreeValue, separator: false)
                }
            }
        }
    }

    // MARK: Bloc propriétaire

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Propriétaire")
            ListCard {
                field("Prénom",          text: $draft.ownerFirstName, required: true)
                field("Nom",             text: $draft.ownerLastName,  required: true)
                field("Email",           text: $draft.ownerEmail,     keyboard: .emailAddress, required: true)
                field("Adresse",         text: $draft.ownerAddress)
                field("Téléphone",       text: $draft.ownerPhone,     keyboard: .phonePad)
                field("Date naissance",  text: $draft.ownerDOB)
                field("SIREN",           text: $draft.ownerSiren,     keyboard: .numberPad, separator: false)
            }
        }
    }

    // MARK: Bloc bien

    private var propertySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Bien")
            ListCard {
                field("Adresse du bien",         text: $draft.propAddress)
                menuRow("Type de bien",           value: $draft.propType, options: [
                    ("",            "— Choisir —"),
                    ("appartement", "Appartement"),
                    ("maison",      "Maison"),
                    ("studio",      "Studio"),
                    ("villa",       "Villa"),
                    ("chambre",     "Chambre"),
                    ("gite",        "Gîte / Chalet"),
                    ("autre",       "Autre"),
                ])
                field("Capacité (pers.)",         text: $draft.propCapacity,  keyboard: .numberPad)
                field("Séjour min (nuits)",        text: $draft.minStay,       keyboard: .numberPad)
                field("Séjour max (nuits)",        text: $draft.maxStay,       keyboard: .numberPad)
                menuRow("Animaux",                value: $draft.animals, options: [
                    ("non",        "Non admis"),
                    ("oui",        "Admis"),
                    ("conditions", "Sous conditions"),
                ])
                menuRow("Fumeur",                 value: $draft.smoking, options: [
                    ("non",       "Interdit"),
                    ("exterieur", "Extérieur seulement"),
                    ("oui",       "Autorisé"),
                ])
                menuRow("Fêtes / événements",     value: $draft.parties, options: [
                    ("non",        "Interdits"),
                    ("conditions", "Sous conditions"),
                    ("oui",        "Autorisés"),
                ])
                timePicker("Arrivée",  timeString: $draft.checkinTime)
                timePicker("Départ",   timeString: $draft.checkoutTime, separator: false)
            }
        }
    }

    // MARK: Composants de formulaire

    private func field(
        _ label: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        required: Bool = false,
        separator: Bool = true
    ) -> some View {
        CardRow(showSeparator: separator) {
            HStack(spacing: 8) {
                Text(required ? "\(label)*" : label)
                    .font(.system(size: 14.5))
                    .foregroundStyle(
                        required && text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.bhTerracotta : Color.bhEncre
                    )
                    .frame(minWidth: 110, alignment: .leading)
                Spacer(minLength: 4)
                TextField(label, text: text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
            }
        }
    }

    private func menuRow(
        _ label: String,
        value: Binding<String>,
        options: [(String, String)],
        separator: Bool = true
    ) -> some View {
        let sel = options.first(where: { $0.0 == value.wrappedValue })?.1 ?? ""
        return CardRow(showSeparator: separator) {
            Menu {
                ForEach(options, id: \.0) { v, l in
                    Button { value.wrappedValue = v } label: {
                        if value.wrappedValue == v { Label(l, systemImage: "checkmark") }
                        else { Text(l) }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(label)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Color.bhEncre)
                    Spacer(minLength: 8)
                    HStack(alignment: .top, spacing: 4) {
                        Text(sel)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.bhAttenue.opacity(0.6))
                    }
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func timePicker(
        _ label: String,
        timeString: Binding<String>,
        separator: Bool = true
    ) -> some View {
        CardRow(showSeparator: separator) {
            HStack {
                Text(label)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                DatePicker("", selection: Binding(
                    get: { dateFromHHMM(timeString.wrappedValue) },
                    set: { timeString.wrappedValue = hhmmFromDate($0) }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
            }
        }
    }

    private func dateFromHHMM(_ s: String) -> Date {
        let parts = s.split(separator: ":").compactMap { Int($0) }
        var c = DateComponents()
        c.hour = parts.first ?? 15
        c.minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(from: c) ?? Date()
    }

    private func hhmmFromDate(_ date: Date) -> String {
        let h = Calendar.current.component(.hour,   from: date)
        let m = Calendar.current.component(.minute, from: date)
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Étape 2 — Missions

private struct FreeExtra: Identifiable {
    let id = UUID()
    var label = ""; var price = ""; var unit = "par_prestation"; var isChecked = true
}

private struct Step2View: View {
    @Binding var draft: MandatDraft

    private static let missionCategories: [(String, [String])] = [
        ("Annonces & visibilité", [
            "Prise de photos / vidéos",
            "Rédaction & diffusion des annonces",
            "Optimisation du calendrier & tarifs",
            "Gestion des avis & e-réputation",
        ]),
        ("Réservations", [
            "Traitement des demandes & confirmations",
            "Messages pré-arrivée & consignes",
            "Coordination channel manager / PMS",
            "Collecte des informations voyageurs",
        ]),
        ("Accueil & départ", [
            "Check-in physique",
            "Check-in autonome",
            "Check-out physique",
            "État des lieux entrée / sortie",
        ]),
        ("Ménage & linge", [
            "Ménage de départ",
            "Fourniture & blanchisserie du linge",
            "Réassort produits d'accueil",
            "Contrôle qualité post-ménage",
        ]),
        ("Assistance voyageurs", [
            "Support téléphonique & messages",
            "Gestion des incidents mineurs",
            "Traitement des réclamations",
            "Coordination artisans / prestataires",
        ]),
        ("Maintenance & intendance", [
            "Visites de contrôle",
            "Petite maintenance",
            "Interventions urgentes",
            "Coordination travaux (sur devis validé)",
        ]),
        ("Gestion financière & administrative", [
            "Perception des loyers pour le compte du propriétaire",
            "Perception du dépôt de garantie",
            "Reversements périodiques & relevés",
            "Encaissement taxe de séjour",
            "Fourniture d'un livret d'accueil",
            "Rédaction du contrat de location voyageurs",
        ]),
    ]

    private static let predefinedExtras: [(label: String, units: [(String, String)])] = [
        ("Ménage",                   [("par_prestation","Par prestation"),("par_heure","Par heure"),("par_nuit","Par nuit"),("par_m2","Par m²")]),
        ("Linge",                    [("par_prestation","Par prestation"),("par_nuit","Par nuit"),("par_personne","Par personne")]),
        ("Check-in tardif",          [("par_prestation","Par prestation"),("par_heure","Par heure")]),
        ("Maintenance",              [("par_prestation","Par prestation"),("par_heure","Par heure")]),
        ("Déplacement exceptionnel", [("par_prestation","Par prestation"),("par_km","Par km")]),
        ("Shooting photo",           [("par_prestation","Par prestation")]),
        ("Urgence WE / jour férié",  [("par_prestation","Par prestation"),("par_heure","Par heure")]),
        ("Gestion de sinistre",      [("par_prestation","Par prestation"),("par_heure","Par heure")]),
    ]

    @State private var extraChecked: [Bool]   = Array(repeating: false,           count: 8)
    @State private var extraPrices:  [String] = Array(repeating: "",              count: 8)
    @State private var extraUnits:   [String] = Array(repeating: "par_prestation", count: 8)
    @State private var freeExtras:   [FreeExtra] = []
    @State private var customMission: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            missionsSection
            urgenceSection
            extrasSection
        }
        .onAppear { restoreFromDraft() }
    }

    // MARK: Missions

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Missions")
            ForEach(0..<Self.missionCategories.count, id: \.self) { i in
                categoryBlock(Self.missionCategories[i].0, items: Self.missionCategories[i].1)
            }
            customMissionsBlock
        }
    }

    private func categoryBlock(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
            ListCard {
                ForEach(0..<items.count, id: \.self) { j in
                    CardRow(showSeparator: j < items.count - 1) {
                        missionCheckRow(items[j])
                    }
                }
            }
        }
    }

    private func missionCheckRow(_ label: String) -> some View {
        let on = draft.missions.contains(label)
        return Button {
            if on { draft.missions.removeAll { $0 == label } }
            else  { draft.missions.append(label) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? Color.bhVert : Color.bhAttenue.opacity(0.45))
                Text(label)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.bhEncre)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: on)
    }

    private var customMissionsBlock: some View {
        let allPredefined = Set(Self.missionCategories.flatMap(\.1))
        let customs = draft.missions.filter { !allPredefined.contains($0) }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Missions libres")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.bhAttenue)
            ListCard {
                ForEach(customs, id: \.self) { m in
                    CardRow(showSeparator: true) {
                        HStack {
                            Text(m)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                            Spacer()
                            Button { draft.missions.removeAll { $0 == m } } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.bhAttenue.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(minHeight: 44)
                    }
                }
                CardRow(showSeparator: false) {
                    HStack(spacing: 8) {
                        TextField("Ajouter une mission…", text: $customMission)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                        if !customMission.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                let t = customMission.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty && !draft.missions.contains(t) { draft.missions.append(t) }
                                customMission = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.bhVert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: Urgence

    private var urgenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Plafond d'urgence")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(spacing: 8) {
                        Text("Intervention sans accord")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                        Spacer(minLength: 4)
                        TextField("150", text: $draft.urgenceLimit)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Text("€ TTC")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
            }
        }
    }

    // MARK: Extras facturables

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Extras facturables")
            ListCard {
                ForEach(0..<Self.predefinedExtras.count, id: \.self) { i in
                    CardRow(showSeparator: true) { extraRow(i) }
                }
                ForEach(freeExtras.indices, id: \.self) { i in
                    CardRow(showSeparator: true) { freeExtraRow(i) }
                }
                CardRow(showSeparator: false) {
                    Button {
                        freeExtras.append(FreeExtra())
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle").font(.system(size: 18)).foregroundStyle(Color.bhVert)
                            Text("Ajouter un extra").font(.system(size: 14.5)).foregroundStyle(Color.bhVert)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func extraRow(_ i: Int) -> some View {
        let def = Self.predefinedExtras[i]
        let on  = extraChecked.indices.contains(i) && extraChecked[i]
        return HStack(spacing: 12) {
            Button {
                guard extraChecked.indices.contains(i) else { return }
                extraChecked[i].toggle()
                syncExtras()
            } label: {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? Color.bhVert : Color.bhAttenue.opacity(0.45))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: on)
            Text(def.label)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
            Spacer(minLength: 8)
            if on {
                TextField("0", text: Binding(
                    get: { extraPrices.indices.contains(i) ? extraPrices[i] : "" },
                    set: { if extraPrices.indices.contains(i) { extraPrices[i] = $0; syncExtras() } }
                ))
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 56)
                Text("€").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                if def.units.count > 1 {
                    Picker("", selection: Binding(
                        get: { extraUnits.indices.contains(i) ? extraUnits[i] : def.units[0].0 },
                        set: { if extraUnits.indices.contains(i) { extraUnits[i] = $0; syncExtras() } }
                    )) {
                        ForEach(def.units, id: \.0) { val, lbl in Text(lbl).tag(val) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.bhAttenue)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func freeExtraRow(_ i: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: freeExtras[i].isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(freeExtras[i].isChecked ? Color.bhVert : Color.bhAttenue.opacity(0.45))
                .onTapGesture { freeExtras[i].isChecked.toggle(); syncExtras() }
            TextField("Libellé", text: Binding(
                get: { freeExtras[i].label },
                set: { freeExtras[i].label = $0; syncExtras() }
            ))
            .font(.system(size: 14.5))
            .foregroundStyle(Color.bhEncre)
            Spacer(minLength: 4)
            TextField("0", text: Binding(
                get: { freeExtras[i].price },
                set: { freeExtras[i].price = $0; syncExtras() }
            ))
            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 46)
            Text("€").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
            Picker("", selection: Binding(
                get: { freeExtras[i].unit },
                set: { freeExtras[i].unit = $0; syncExtras() }
            )) {
                Text("/ prestation").tag("par_prestation")
                Text("/ heure").tag("par_heure")
                Text("/ nuit").tag("par_nuit")
            }
            .pickerStyle(.menu).tint(Color.bhAttenue)
            Button { freeExtras.remove(at: i); syncExtras() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18)).foregroundStyle(Color.bhAttenue.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 44)
    }

    // MARK: Sync extras → draft

    private func syncExtras() {
        var result: [String] = []
        for (i, def) in Self.predefinedExtras.enumerated() {
            guard extraChecked.indices.contains(i), extraChecked[i] else { continue }
            let p = extraPrices.indices.contains(i) ? extraPrices[i].trimmingCharacters(in: .whitespaces) : ""
            let u = extraUnits.indices.contains(i)  ? extraUnits[i] : def.units[0].0
            result.append(p.isEmpty ? def.label : "\(def.label) : \(p) € \(u)")
        }
        for fe in freeExtras where fe.isChecked {
            let lbl = fe.label.trimmingCharacters(in: .whitespaces)
            guard !lbl.isEmpty else { continue }
            let p = fe.price.trimmingCharacters(in: .whitespaces)
            result.append(p.isEmpty ? lbl : "\(lbl) : \(p) € \(fe.unit)")
        }
        draft.extrasFacturables = result
    }

    private func restoreFromDraft() {
        extraChecked = Array(repeating: false,            count: Self.predefinedExtras.count)
        extraPrices  = Array(repeating: "",               count: Self.predefinedExtras.count)
        extraUnits   = Array(repeating: "par_prestation", count: Self.predefinedExtras.count)
        for s in draft.extrasFacturables {
            for (j, def) in Self.predefinedExtras.enumerated() {
                if s == def.label {
                    extraChecked[j] = true
                } else if s.hasPrefix(def.label + " : ") {
                    extraChecked[j] = true
                    let rest = String(s.dropFirst(def.label.count + 3))
                    let parts = rest.components(separatedBy: " € ")
                    extraPrices[j] = parts.first ?? ""
                    if parts.count > 1 { extraUnits[j] = parts[1] }
                }
            }
        }
    }
}

// MARK: - Étape 3 — Honoraires

private struct Step3View: View {
    @Binding var draft: MandatDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            remuTypeSection
            if !draft.remuType.isEmpty { dependentSection }
            modalitesSection
        }
    }

    // MARK: Type de rémunération

    private var remuTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Type de rémunération")
            VStack(spacing: 8) {
                remuCard("commission",      "% sur revenus",    "percent",              "Commission sur les revenus")
                remuCard("forfait_mensuel", "Forfait mensuel",  "calendar",             "Montant fixe par mois")
                remuCard("forfait_resa",    "Par réservation",  "house",                "Montant fixe par réservation")
                remuCard("mixte",           "Mixte",            "arrow.triangle.merge", "Commission + forfait mensuel")
                remuCard("carte",           "À la carte",       "list.bullet",          "Services facturés séparément")
            }
        }
    }

    private func remuCard(_ value: String, _ label: String, _ icon: String, _ detail: String) -> some View {
        let sel = draft.remuType == value
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { draft.remuType = value }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(sel ? .white : Color.bhVert)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(sel ? Color.bhVert : Color.bhVert.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(sel ? .white : Color.bhEncre)
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(sel ? .white.opacity(0.8) : Color.bhAttenue)
                }
                Spacer()
                if sel {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sel ? Color.bhVert : Color.white.opacity(0.72))
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: sel)
    }

    // MARK: Champs dépendants

    @ViewBuilder
    private var dependentSection: some View {
        switch draft.remuType {
        case "commission":
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Taux")
                ListCard {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Taux de commission").font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            TextField("0", text: $draft.commissionRate)
                                .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                                .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 60)
                            Text("%").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                    menuRow("Base de calcul", value: $draft.commissionBase, options: [
                        ("ht","Sur revenus HT"), ("ttc","Sur revenus TTC"),
                    ], separator: false)
                }
            }
        case "forfait_mensuel":
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Forfait")
                ListCard {
                    CardRow(showSeparator: false) {
                        amountRow("Montant mensuel", text: $draft.forfaitMensuel, unit: "€/mois", placeholder: "200")
                    }
                }
            }
        case "forfait_resa":
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Forfait")
                ListCard {
                    CardRow(showSeparator: false) {
                        amountRow("Montant / réservation", text: $draft.forfaitResa, unit: "€", placeholder: "50")
                    }
                }
            }
        case "mixte":
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Tarification mixte")
                ListCard {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Taux").font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            TextField("8", text: $draft.mixteRate)
                                .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                                .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 60)
                            Text("%").font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                        }
                    }
                    CardRow(showSeparator: false) {
                        amountRow("Forfait mensuel", text: $draft.mixteForfait, unit: "€/mois", placeholder: "100")
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private func amountRow(_ label: String, text: Binding<String>, unit: String, placeholder: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
            Spacer()
            TextField(placeholder, text: text)
                .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 80)
            Text(unit).font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
        }
    }

    // MARK: Modalités

    private var modalitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Modalités")
            ListCard {
                menuRow("TVA", value: $draft.tva, options: [
                    ("franchise","Auto-entrepreneur, sans TVA"),
                    ("ht","HT — TVA en sus"),
                    ("ttc","TTC toutes taxes comprises"),
                ])
                menuRow("Délai de préavis", value: $draft.tarifPreavis, options: [
                    ("30","30 jours"), ("60","60 jours"), ("90","90 jours"),
                ])
                menuRow("Reversement", value: $draft.reversement, options: [
                    ("par_resa","À chaque réservation"),
                    ("hebdo","Hebdomadaire"),
                    ("mensuel","Mensuel"),
                    ("encaissement_direct","Encaissement direct par le propriétaire"),
                ], separator: false)
            }
        }
    }

    private func menuRow(_ label: String, value: Binding<String>, options: [(String, String)], separator: Bool = true) -> some View {
        let sel = options.first(where: { $0.0 == value.wrappedValue })?.1 ?? ""
        return CardRow(showSeparator: separator) {
            Menu {
                ForEach(options, id: \.0) { v, l in
                    Button { value.wrappedValue = v } label: {
                        if value.wrappedValue == v { Label(l, systemImage: "checkmark") }
                        else { Text(l) }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(label).font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                    Spacer(minLength: 8)
                    HStack(alignment: .top, spacing: 4) {
                        Text(sel)
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.bhAttenue.opacity(0.6))
                    }
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Étape 4 — Conditions

private struct Step4View: View {
    @Binding var draft: MandatDraft
    @State private var newClause: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            dureeSection
            conditionsSection
            clausesSection
        }
    }

    // MARK: Durée

    private var dureeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Durée du contrat")
            ListCard {
                menuRow("Durée", value: $draft.dureeType, options: [
                    ("indeterminee","Indéterminée"),
                    ("determinee","Déterminée"),
                ], separator: draft.dureeType == "determinee")
                if draft.dureeType == "determinee" {
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Date de début").font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            DatePicker("", selection: Binding(
                                get: { isoToDate(draft.dateDebut) },
                                set: { draft.dateDebut = dateToISO($0) }
                            ), displayedComponents: .date)
                            .labelsHidden().tint(Color.bhVert)
                        }
                    }
                    CardRow(showSeparator: true) {
                        HStack {
                            Text("Durée").font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            Picker("", selection: $draft.dureeMois) {
                                if draft.dureeMois.isEmpty { Text("— Choisir —").tag("") }
                                Text("3 mois").tag("3")
                                Text("6 mois").tag("6")
                                Text("12 mois").tag("12")
                                Text("24 mois").tag("24")
                            }
                            .pickerStyle(.menu).tint(Color.bhAttenue)
                        }
                    }
                    menuRow("Renouvellement", value: $draft.renouvellement, options: [
                        ("tacite","Tacite reconduction"),
                        ("expres","Renouvellement exprès"),
                    ], separator: false)
                }
            }
        }
    }

    // MARK: Conditions générales

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Conditions générales")
            ListCard {
                menuRow("Préavis de résiliation", value: $draft.preavis, options: [
                    ("0","Aucun préavis"), ("15","15 jours"), ("30","30 jours"),
                    ("60","60 jours"), ("90","90 jours"),
                ])
                menuRow("Exclusivité", value: $draft.exclusivite, options: [
                    ("non","Sans exclusivité"),
                    ("totale","Exclusivité totale"),
                    ("partielle","Exclusivité partielle, sur les plateformes"),
                ])
                menuRow("Responsabilité", value: $draft.respPlafond, options: [
                    ("oui","Limitée aux honoraires perçus"),
                    ("non","Responsabilité de droit commun"),
                ])
                menuRow("Juridiction", value: $draft.juridiction, options: [
                    ("domicile_defendeur","Domicile du défendeur"),
                    ("lieu_bien","Lieu du bien"),
                    ("commerce","Tribunal de commerce, si 2 sociétés"),
                ])
                menuRow("Confidentialité", value: $draft.confidentialite, options: [
                    ("2","2 ans"), ("5","5 ans"),
                ], separator: false)
            }
        }
    }

    // MARK: Clauses personnalisées

    private var clausesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Clauses personnalisées")
            ListCard {
                ForEach(Array(draft.clausesPersonnalisees.enumerated()), id: \.offset) { idx, clause in
                    CardRow(showSeparator: true) {
                        HStack {
                            Text(clause).font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                            Spacer()
                            Button { draft.clausesPersonnalisees.remove(at: idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18)).foregroundStyle(Color.bhAttenue.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(minHeight: 44)
                    }
                }
                CardRow(showSeparator: false) {
                    HStack(spacing: 8) {
                        TextField("Ajouter une clause…", text: $newClause)
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                        if !newClause.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button {
                                let t = newClause.trimmingCharacters(in: .whitespaces)
                                if !t.isEmpty { draft.clausesPersonnalisees.append(t) }
                                newClause = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20)).foregroundStyle(Color.bhVert)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: Composants

    private func menuRow(_ label: String, value: Binding<String>, options: [(String, String)], separator: Bool = true) -> some View {
        let sel = options.first(where: { $0.0 == value.wrappedValue })?.1 ?? ""
        return CardRow(showSeparator: separator) {
            Menu {
                ForEach(options, id: \.0) { v, l in
                    Button { value.wrappedValue = v } label: {
                        if value.wrappedValue == v { Label(l, systemImage: "checkmark") }
                        else { Text(l) }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(label).font(.system(size: 14.5)).foregroundStyle(Color.bhEncre)
                    Spacer(minLength: 8)
                    HStack(alignment: .top, spacing: 4) {
                        Text(sel)
                            .font(.system(size: 14.5)).foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.bhAttenue.opacity(0.6))
                    }
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func isoToDate(_ s: String) -> Date {
        guard !s.isEmpty else { return Date() }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: s) ?? Date()
    }

    private func dateToISO(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: d)
    }
}

// MARK: - Étape 5 — Récapitulatif + signature

private struct Step5View: View {
    let vm: MandatViewModel
    let onSignTap: () -> Void

    @State private var partiesExpanded  = false
    @State private var missionsExpanded = false
    @State private var honExpanded      = false
    @State private var condExpanded     = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trois chiffres qui engagent — maquette 9a, rayon 18, commission en bhVert
            HStack(spacing: 8) {
                summaryBlock(value: vm.commissionSummary, label: "Rémunération", accent: true)
                summaryBlock(value: vm.dureeSummary,      label: "Durée",        accent: false)
                summaryBlock(value: vm.preavisSummary,    label: "Préavis",      accent: false)
            }

            sectionCard("Parties et bien", isExpanded: $partiesExpanded) { partiesContent }
            sectionCard("Missions", count: vm.draft.missions.count, isExpanded: $missionsExpanded) { missionsContent }
            sectionCard("Honoraires", count: vm.draft.remuType.isEmpty ? 0 : nil, isExpanded: $honExpanded) { honorairesContent }
            sectionCard("Conditions", isExpanded: $condExpanded) { conditionsContent }
        }
    }

    // MARK: Trois blocs

    private func summaryBlock(value: String, label: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent ? Color.bhVert : Color.bhEncre)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background { GlassCardBackground(cornerRadius: 18, fillOpacity: 0.66) }
    }

    // MARK: Section card helper

    private func sectionCard<Content: View>(
        _ title: String,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let built = content()
        return DisclosureGroup(isExpanded: isExpanded) {
            Divider().padding(.top, 8).padding(.bottom, 4)
            built
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue)
                if let n = count {
                    Text("\(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(n > 0 ? Color.bhVert : Color.bhAttenue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(n > 0 ? Color.bhMentheFond : Color.bhAttenue.opacity(0.12)))
                }
            }
        }
        .padding(16)
        .background { GlassCardBackground(cornerRadius: 22) }
    }

    // MARK: Parties et bien

    private var partiesContent: some View {
        let d = vm.draft
        return VStack(spacing: 0) {
            detailRow("Propriétaire",
                value: [d.ownerFirstName, d.ownerLastName].filter { !$0.isEmpty }.joined(separator: " "))
            detailRow("Email",        value: d.ownerEmail)
            detailRow("Adresse",      value: d.propAddress)
            detailRow("Type de bien", value: Self.propTypeLabel(d.propType))
            if !d.propCapacity.isEmpty { detailRow("Capacité",   value: "\(d.propCapacity)\u{202F}pers.") }
            if !d.minStay.isEmpty      { detailRow("Séjour min", value: "\(d.minStay)\u{202F}nuits") }
            if !d.maxStay.isEmpty      { detailRow("Séjour max", value: "\(d.maxStay)\u{202F}nuits") }
            detailRow("Animaux",      value: Self.animalsLabel(d.animals))
            detailRow("Fumeur",       value: Self.smokingLabel(d.smoking))
            detailRow("Fêtes",        value: Self.partiesLabel(d.parties))
            detailRow("Arrivée",      value: Formatters.time(d.checkinTime)  ?? d.checkinTime)
            detailRow("Départ",       value: Formatters.time(d.checkoutTime) ?? d.checkoutTime, separator: false)
        }
    }

    // MARK: Missions

    private var missionsContent: some View {
        let d = vm.draft
        return VStack(spacing: 0) {
            if d.missions.isEmpty && d.extrasFacturables.isEmpty && d.urgenceLimit.isEmpty {
                Text("Aucune mission ni extra sélectionné.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(d.missions.enumerated()), id: \.offset) { _, m in
                    detailItem(m)
                }
                if !d.urgenceLimit.isEmpty {
                    detailRow("Plafond urgence",
                        value: "\(d.urgenceLimit)\u{202F}€ TTC",
                        separator: !d.extrasFacturables.isEmpty)
                }
                ForEach(Array(d.extrasFacturables.enumerated()), id: \.offset) { idx, e in
                    detailItem(e, separator: idx < d.extrasFacturables.count - 1)
                }
            }
        }
    }

    // MARK: Honoraires

    @ViewBuilder
    private var honorairesContent: some View {
        let d = vm.draft
        if d.remuType.isEmpty {
            Text("Aucun type de rémunération sélectionné.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                detailRow("Type", value: Self.remuTypeLabel(d.remuType))
                switch d.remuType {
                case "commission":
                    if !d.commissionRate.isEmpty {
                        detailRow("Taux",          value: "\(d.commissionRate)\u{202F}%")
                    }
                    detailRow("Base de calcul",    value: Self.commissionBaseLabel(d.commissionBase))
                case "forfait_mensuel":
                    if !d.forfaitMensuel.isEmpty {
                        detailRow("Forfait",       value: "\(d.forfaitMensuel)\u{202F}€/mois")
                    }
                case "forfait_resa":
                    if !d.forfaitResa.isEmpty {
                        detailRow("Forfait / rés.", value: "\(d.forfaitResa)\u{202F}€")
                    }
                case "mixte":
                    if !d.mixteRate.isEmpty    { detailRow("Taux",    value: "\(d.mixteRate)\u{202F}%") }
                    if !d.mixteForfait.isEmpty { detailRow("Forfait", value: "\(d.mixteForfait)\u{202F}€/mois") }
                default:
                    EmptyView()
                }
                detailRow("TVA",           value: Self.tvaLabel(d.tva))
                detailRow("Délai préavis", value: "\(d.tarifPreavis)\u{202F}jours")
                detailRow("Reversement",   value: Self.reversementLabel(d.reversement), separator: false)
            }
        }
    }

    // MARK: Conditions

    private var conditionsContent: some View {
        let d = vm.draft
        return VStack(spacing: 0) {
            detailRow("Durée", value: Self.dureeTypeLabel(d.dureeType))
            if d.dureeType == "determinee" {
                if !d.dateDebut.isEmpty { detailRow("Date de début",  value: Self.formatDateISO(d.dateDebut)) }
                if !d.dureeMois.isEmpty { detailRow("Durée (mois)",   value: "\(d.dureeMois)\u{202F}mois") }
                detailRow("Renouvellement", value: Self.renouvellementLabel(d.renouvellement))
            }
            detailRow("Préavis résiliation", value: Self.preavisLabel(d.preavis))
            detailRow("Exclusivité",         value: Self.exclusiviteLabel(d.exclusivite))
            detailRow("Responsabilité",      value: Self.respPlafondLabel(d.respPlafond))
            detailRow("Juridiction",         value: Self.juridictionLabel(d.juridiction))
            detailRow("Confidentialité",     value: Self.confidentialiteLabel(d.confidentialite),
                      separator: !d.clausesPersonnalisees.isEmpty)
            ForEach(Array(d.clausesPersonnalisees.enumerated()), id: \.offset) { idx, c in
                detailItem(c, separator: idx < d.clausesPersonnalisees.count - 1)
            }
        }
    }

    // MARK: Composants de ligne

    private func detailRow(_ label: String, value: String, separator: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.top, 1)
                Spacer()
                Text(value.isEmpty ? "—" : value)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.bhEncre)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    private func detailItem(_ text: String, separator: Bool = true) -> some View {
        VStack(spacing: 0) {
            Text("·\u{202F}\(text)")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhEncre)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            if separator {
                Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.5)
            }
        }
    }

    // MARK: Conversion valeur → libellé

    private static func propTypeLabel(_ v: String) -> String {
        switch v {
        case "appartement": return "Appartement"
        case "maison":      return "Maison"
        case "studio":      return "Studio"
        case "villa":       return "Villa"
        case "chambre":     return "Chambre"
        case "gite":        return "Gîte / Chalet"
        case "autre":       return "Autre"
        default:            return v
        }
    }
    private static func animalsLabel(_ v: String) -> String {
        switch v {
        case "non":        return "Non admis"
        case "oui":        return "Admis"
        case "conditions": return "Sous conditions"
        default:           return v
        }
    }
    private static func smokingLabel(_ v: String) -> String {
        switch v {
        case "non":       return "Interdit"
        case "exterieur": return "Extérieur seulement"
        case "oui":       return "Autorisé"
        default:          return v
        }
    }
    private static func partiesLabel(_ v: String) -> String {
        switch v {
        case "non":        return "Interdits"
        case "conditions": return "Sous conditions"
        case "oui":        return "Autorisés"
        default:           return v
        }
    }
    private static func remuTypeLabel(_ v: String) -> String {
        switch v {
        case "commission":      return "% sur revenus"
        case "forfait_mensuel": return "Forfait mensuel"
        case "forfait_resa":    return "Par réservation"
        case "mixte":           return "Mixte"
        case "carte":           return "À la carte"
        default:                return v
        }
    }
    private static func commissionBaseLabel(_ v: String) -> String {
        switch v {
        case "ht":  return "Sur revenus HT"
        case "ttc": return "Sur revenus TTC"
        default:    return v
        }
    }
    private static func tvaLabel(_ v: String) -> String {
        switch v {
        case "franchise": return "Auto-entrepreneur, sans TVA"
        case "ht":        return "HT — TVA en sus"
        case "ttc":       return "TTC toutes taxes comprises"
        default:          return v
        }
    }
    private static func reversementLabel(_ v: String) -> String {
        switch v {
        case "par_resa":            return "À chaque réservation"
        case "hebdo":               return "Hebdomadaire"
        case "mensuel":             return "Mensuel"
        case "encaissement_direct": return "Encaissement direct par le propriétaire"
        default:                    return v
        }
    }
    private static func dureeTypeLabel(_ v: String) -> String {
        switch v {
        case "indeterminee": return "Indéterminée"
        case "determinee":   return "Déterminée"
        default:             return v
        }
    }
    private static func renouvellementLabel(_ v: String) -> String {
        switch v {
        case "tacite": return "Tacite reconduction"
        case "expres": return "Renouvellement exprès"
        default:       return v
        }
    }
    private static func exclusiviteLabel(_ v: String) -> String {
        switch v {
        case "non":       return "Sans exclusivité"
        case "totale":    return "Exclusivité totale"
        case "partielle": return "Exclusivité partielle, sur les plateformes"
        default:          return v
        }
    }
    private static func respPlafondLabel(_ v: String) -> String {
        switch v {
        case "oui": return "Limitée aux honoraires perçus"
        case "non": return "Responsabilité de droit commun"
        default:    return v
        }
    }
    private static func juridictionLabel(_ v: String) -> String {
        switch v {
        case "domicile_defendeur": return "Domicile du défendeur"
        case "lieu_bien":          return "Lieu du bien"
        case "commerce":           return "Tribunal de commerce, si 2 sociétés"
        default:                   return v
        }
    }
    private static func preavisLabel(_ v: String) -> String {
        if v == "0" { return "Aucun préavis" }
        return v.isEmpty ? "—" : "\(v)\u{202F}jours"
    }
    private static func confidentialiteLabel(_ v: String) -> String {
        return v.isEmpty ? "—" : "\(v)\u{202F}ans"
    }
    private static func formatDateISO(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        guard let date = f.date(from: s) else { return s }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        df.locale = Locale(identifier: "fr_FR")
        return df.string(from: date)
    }
}

// SignatureSheet est dans Features/Manage/SignatureSheet.swift.
