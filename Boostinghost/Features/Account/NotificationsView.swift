import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = NotificationsViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                content
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
        .alert("Erreur", isPresented: Binding(
            get: { vm.saveError != nil },
            set: { if !$0 { vm.saveError = nil } }
        )) {
            Button("OK") { vm.saveError = nil }
        } message: {
            Text(vm.saveError ?? "")
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        ZStack {
            Text("Notifications")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
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
        .padding(.vertical, 14)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        switch vm.viewState {
        case .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()

        case .subAccountRestricted:
            Spacer()
            Text("Les préférences de notifications ne sont pas disponibles pour les sous-comptes.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

        case .failed:
            Spacer()
            Text("Impossible de charger les préférences.")
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

        case .loaded:
            ScrollView(showsIndicators: false) {
                prefList
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    private var prefList: some View {
        let prefs = NotificationsViewModel.preferences
        return ListCard {
            ForEach(Array(prefs.enumerated()), id: \.offset) { idx, pref in
                CardRow(showSeparator: idx < prefs.count - 1) {
                    HStack {
                        Text(pref.label)
                            .font(.system(size: 15.5))
                            .foregroundStyle(Color.bhEncre)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.value(for: pref.key) },
                            set: { _ in Task { await vm.toggle(key: pref.key) } }
                        ))
                        .labelsHidden()
                        .tint(Color.bhVert)
                    }
                }
            }
        }
    }
}
