import SwiftUI

// MARK: - Feuille de note interne

struct NoteSheet: View {
    let vm: ConversationDetailViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var isSaving = false
    @State private var saveError: String? = nil

    init(vm: ConversationDetailViewModel) {
        self.vm = vm
        _text = State(initialValue: vm.currentNote ?? "")
    }

    private var hasChanged: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = vm.currentNote ?? ""
        return trimmed != current
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $text)
                    .font(.bhCorps)
                    .foregroundStyle(Color.bhEncre)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Visible uniquement par votre équipe. Laisser vide pour supprimer la note.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .background(Color.bhGradientTop)
            .navigationTitle("Note interne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Enregistrer") { Task { await save() } }
                            .font(.system(size: 15, weight: .semibold))
                            .disabled(!hasChanged)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .alert("Erreur", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Réseau

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await vm.saveNote(text.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            saveError = "Sauvegarde échouée. Vérifiez votre connexion."
        }
    }
}
