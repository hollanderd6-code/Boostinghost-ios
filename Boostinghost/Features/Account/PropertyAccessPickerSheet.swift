import SwiftUI

// MARK: - Sélecteur de logements accessibles pour un sous-compte
//
// Binding : selectedIds
//   []            → accès à TOUS les logements (sémantique backend)
//   ["id1","id2"] → sélection précise
//
// États internes :
//   explicitAllMode = true  → "Tous les logements" choisi explicitement  → commit envoie []
//   explicitAllMode = false, draft non vide → sélection précise          → commit envoie les IDs
//   explicitAllMode = false, draft vide     → état INVALIDE              → Valider désactivé
//
// Invariant : on ne normalise JAMAIS silencieusement draft.isEmpty vers [].
// L'utilisateur doit choisir explicitement "Tous les logements" pour obtenir [].

struct PropertyAccessPickerSheet: View {

    @Binding var selectedIds: [String]
    let properties: [Property]

    @Environment(\.dismiss) private var dismiss

    @State private var draft: Set<String>
    @State private var explicitAllMode: Bool
    @State private var search = ""

    init(selectedIds: Binding<[String]>, properties: [Property]) {
        self._selectedIds = selectedIds
        let ids = selectedIds.wrappedValue
        self._draft          = State(initialValue: Set(ids))
        self._explicitAllMode = State(initialValue: ids.isEmpty)
        self.properties = properties
    }

    private var isAllMode: Bool { explicitAllMode }

    // Valider autorisé ssi : "Tous" explicite OU au moins un logement coché.
    private var isCommitAllowed: Bool { explicitAllMode || !draft.isEmpty }

    private var allIds: Set<String> { Set(properties.map(\.id)) }

    private var filtered: [Property] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return properties }
        return properties.filter { ($0.internalName ?? $0.name).lowercased().contains(q) }
    }

    private var selectionLabel: String {
        if isAllMode { return "Tous les logements" }
        if draft.isEmpty { return "Aucun logement sélectionné" }
        let n = draft.count
        return "\(n) logement\(n == 1 ? "" : "s") sélectionné\(n == 1 ? "" : "s")"
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if properties.count >= 6 { searchBar }
                        accessSection
                        if !isAllMode { propertyList }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Barre

    private var navBar: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                Text("Logements accessibles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                HStack {
                    Button("Annuler") { dismiss() }
                        .font(.system(size: 16))
                        .foregroundStyle(Color.bhAttenue)
                        .buttonStyle(.plain)
                    Spacer()
                    Button("Valider") { commit() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isCommitAllowed ? Color.bhVert : Color.bhAttenue)
                        .buttonStyle(.plain)
                        .disabled(!isCommitAllowed)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Barre de recherche

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.bhAttenue)
            TextField("Rechercher un logement…", text: $search)
                .font(.bhCorps)
                .foregroundStyle(Color.bhEncre)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.bhAttenue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .glassEffect(in: .rect(cornerRadius: 14))
                .specularEdge(cornerRadius: 14)
        }
    }

    // MARK: - Toggle "Tous les logements"

    private var accessSection: some View {
        ListCard {
            CardRow(showSeparator: false) {
                Button {
                    if isAllMode {
                        // Décocher "Tous" → sélectionner tous individuellement.
                        explicitAllMode = false
                        draft = allIds
                    } else {
                        // Cocher "Tous" → revenir en mode accès total.
                        explicitAllMode = true
                        draft = []
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isAllMode ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isAllMode ? Color.bhVert : Color.bhAttenue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tous les logements")
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Text("Accès à l'ensemble des logements du compte")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Liste individuelle (mode sélection)

    private var propertyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: selectionLabel)
            // Alerte visible quand aucune propriété n'est cochée en mode individuel.
            if !explicitAllMode && draft.isEmpty {
                Text("Sélectionnez au moins un logement ou choisissez « Tous les logements ».")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 4)
            }
            if filtered.isEmpty {
                ListCard {
                    CardRow(showSeparator: false) {
                        Text("Aucun logement correspondant.")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                }
            } else {
                ListCard {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, property in
                        CardRow(showSeparator: idx < filtered.count - 1) {
                            propertyRow(property)
                        }
                    }
                }
            }
        }
    }

    private func propertyRow(_ property: Property) -> some View {
        let isSelected = draft.contains(property.id)
        return Button {
            if isSelected {
                draft.remove(property.id)
                // draft peut devenir vide ici — état invalide visible, Valider est bloqué.
                // Aucune normalisation silencieuse vers [].
            } else {
                draft.insert(property.id)
                // Si tous cochés individuellement → normaliser vers mode accès total.
                if draft == allIds {
                    explicitAllMode = true
                    draft = []
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.bhVert : Color.bhAttenue)
                Text(property.internalName ?? property.name)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.bhEncre)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    // MARK: - Validation

    private func commit() {
        guard isCommitAllowed else { return }
        selectedIds = explicitAllMode ? [] : Array(draft).sorted()
        dismiss()
    }
}
