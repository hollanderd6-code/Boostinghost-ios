import SwiftUI

// Feuille de réorganisation des logements par glisser-déposer.
// L'ordre n'est soumis au backend qu'à la validation — pas de mise à jour optimiste.

struct PropertyReorderSheet: View {
    var vm: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftOrder: [PropertySummary] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(draftOrder) { prop in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(Color.bhAttenue)
                            .imageScale(.medium)
                        Text(prop.displayName)
                            .font(.bhCorps)
                            .foregroundStyle(Color.bhEncre)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    draftOrder.move(fromOffsets: source, toOffset: destination)
                    #if DEBUG
                    print("[CALORDER] draft after move = \(draftOrder.map(\.displayName))")
                    #endif
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordre des logements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Terminé") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let msg = errorMessage {
                    errorBanner(msg)
                }
            }
        }
        .onAppear {
            draftOrder = vm.properties
            #if DEBUG
            print("[CALORDER] original = \(draftOrder.map(\.displayName))")
            #endif
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        #if DEBUG
        print("[CALORDER] Terminé tapped — draft = \(draftOrder.map(\.displayName))")
        #endif
        do {
            try await vm.reorderProperties(draftOrder)
            dismiss()
        } catch {
            errorMessage = "Impossible de sauvegarder l'ordre. Réessayez."
        }
        isSaving = false
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.bhTerracotta)
            Text(message)
                .font(.bhCorps)
                .foregroundStyle(Color.bhEncre)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.bhTerracottaBd, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
