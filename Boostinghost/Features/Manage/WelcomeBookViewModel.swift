import Foundation
import SwiftUI

// MARK: - States

enum WelcomeBookState: Equatable {
    case idle
    case loading
    case notCreated
    case loaded(uniqueId: String, publicUrl: String, data: WelcomeBookData?)
    case creating
    case saving
    case failed(String)
}

// MARK: - ViewModel

@MainActor
final class WelcomeBookViewModel: ObservableObject {

    @Published private(set) var state: WelcomeBookState = .idle
    @Published private(set) var saveError: String? = nil
    @Published var welcomeDescription: String = ""
    @Published var checkoutInstructions: String = ""

    private let propertyId: String
    private var uniqueId: String?

    init(propertyId: String) {
        self.propertyId = propertyId
    }

    var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    var publicUrl: URL? {
        if case .loaded(_, let urlStr, _) = state {
            return URL(string: urlStr)
        }
        return nil
    }

    var rooms: [WelcomeBookRoom] {
        if case .loaded(_, _, let data) = state {
            return data?.rooms ?? []
        }
        return []
    }

    // MARK: - Fetch

    func fetch() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let resp: WelcomeBookResponse = try await APIClient.shared.get(
                Endpoint.welcomeBookByProperty(propertyId), agencyAll: true
            )
            if resp.exists, let uid = resp.uniqueId, let urlStr = resp.publicUrl {
                uniqueId = uid
                welcomeDescription   = resp.data?.welcomeDescription   ?? ""
                checkoutInstructions = resp.data?.checkoutInstructions ?? ""
                state = .loaded(uniqueId: uid, publicUrl: urlStr, data: resp.data)
            } else {
                state = .notCreated
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        state = .idle
        await fetch()
    }

    // MARK: - Create

    func create() async {
        guard case .notCreated = state else { return }
        state = .creating
        do {
            let resp: WelcomeBookCreateResponse = try await APIClient.shared.post(
                Endpoint.welcomeBookCreate,
                body: WelcomeBookCreateRequest(propertyId: propertyId),
                agencyAll: true
            )
            guard resp.success, let uid = resp.uniqueId,
                  let urlStr = resp.publicUrl ?? resp.url else {
                state = .failed("Création échouée")
                return
            }
            uniqueId = uid
            state = .loaded(uniqueId: uid, publicUrl: urlStr, data: nil)
        } catch let err as APIError {
            state = .failed(err.userMessage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Save extras (welcmeDescription, checkoutInstructions)

    func saveExtras() async {
        guard case .loaded(let uid, let url, let existingData) = state,
              !uid.isEmpty else { return }
        state = .saving
        saveError = nil
        do {
            let body = WelcomeBookExtrasRequest(
                welcomeDescription:   welcomeDescription,
                checkoutInstructions: checkoutInstructions
            )
            let resp: WelcomeBookExtrasResponse = try await patchExtras(uniqueId: uid, body: body)
            guard resp.success else {
                state = .loaded(uniqueId: uid, publicUrl: url, data: existingData)
                saveError = "Erreur de sauvegarde. Vérifiez votre connexion et réessayez."
                return
            }
            // Recréer data fusionnée localement pour ne pas perdre rooms
            let merged = WelcomeBookData(
                welcomeDescription:   welcomeDescription,
                checkoutInstructions: checkoutInstructions,
                contactPhone:         existingData?.contactPhone,
                rooms:                existingData?.rooms
            )
            state = .loaded(uniqueId: uid, publicUrl: url, data: merged)
            saveError = nil
        } catch let err as APIError {
            if case .loaded(let uid, let url, let existingData) = state {
                state = .loaded(uniqueId: uid, publicUrl: url, data: existingData)
            }
            saveError = err.userMessage
        } catch {
            if case .loaded(let uid, let url, let existingData) = state {
                state = .loaded(uniqueId: uid, publicUrl: url, data: existingData)
            }
            saveError = "Erreur de sauvegarde. Vérifiez votre connexion et réessayez."
        }
    }

    private func patchExtras(uniqueId: String, body: WelcomeBookExtrasRequest) async throws -> WelcomeBookExtrasResponse {
        return try await APIClient.shared.patch(
            Endpoint.welcomeBookExtras(uniqueId),
            body: body,
            agencyAll: true
        )
    }
}

