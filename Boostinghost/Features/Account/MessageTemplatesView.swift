import SwiftUI

// MARK: - Liste des modèles de messages automatiques

struct MessageTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = MessageTemplatesViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                scrollContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(for: MessageTemplateItem.self) { template in
            TemplateDetailView(template: template, vm: vm)
        }
        .task { await vm.load() }
    }

    // MARK: - Barre de navigation + filtre

    private var navBar: some View {
        VStack(spacing: 0) {
            ZStack {
                VStack(spacing: 2) {
                    Text(countLabel)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                    Text("Messages auto.")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                }
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
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if !vm.properties.isEmpty {
                propertyFilterBar
            }
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var propertyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(id: nil, label: "Tous")
                ForEach(vm.properties) { prop in
                    filterPill(id: prop.id, label: prop.internalName ?? prop.name)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private func filterPill(id: String?, label: String) -> some View {
        let selected = vm.selectedPropertyId == id
        return Button { Task { await vm.selectProperty(id) } } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.bhEncre)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.bhVert)
                        } else {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.55))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var scrollContent: some View {
        switch vm.loadState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()
        case .failed:
            Spacer()
            Text("Impossible de charger les modèles.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        case .loaded:
            if vm.templates.isEmpty {
                Spacer()
                Text("Aucun modèle de message.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    templateList
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private var templateList: some View {
        ListCard {
            ForEach(Array(vm.templates.enumerated()), id: \.element.id) { idx, template in
                CardRow(showSeparator: idx < vm.templates.count - 1) {
                    NavigationLink(value: template) {
                        templateRow(template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func templateRow(_ t: MessageTemplateItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(t.title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                    .lineLimit(1)
                    .truncationMode(.tail)
                StatusPill(
                    text: t.active ? "Actif" : "En pause",
                    style: t.active ? .vert : .neutre
                )
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
            Text(t.contextLine)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.bhAttenue)
                .lineLimit(1)
            Text(t.message)
                .font(.system(size: 13))
                .foregroundStyle(Color.bhCorps)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
    }

    private var countLabel: String {
        guard case .loaded = vm.loadState else { return " " }
        let n = vm.templates.count
        return "\(n) modèle\(n == 1 ? "" : "s")"
    }
}

// MARK: - Fiche d'un modèle (lecture)

private struct TemplateDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let vm: MessageTemplatesViewModel
    @State private var template: MessageTemplateItem
    @State private var isTogglingActive = false
    @State private var toggleError: String? = nil
    @State private var showEdit = false

    init(template: MessageTemplateItem, vm: MessageTemplatesViewModel) {
        self.vm   = vm
        _template = State(initialValue: template)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if let err = toggleError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.85))
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerCard
                        messageSection
                        triggerSection
                        conditionsSection
                        platformsSection
                        scopeSection
                        activeSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEdit) {
            TemplateEditView(template: template, vm: vm) { updated in
                template = updated
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { toggleError != nil },
            set: { if !$0 { toggleError = nil } }
        )) {
            Button("OK") { toggleError = nil }
        } message: {
            Text(toggleError ?? "")
        }
    }

    // MARK: - Barre

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Messages")
                        .font(.system(size: 16.5, weight: .semibold))
                }
                .foregroundStyle(Color.bhVert)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(template.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button("Modifier") { showEdit = true }
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(Color.bhVert)
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

    private var headerCard: some View {
        ListCard {
            HStack(spacing: 12) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(template.title)
                            .font(.system(size: 18.5, weight: .semibold))
                            .foregroundStyle(Color.bhEncre)
                        StatusPill(
                            text: template.active ? "Actif" : "En pause",
                            style: template.active ? .vert : .neutre
                        )
                    }
                    Text(template.triggerLabel)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Message")
            ListCard {
                CardRow(showSeparator: false) {
                    highlightedMessage(template.message)
                        .font(.system(size: 14.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Déclencheur")
            ListCard {
                CardRow(showSeparator: false) {
                    infoRow("Envoi", template.triggerLabel)
                }
            }
        }
    }

    @ViewBuilder
    private var conditionsSection: some View {
        let parsed = SendConditionComponents(template.sendCondition)
        if parsed.hasConditions {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Conditions d'envoi")
                ListCard {
                    ForEach(Array(parsed.conditions.enumerated()), id: \.offset) { idx, token in
                        CardRow(showSeparator: idx < parsed.conditions.count - 1) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.bhVert)
                                Text(SendConditionComponents.conditionLabel(token))
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhEncre)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                Text("Toutes les conditions doivent être remplies au moment de l'envoi.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var platformsSection: some View {
        let parsed = SendConditionComponents(template.sendCondition)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Plateformes")
            ListCard {
                if parsed.hasPlatforms {
                    ForEach(Array(parsed.platforms.enumerated()), id: \.offset) { idx, token in
                        CardRow(showSeparator: idx < parsed.platforms.count - 1) {
                            Text(SendConditionComponents.platformLabel(token))
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    CardRow(showSeparator: false) {
                        Text("Toutes les plateformes")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Logements concernés")
            ListCard {
                CardRow(showSeparator: false) {
                    infoRow("Portée", template.scopeLabel)
                }
            }
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "État")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack {
                        Text("Actif")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        if isTogglingActive {
                            ProgressView().tint(Color.bhAttenue).scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { template.active },
                                set: { _ in Task { await doToggleActive() } }
                            ))
                            .labelsHidden()
                            .tint(Color.bhVert)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers visuels

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Color.bhEncre)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhEncre)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Message avec variables {xxx} mises en valeur en vert.
    private func highlightedMessage(_ text: String) -> Text {
        guard let regex = try? NSRegularExpression(pattern: "\\{[^}]+\\}") else {
            return Text(text).foregroundStyle(Color.bhCorps)
        }
        let ns = text as NSString
        var result = Text("")
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let before = ns.substring(with: NSRange(location: cursor,
                                                    length: match.range.location - cursor))
            if !before.isEmpty {
                result = result + Text(before).foregroundStyle(Color.bhCorps)
            }
            let variable = ns.substring(with: match.range)
            result = result + Text(variable)
                .foregroundStyle(Color.bhVert)
                .fontWeight(.medium)
            cursor = match.range.location + match.range.length
        }
        let trailing = ns.substring(from: cursor)
        if !trailing.isEmpty {
            result = result + Text(trailing).foregroundStyle(Color.bhCorps)
        }
        return result
    }

    // MARK: - Action

    private func doToggleActive() async {
        guard !isTogglingActive else { return }
        isTogglingActive = true
        let before = template.active
        template.active = !before
        do {
            try await vm.toggleActive(templateId: template.id, current: before)
        } catch {
            template.active = before
            toggleError = templateAPIMessage(error)
        }
        isTogglingActive = false
    }
}

// MARK: - Formatage des erreurs API

private func templateAPIMessage(_ error: Error) -> String {
    if let e = error as? APIError {
        switch e {
        case .server(_, let msg?): return msg
        case .network:             return "Connexion impossible. Vérifiez votre réseau."
        default:                   break
        }
    }
    return "Une erreur est survenue. Réessayez."
}
