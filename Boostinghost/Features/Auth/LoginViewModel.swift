import AuthenticationServices
import Foundation
import GoogleSignIn
import LocalAuthentication
import Observation

@MainActor
@Observable
final class LoginViewModel {

    var email    = ""
    var password = ""
    var isLoading    = false
    var showPassword = false
    var errorMessage: String? = nil
    var socialLoadingProvider: String? = nil

    var isSocialLoading: Bool { socialLoadingProvider != nil }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    private let appleCoordinator = AppleSignInCoordinator()

    // MARK: - Connexion par identifiants

    func signIn(using authStore: AuthStore) async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authStore.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                       password: password)
        } catch let error as APIError {
            switch error {
            case .network:
                errorMessage = "Pas de connexion"
            default:
                errorMessage = "Email ou mot de passe incorrect."
                password = ""
            }
        } catch {
            errorMessage = "Email ou mot de passe incorrect."
            password = ""
        }
    }

    // MARK: - Connexion par Face ID
    //
    // Replis couverts :
    //   • Appareil sans biométrie → hasBiometricToken = false, bouton masqué, jamais atteint
    //   • Face ID refusé dans Réglages → canEvaluatePolicy = false, idem
    //   • Annulation utilisateur / échec de reconnaissance → LAError silencieux, retour formulaire
    //   • Face ID bloqué (trop d'échecs) → message explicite
    //   • Session expirée sur le serveur → message demandant reconnexion par mot de passe
    //   • Pas de réseau → session cache utilisée par signInWithBiometrics, pas d'erreur affichée

    func signInWithFaceID(using authStore: AuthStore) async {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await evaluate(context)
            guard success else { return }
            try await authStore.signInWithBiometrics(context: context)
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .systemCancel, .appCancel, .authenticationFailed:
                break
            case .biometryLockout:
                errorMessage = "Face ID est bloqué. Déverrouillez votre appareil pour continuer."
            default:
                break
            }
        } catch APIError.unauthorized {
            errorMessage = "Session expirée. Reconnectez-vous avec votre mot de passe."
        } catch {
            // signInWithBiometrics absorbe les erreurs réseau et utilise le cache.
        }
    }

    // MARK: - Connexion sociale (Apple / Google)

    func signInWithApple(using authStore: AuthStore) async {
        guard !isSocialLoading else { return }
        socialLoadingProvider = "apple"
        errorMessage = nil
        defer { socialLoadingProvider = nil }
        do {
            let (idToken, name) = try await appleCoordinator.perform()
            try await authStore.signInWithSocial(provider: "apple", idToken: idToken, name: name)
        } catch let err as ASAuthorizationError where err.code == .canceled { }
        catch is CancellationError { }
        catch let error as APIError {
            switch error {
            case .network: errorMessage = "Pas de connexion"
            default:       errorMessage = "Connexion avec Apple impossible. Réessayez."
            }
        } catch { }
    }

    func signInWithGoogle(using authStore: AuthStore) async {
        guard !isSocialLoading else { return }
        socialLoadingProvider = "google"
        errorMessage = nil
        defer { socialLoadingProvider = nil }
        do {
            if GIDSignIn.sharedInstance.configuration == nil {
                let config: SocialConfigResponse = try await APIClient.shared.get(Endpoint.socialConfig)
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: config.googleIOS)
            }
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let rootVC = windowScene.keyWindow?.rootViewController else { return }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Connexion avec Google impossible. Réessayez."
                return
            }
            try await authStore.signInWithSocial(provider: "google", idToken: idToken,
                                                  name: result.user.profile?.name)
        } catch let err as GIDSignInError where err.code == .canceled { }
        catch let error as APIError {
            switch error {
            case .network: errorMessage = "Pas de connexion"
            default:       errorMessage = "Connexion avec Google impossible. Réessayez."
            }
        } catch {
            errorMessage = "Connexion avec Google impossible. Réessayez."
        }
    }

    // MARK: - Private

    private func evaluate(_ context: LAContext) async throws -> Bool {
        try await withCheckedThrowingContinuation { cont in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Accédez à votre espace Boostinghost"
            ) { success, error in
                if let error { cont.resume(throwing: error) }
                else         { cont.resume(returning: success) }
            }
        }
    }
}

// MARK: - Apple Sign-In coordinator

@MainActor
private final class AppleSignInCoordinator: NSObject,
        ASAuthorizationControllerDelegate,
        ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<(idToken: String, name: String?), Error>?

    func perform() async throws -> (idToken: String, name: String?) {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow ?? UIWindow()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                let cont = continuation; continuation = nil
                cont?.resume(throwing: ASAuthorizationError(.failed))
                return
            }
            let fn = cred.fullName
            let name = [fn?.givenName, fn?.familyName]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
            let cont = continuation; continuation = nil
            cont?.resume(returning: (idToken: idToken, name: name.isEmpty ? nil : name))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            let cont = continuation; continuation = nil
            cont?.resume(throwing: error)
        }
    }
}

// MARK: - Social config

private struct SocialConfigResponse: Decodable {
    let googleIOS: String
}

