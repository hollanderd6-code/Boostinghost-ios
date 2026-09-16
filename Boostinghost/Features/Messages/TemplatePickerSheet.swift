import SwiftUI

// MARK: - Feuille de sélection de template

struct TemplatePickerSheet: View {
    let conversation: Conversation
    let vm: ConversationDetailViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var templates: [MessageTemplateItem] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var sendingId: Int? = nil
    @State private var sendError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    VStack(spacing: 12) {
                        Text(err)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhAttenue)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") { Task { await loadTemplates() } }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.bhVert)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if templates.isEmpty {
                    Text("Aucun template disponible pour ce logement.")
                        .font(.bhCorps)
                        .foregroundStyle(Color.bhAttenue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    templateList
                }
            }
            .navigationTitle("Envoyer un template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .alert("Erreur", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("OK") { sendError = nil }
        } message: {
            Text(sendError ?? "")
        }
        .task { await loadTemplates() }
    }

    // MARK: - Liste

    private var templateList: some View {
        List {
            // on_arrival en tête, le reste suit dans l'ordre d'origine
            let sorted = templates.sorted { a, _ in a.triggerType == "on_arrival" }
            ForEach(sorted) { template in
                templateRow(template)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func templateRow(_ template: MessageTemplateItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                Text(template.triggerLabel)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
            Spacer(minLength: 8)
            if sendingId == template.id {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Button {
                    Task { await send(template) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.bhVert, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(sendingId != nil)
            }
        }
        .contentShape(Rectangle())
        .opacity(sendingId != nil && sendingId != template.id ? 0.4 : 1)
    }

    // MARK: - Réseau

    private func loadTemplates() async {
        isLoading = true
        loadError = nil
        do {
            let extra: [URLQueryItem] = conversation.propertyId.map {
                [URLQueryItem(name: "property_id", value: $0)]
            } ?? []
            let r: MessageTemplatesResponse = try await APIClient.shared.get(
                Endpoint.messageTemplates,
                extraQueryItems: extra
            )
            templates = r.templates.filter { $0.active }
        } catch {
            loadError = "Impossible de charger les templates."
        }
        isLoading = false
    }

    private func send(_ template: MessageTemplateItem) async {
        sendingId = template.id
        defer { sendingId = nil }
        do {
            try await vm.sendTemplate(id: template.id)
            dismiss()
        } catch {
            sendError = "Envoi échoué. Vérifiez votre connexion."
        }
    }
}
