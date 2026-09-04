import SwiftUI

struct TeamListView: View {

    @State private var vm = TeamViewModel()
    @Environment(\.dismiss) private var dismiss

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
        .navigationDestination(for: SubAccount.self) { member in
            TeamMemberDetailView(member: member, teamVM: vm)
        }
        .task { await vm.load() }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
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

            VStack(spacing: 1) {
                Text(surTitle)
                    .font(.bhSurTitre)
                    .foregroundStyle(Color.bhAttenue)
                Text("Mon équipe et accès")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
            }

            Spacer()

            Color.clear.frame(width: 90, height: 1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private var surTitle: String {
        switch vm.loadState {
        case .loaded:
            let n = vm.members.count
            return "\(n) membre\(n == 1 ? "" : "s")"
        default:
            return " "
        }
    }

    // MARK: - Contenu principal

    @ViewBuilder
    private var content: some View {
        switch vm.loadState {
        case .idle, .loading:
            Spacer()
            ProgressView().tint(Color.bhAttenue)
            Spacer()

        case .failed(let msg):
            Spacer()
            Text(msg)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

        case .loaded:
            if vm.members.isEmpty {
                Spacer()
                Text("Aucun membre dans l'équipe.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    memberList
                        .padding(.horizontal, 18)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Liste des membres

    private var memberList: some View {
        VStack(spacing: 12) {
            ForEach(vm.members, id: \.id) { member in
                ListCard {
                    NavigationLink(value: member) {
                        memberRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func memberRow(_ member: SubAccount) -> some View {
        CardRow(verticalPadding: 16, showSeparator: false) {
            HStack(spacing: 14) {

                // Rond d'initiales 40×40
                ZStack {
                    Circle()
                        .fill(Color(hex: "#DCE8E1"))
                        .frame(width: 40, height: 40)
                    Text(member.initials.isEmpty ? "?" : member.initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.bhVert)
                }

                // Nom + e-mail
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(member.displayName.isEmpty ? member.email ?? "—" : member.displayName)
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(Color.bhEncre)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if !member.isActive {
                            StatusPill(text: "inactif", style: .neutre)
                        }
                    }
                    Text(member.email ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                // Chevron décoratif
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.bhAttenue.opacity(0.55))
            }
        }
    }
}
