import Foundation
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

    var canSubmit: Bool { !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading }

    // MARK: - Connexion par identifiants

    func signIn(using authStore: AuthStore) async {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authStore.signIn(email: email.trimmingCharacters(in: .whitespaces),
                                       password: password)
            // Succès : AuthStore met appState à .authenticated → navigation automatique.
        } catch let error as APIError {
            switch error {
            case .network:
                errorMessage = "Pas de connexion"
                // Conserver le mot de passe pour permettre de réessayer
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

    func signInWithFaceID(using authStore: AuthStore) async {
        let context = LAContext()
        var err: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await evaluate(context)
            guard success else { return }

            let hadToken = authStore.hasBiometricToken
            await authStore.verifyOnLaunch()

            // Biométrie réussie mais verify → 401 : session expirée.
            if hadToken && authStore.appState == .unauthenticated {
                errorMessage = "Votre session a expiré. Reconnectez-vous pour réactiver Face ID."
            }
        } catch {
            // Annulé ou biométrie non disponible — aucune erreur à afficher.
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
