import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) var authStore
    @State private var vm = LoginViewModel()
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground(expandedHalos: true)

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        brandBlock
                        Spacer(minLength: 0).frame(height: 34)
                        cardBlock
                        errorBlock
                        forgotPasswordButton
                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 26)
                    .frame(minHeight: geo.size.height - 60)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            footerBlock
        }
        .ignoresSafeArea()
    }

    // MARK: - Marque

    private var brandBlock: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.bhVert)
                .frame(width: 66, height: 66)
                .overlay {
                    Text("B")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(
                    color: Color(red: 14/255, green: 59/255, blue: 46/255).opacity(0.32),
                    radius: 15, x: 0, y: 12
                )

            Spacer().frame(height: 16)

            Text("Boostinghost")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Color.bhEncre)

            Spacer().frame(height: 5)

            Text("Gérez vos logements depuis votre poche")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Carte de connexion (verre franc)

    private var cardBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            // E-mail
            VStack(alignment: .leading, spacing: 6) {
                Text("ADRESSE E-MAIL")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(0.09 * 11.5)
                    .foregroundStyle(Color.bhAttenue)

                TextField("", text: $vm.email)
                    .font(.system(size: 16))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
                    .fieldStyle()
            }

            // Mot de passe
            VStack(alignment: .leading, spacing: 6) {
                Text("MOT DE PASSE")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(0.09 * 11.5)
                    .foregroundStyle(Color.bhAttenue)

                HStack(spacing: 0) {
                    Group {
                        if vm.showPassword {
                            TextField("", text: $vm.password)
                                .font(.system(size: 16))
                                .textContentType(.password)
                        } else {
                            SecureField("", text: $vm.password)
                                .font(.system(size: 18))
                                .textContentType(.password)
                        }
                    }
                    .focused($focus, equals: .password)
                    .onSubmit {
                        focus = nil
                        Task { await vm.signIn(using: authStore) }
                    }

                    Button {
                        vm.showPassword.toggle()
                    } label: {
                        Image(systemName: vm.showPassword ? "eye" : "eye.slash")
                            .foregroundStyle(Color.bhAttenue)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .fieldStyle()
            }

            // Bouton Se connecter
            Button {
                focus = nil
                Task { await vm.signIn(using: authStore) }
            } label: {
                ZStack {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Se connecter")
                            .font(.system(size: 16.5, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Color.bhVert.opacity(vm.canSubmit ? 1 : 0.4),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSubmit)
            .animation(.easeInOut(duration: 0.15), value: vm.canSubmit)

            // Face ID — uniquement à partir de la seconde ouverture
            if authStore.hasBiometricToken {
                Button {
                    Task { await vm.signInWithFaceID(using: authStore) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Utiliser Face ID")
                            .font(.system(size: 15.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.bhVert)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
            }
        }
        .padding(22)
        .glassEffect(in: .rect(cornerRadius: 28))
        .specularEdge(cornerRadius: 28)
        .chromeShadow()
    }

    // MARK: - Erreur

    @ViewBuilder
    private var errorBlock: some View {
        if let msg = vm.errorMessage {
            Text(msg)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhTerracotta)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .transition(.opacity)
        }
    }

    // MARK: - Mot de passe oublié

    private var forgotPasswordButton: some View {
        Button("Mot de passe oublié ?") { }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.bhVert)
            .padding(.top, 22)
    }

    // MARK: - Pied de page

    private var footerBlock: some View {
        Text("Boostinghost 3.2 · CGU · Confidentialité")
            .font(.system(size: 12.5))
            .foregroundStyle(Color.bhAttenue)
            .padding(.bottom, 26)
    }
}

// MARK: - Style de champ de saisie

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(
                        Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.05),
                        lineWidth: 1
                    )
            }
    }
}
