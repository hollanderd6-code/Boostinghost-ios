import SwiftUI

struct AccountSwitcherSheet: View {
    var onComplete: () -> Void = {}

    @Environment(AuthStore.self) var authStore
    @State private var switching: String? = nil
    @State private var switchError: String? = nil

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                handle
                sheetTitle
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ownRow
                        rowDivider
                        allAccountsRow
                        if authStore.canActAsAgent && !authStore.delegations.isEmpty {
                            delegationsSectionHeader
                            ForEach(authStore.delegations) { delegation in
                                rowDivider
                                delegationRow(delegation)
                            }
                        }
                    }
                    .padding(.top, 4)
                    if let switchError {
                        Text(switchError)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhTerracotta)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var handle: some View {
        Capsule()
            .fill(Color.bhAttenue.opacity(0.3))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 20)
    }

    private var sheetTitle: some View {
        Text("Changer de compte")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.bhEncre)
            .padding(.bottom, 20)
    }

    // MARK: - Section 1 — Mon compte

    private var ownRow: some View {
        let isActive = authStore.agencyContext == .own
        return Button {
            authStore.restoreOwnAccount()
            onComplete()
        } label: {
            HStack(spacing: 14) {
                initialsCircle(text: initials(for: authStore.session?.displayName ?? ""),
                               bg: Color(hex: "#DCE8E1"), fg: Color.bhVert)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mon compte")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text(authStore.session?.displayName ?? "")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
                Spacer()
                if isActive {
                    checkmark
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 2 — Tous les comptes

    private var allAccountsRow: some View {
        let isActive = authStore.agencyContext == .allAccounts
        return Button {
            authStore.switchToAllAccounts()
            onComplete()
        } label: {
            HStack(spacing: 14) {
                initialsCircle(icon: "building.2", bg: Color(hex: "#DCE8E1"), fg: Color.bhVert)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tous les comptes")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    Text("Vue agence complète")
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
                Spacer()
                if isActive {
                    checkmark
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section 3 — Comptes délégants

    private var delegationsSectionHeader: some View {
        HStack {
            Text("COMPTES DÉLÉGANTS")
                .bhIntertitre()
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private func delegationRow(_ delegation: Delegation) -> some View {
        let isActive: Bool = {
            guard case .delegating(let uid, _, _) = authStore.agencyContext else { return false }
            return uid == delegation.userId
        }()
        let isSwitching = switching == delegation.userId

        return Button {
            guard switching == nil else { return }
            Task {
                switching = delegation.userId
                switchError = nil
                do {
                    try await authStore.switchToAccount(delegation)
                    onComplete()
                } catch APIError.network(_) {
                    switchError = "Impossible de joindre le serveur. Vérifiez votre connexion."
                } catch APIError.server(let code, let msg) {
                    switchError = msg ?? "Erreur serveur (\(code))."
                } catch APIError.decoding(let e) {
                    switchError = "Erreur de décodage — consultez la console."
                    print("[switch] decode: \(e)")
                } catch {
                    switchError = "Erreur inattendue : \(error.localizedDescription)"
                }
                switching = nil
            }
        } label: {
            HStack(spacing: 14) {
                initialsCircle(text: initials(for: delegation.name),
                               bg: Color(hex: "#DCE8E1"), fg: Color.bhVert)
                VStack(alignment: .leading, spacing: 2) {
                    Text(delegation.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    if let count = delegation.propertyCount {
                        Text("\(count) logement\(count == 1 ? "" : "s")")
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }
                Spacer()
                if isSwitching {
                    ProgressView()
                        .tint(Color.bhAttenue)
                } else if isActive {
                    checkmark
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .opacity(switching != nil && !isSwitching ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(switching != nil && !isSwitching)
        .animation(.easeInOut(duration: 0.15), value: switching)
    }

    // MARK: - Sub-views

    private var rowDivider: some View {
        Divider().padding(.horizontal, 24)
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.bhVert)
    }

    @ViewBuilder
    private func initialsCircle(text: String? = nil, icon: String? = nil,
                                bg: Color, fg: Color) -> some View {
        ZStack {
            Circle().fill(bg).frame(width: 40, height: 40)
            if let text {
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(fg)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(fg)
            }
        }
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
