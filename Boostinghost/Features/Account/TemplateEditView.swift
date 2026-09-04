import SwiftUI
import UIKit

// MARK: - Formulaire d'édition d'un modèle de message

struct TemplateEditView: View {
    @Environment(\.dismiss) private var dismiss

    let vm:     MessageTemplatesViewModel
    let onSave: (MessageTemplateItem) -> Void

    // Draft fields (initialisés depuis le modèle existant)
    @State private var title:       String
    @State private var message:     String
    @State private var triggerType: String
    @State private var offsetDays:  Int
    @State private var offsetHours: Int
    @State private var conditions:  Set<String>  // deposit_*, police_*
    @State private var platforms:   Set<String>  // platform_*
    @State private var scopeIsAll:  Bool          // true → property_ids = []
    @State private var selectedIds: Set<String>   // propriété explicitement sélectionnées
    @State private var active:      Bool

    private let templateId: Int
    private let insertionProxy = InsertionProxy()

    @State private var showVariablePicker = false
    @State private var isSaving  = false
    @State private var saveError: String? = nil

    init(template: MessageTemplateItem,
         vm: MessageTemplatesViewModel,
         onSave: @escaping (MessageTemplateItem) -> Void) {
        self.vm     = vm
        self.onSave = onSave
        templateId  = template.id

        let cond = SendConditionComponents(template.sendCondition)
        _title       = State(initialValue: template.title)
        _message     = State(initialValue: template.message)
        _triggerType = State(initialValue: template.triggerType.isEmpty ? "before_arrival" : template.triggerType)
        // abs() : trigger_offset_hours/days sont signés en base mais le serveur
        // applique Math.abs() à l'exécution — le signe est sémantiquement nul.
        _offsetDays  = State(initialValue: abs(template.triggerOffsetDays))
        _offsetHours = State(initialValue: abs(template.triggerOffsetHours))
        _conditions  = State(initialValue: Set(cond.conditions))
        _platforms   = State(initialValue: Set(cond.platforms))
        // [] = tous ; ne jamais convertir en sélection explicite à l'ouverture.
        _scopeIsAll  = State(initialValue: template.propertyIds.isEmpty)
        _selectedIds = State(initialValue: Set(template.propertyIds))
        _active      = State(initialValue: template.active)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        titleSection
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
        .sheet(isPresented: $showVariablePicker) {
            VariablePickerSheet { variable in
                insertionProxy.insert(variable)
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Barre

    private var navBar: some View {
        HStack {
            Button("Annuler") { dismiss() }
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(Color.bhVert)

            Spacer()

            Text("Modifier")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            Spacer()

            Button {
                Task { await doSave() }
            } label: {
                if isSaving {
                    ProgressView().tint(Color.bhVert).scaleEffect(0.8)
                } else {
                    Text("Enregistrer")
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(canSave ? Color.bhVert : Color.bhAttenue)
                }
            }
            .disabled(!canSave || isSaving)
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

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - Titre

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Titre")
            ListCard {
                CardRow(showSeparator: false) {
                    TextField("Titre du modèle", text: $title)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.bhEncre)
                }
            }
        }
    }

    // MARK: - Message

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Message")
            ListCard {
                CardRow(showSeparator: false) {
                    VStack(alignment: .trailing, spacing: 10) {
                        CursorTextEditor(text: $message, proxy: insertionProxy)
                            .frame(height: 180)
                        Button {
                            showVariablePicker = true
                        } label: {
                            Label("Insérer une variable", systemImage: "textformat.alt")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.bhVert)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Déclencheur

    private var triggerSection: some View {
        let hasOffset = !["on_arrival", "on_departure", "on_booking"].contains(triggerType)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Déclencheur")
            ListCard {
                CardRow(showSeparator: hasOffset) {
                    Picker("Déclencheur", selection: $triggerType) {
                        ForEach(EditTriggerType.allCases) { t in
                            Text(t.label).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.bhEncre)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if hasOffset {
                    CardRow(showSeparator: false) {
                        VStack(spacing: 12) {
                            HStack {
                                Text(offsetLabel(offsetDays, unit: "j"))
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Stepper("", value: $offsetDays, in: 0...30)
                                    .labelsHidden()
                                    .fixedSize()
                            }
                            Divider()
                            HStack {
                                Text(offsetLabel(offsetHours, unit: "h"))
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Color.bhEncre)
                                Spacer()
                                Stepper("", value: $offsetHours, in: 0...23)
                                    .labelsHidden()
                                    .fixedSize()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Conditions d'envoi

    private var conditionsSection: some View {
        let items: [(token: String, label: String)] = [
            ("deposit_active",   "Caution validée"),
            ("deposit_captured", "Caution encaissée"),
            ("deposit_pending",  "Caution en attente"),
            ("police_complete",  "Fiche de police complète"),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Conditions d'envoi")
            ListCard {
                ForEach(Array(items.enumerated()), id: \.element.token) { idx, item in
                    CardRow(showSeparator: idx < items.count - 1) {
                        Toggle(isOn: Binding(
                            get: { conditions.contains(item.token) },
                            set: { on in
                                if on { conditions.insert(item.token) }
                                else  { conditions.remove(item.token) }
                            }
                        )) {
                            Text(item.label)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                        }
                        .tint(Color.bhVert)
                    }
                }
            }
            Text("Sans condition, le message part à chaque séjour.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Plateformes

    private var platformsSection: some View {
        let items: [(token: String, label: String)] = [
            ("platform_airbnb",  "Airbnb"),
            ("platform_booking", "Booking.com"),
            ("platform_direct",  "Direct / BHGuest"),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Plateformes")
            ListCard {
                ForEach(Array(items.enumerated()), id: \.element.token) { idx, item in
                    CardRow(showSeparator: idx < items.count - 1) {
                        Toggle(isOn: Binding(
                            get: { platforms.contains(item.token) },
                            set: { on in
                                if on { platforms.insert(item.token) }
                                else  { platforms.remove(item.token) }
                            }
                        )) {
                            Text(item.label)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Color.bhEncre)
                        }
                        .tint(Color.bhVert)
                    }
                }
            }
            Text("Sans restriction, le message part sur toutes les plateformes.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Logements

    private var scopeSection: some View {
        let hasProperties = !vm.properties.isEmpty
        let showList = hasProperties && !scopeIsAll
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Logements concernés")
            ListCard {
                CardRow(showSeparator: showList) {
                    Toggle(isOn: $scopeIsAll) {
                        Text("Tous les logements")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.bhEncre)
                    }
                    .tint(Color.bhVert)
                    .onChange(of: scopeIsAll) { _, isAll in
                        if isAll { selectedIds.removeAll() }
                    }
                }

                if showList {
                    ForEach(Array(vm.properties.enumerated()), id: \.element.id) { idx, prop in
                        CardRow(showSeparator: idx < vm.properties.count - 1) {
                            Toggle(isOn: Binding(
                                get: { selectedIds.contains(prop.id) },
                                set: { on in
                                    if on { selectedIds.insert(prop.id) }
                                    else  { selectedIds.remove(prop.id)  }
                                }
                            )) {
                                Text(prop.internalName ?? prop.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.bhEncre)
                            }
                            .tint(Color.bhVert)
                        }
                    }
                }
            }
        }
    }

    // MARK: - État

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "État")
            ListCard {
                CardRow(showSeparator: false) {
                    Toggle(isOn: $active) {
                        Text("Actif")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                    }
                    .tint(Color.bhVert)
                }
            }
        }
    }

    // MARK: - Helpers déclencheur

    private func offsetLabel(_ n: Int, unit: String) -> String {
        let dir: String
        switch triggerType {
        case "before_arrival":   dir = "avant l'arrivée"
        case "after_arrival":    dir = "après l'arrivée"
        case "before_departure": dir = "avant le départ"
        case "after_departure":  dir = "après le départ"
        default:                 dir = ""
        }
        guard n > 0 else {
            return unit == "j" ? "0 jour" : "0 heure"
        }
        return "\(n) \(unit) \(dir)"
    }

    // MARK: - Sauvegarde

    private func doSave() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        // Conditions triées + plateformes triées → chaîne conforme au relevé backend.
        // Aller-retour garanti : SendConditionComponents.selfTest() valide le round-trip.
        let allTokens = conditions.sorted() + platforms.sorted()
        let sendCondition = allTokens.isEmpty ? "always" : allTokens.joined(separator: ",")

        // property_ids = [] signifie "tous les logements" — jamais remplacé par une
        // liste explicite : si scopeIsAll, on envoie [] quelle que soit selectedIds.
        let finalPropertyIds: [String] = scopeIsAll ? [] : Array(selectedIds).sorted()

        // abs() : normalise les valeurs négatives héritées — le serveur les
        // traite déjà comme positives (Math.abs dans le moteur d'envoi).
        let body = TemplateWriteBody(
            title:              title.trimmingCharacters(in: .whitespaces),
            message:            message,
            triggerType:        triggerType,
            triggerOffsetDays:  abs(offsetDays),
            triggerOffsetHours: abs(offsetHours),
            sendCondition:      sendCondition,
            propertyIds:        finalPropertyIds,
            active:             active
        )

        do {
            let updated = try await vm.saveTemplate(id: templateId, body: body)
            onSave(updated)
            dismiss()
        } catch {
            saveError = templateSaveErrorMessage(error)
        }
    }
}

// MARK: - Trigger types

private enum EditTriggerType: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case beforeArrival   = "before_arrival"
    case onArrival       = "on_arrival"
    case afterArrival    = "after_arrival"
    case beforeDeparture = "before_departure"
    case onDeparture     = "on_departure"
    case afterDeparture  = "after_departure"
    case onBooking       = "on_booking"

    var label: String {
        switch self {
        case .beforeArrival:   return "Avant l'arrivée"
        case .onArrival:       return "À l'arrivée"
        case .afterArrival:    return "Après l'arrivée"
        case .beforeDeparture: return "Avant le départ"
        case .onDeparture:     return "Au départ"
        case .afterDeparture:  return "Après le départ"
        case .onBooking:       return "À la réservation"
        }
    }
}

// MARK: - Éditeur de texte avec suivi de curseur

// Classe de référence passée de TemplateEditView à CursorTextEditor et VariablePickerSheet.
// L'insertion se fait directement dans UITextView à la position du curseur.
final class InsertionProxy {
    weak var textView: UITextView?

    func insert(_ text: String) {
        guard let tv = textView else { return }
        let range = tv.selectedTextRange ?? {
            let end = tv.endOfDocument
            return tv.textRange(from: end, to: end)
        }()
        if let range {
            tv.replace(range, withText: text)
        }
    }
}

struct CursorTextEditor: UIViewRepresentable {
    @Binding var text: String
    let proxy: InsertionProxy

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.systemFont(ofSize: 14.5)
        tv.textColor = UIColor(Color.bhCorps)
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        proxy.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorTextEditor
        init(_ p: CursorTextEditor) { parent = p }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            // Scroll to keep cursor visible after each keystroke.
            if let range = tv.selectedTextRange {
                let rect = tv.caretRect(for: range.end)
                tv.scrollRectToVisible(rect.insetBy(dx: 0, dy: -8), animated: false)
            }
        }
    }
}

// MARK: - Sélecteur de variables

// Les 15 variables relevées dans server.js (handler sendTemplateMessage).
// Source : docs/releves/mon-compte.md §7 (ligne 661-663).
private struct VariablePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onInsert: (String) -> Void

    private let groups: [(title: String, items: [(token: String, label: String, note: String?)])] = [
        ("Voyageur", [
            ("{prenom}",        "Prénom",               nil),
            ("{nom}",           "Nom",                  nil),
        ]),
        ("Séjour", [
            ("{arrivee}",       "Date d'arrivée",       nil),
            ("{depart}",        "Date de départ",       nil),
            ("{heure_arrivee}", "Heure d'arrivée",      nil),
            ("{heure_depart}",  "Heure de départ",      nil),
        ]),
        ("Logement", [
            ("{logement}",      "Nom du logement",      nil),
            ("{adresse}",       "Adresse",              nil),
            ("{instructions}",  "Instructions",         nil),
            ("{livret}",        "Livret d'accueil",     nil),
        ]),
        ("Accès", [
            ("{code_acces}",    "Code d'accès",         nil),
            ("{code_serrure}",  "Code serrure",         "Requiert Igloohome"),
            ("{wifi_nom}",      "Nom Wi-Fi",            nil),
            ("{wifi_mdp}",      "Mot de passe Wi-Fi",   nil),
        ]),
        ("Paiement", [
            ("{caution_url}",   "Lien caution",         "Réservations avec caution uniquement"),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.items, id: \.token) { v in
                                Button {
                                    onInsert(v.token)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(v.label)
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.bhEncre)
                                            if let note = v.note {
                                                Text(note)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.bhTerracotta)
                                            }
                                        }
                                        Spacer()
                                        Text(v.token)
                                            .font(.system(size: 12.5, design: .monospaced))
                                            .foregroundStyle(Color.bhVert)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Insérer une variable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Color.bhVert)
                }
            }
        }
    }
}

// MARK: - Formatage des erreurs API

private func templateSaveErrorMessage(_ error: Error) -> String {
    if let e = error as? APIError {
        switch e {
        case .server(_, let msg?): return msg
        case .network:             return "Connexion impossible. Vérifiez votre réseau."
        default:                   break
        }
    }
    return "Une erreur est survenue. Réessayez."
}
