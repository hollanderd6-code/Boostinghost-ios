import SwiftUI
import WebKit

// MARK: - Models (partagés avec PropertyDetailView)

struct ConnectedChannel: Decodable, Identifiable {
    let id: String
    let channel: String   // "airbnb" | "bookingcom" | "expedia" | "vrbo"
    let title: String     // "Airbnb" | "Booking.com" | "Expedia" | "Abritel"
    let status: String    // toujours "" côté serveur — les canaux inactifs sont filtrés

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id      = c.flexString(forKey: .id)  ?? UUID().uuidString
        channel = (try? c.decodeIfPresent(String.self, forKey: .channel)) ?? ""
        title   = (try? c.decodeIfPresent(String.self, forKey: .title))   ?? ""
        status  = (try? c.decodeIfPresent(String.self, forKey: .status))  ?? ""
    }

    private enum CodingKeys: CodingKey { case id, channel, title, status }
}

struct ConnectedChannelsResponse: Decodable {
    let channels: [ConnectedChannel]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        channels = (try? c.decodeIfPresent([ConnectedChannel].self, forKey: .channels)) ?? []
    }

    private enum CodingKeys: CodingKey { case channels }
}

// MARK: - Modèles privés à ce fichier

// Seul avertissement nous intéresse : c'est lui qui signale prix manquant ou tarifs non poussés.
// success est redondant (HTTP 200 suffit) ; les autres champs sont ignorés.
private struct ConnectPropertyResponse: Decodable {
    let avertissement: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // decodeIfPresent + try? : si la clé est absente (cas normal), retourne nil sans erreur.
        avertissement = try? c.decodeIfPresent(String.self, forKey: .avertissement)
    }

    private enum CodingKeys: CodingKey { case avertissement }
}

private struct IframeTokenResponse: Decodable {
    // JSON key : "iframe_url" → convertFromSnakeCase → "iframeUrl"
    let iframeUrl: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        iframeUrl = (try? c.decodeIfPresent(String.self, forKey: .iframeUrl)) ?? ""
    }

    private enum CodingKeys: CodingKey { case iframeUrl }
}

private struct PropertyIdBody: Encodable {
    let propertyId: String
    private enum CodingKeys: String, CodingKey { case propertyId = "property_id" }
}

// MARK: - ViewModel

@Observable
@MainActor
final class PropertyDiffusionViewModel {
    enum Phase { case preparing, ready, failed }

    var phase: Phase = .preparing
    var iframeURL: URL?      = nil
    var warning: String?     = nil
    var errorMessage: String? = nil

    func prepare(property: Property) async {
        phase        = .preparing
        warning      = nil
        errorMessage = nil
        iframeURL    = nil  // efface toute URL d'une session précédente — le token est à usage unique

        // Condition miroir du serveur : 400 si channex_enabled = true ET channex_property_id non nul.
        // On vérifie les deux pour éviter d'appeler la route quand ce n'est pas nécessaire.
        let alreadyConnected = property.channexEnabled == true
            && !(property.channexPropertyId ?? "").isEmpty

        if !alreadyConnected {
            do {
                let resp: ConnectPropertyResponse = try await APIClient.shared.post(
                    Endpoint.channexConnect,
                    body: PropertyIdBody(propertyId: property.id),
                    agencyAll: true
                )
                if let w = resp.avertissement, !w.isEmpty {
                    warning = clean(w)
                }
            } catch let err as APIError {
                if case .server(let code, let msg) = err, code == 400 {
                    // N'ignorer le 400 que s'il signifie explicitement "déjà connecté" :
                    // le cache local peut être en retard d'une connexion faite dans un autre onglet.
                    // Tout autre 400 (property_id manquant, quota dépassé…) doit remonter.
                    let text = (msg ?? "").lowercased()
                    guard text.contains("déjà") || text.contains("already") else {
                        errorMessage = err.userMessage
                        phase = .failed
                        return
                    }
                    // "déjà connecté" : continuer vers iframe-token
                } else {
                    errorMessage = err.userMessage
                    phase = .failed
                    return
                }
            } catch {
                errorMessage = error.localizedDescription
                phase = .failed
                return
            }
        }

        // iframe-token est à usage unique : appelé à chaque présentation de la feuille.
        // Le ViewModel est recréé par SwiftUI à chaque ouverture (sheet isPresented),
        // et prepare() remet iframeURL à nil en tête — aucun token n'est conservé entre sessions.
        do {
            let resp: IframeTokenResponse = try await APIClient.shared.post(
                Endpoint.channexIframeToken,
                body: PropertyIdBody(propertyId: property.id),
                agencyAll: true
            )
            guard !resp.iframeUrl.isEmpty, let url = URL(string: resp.iframeUrl) else {
                errorMessage = "URL de gestion invalide."
                phase = .failed
                return
            }
            iframeURL = url
            phase = .ready
        } catch let err as APIError {
            errorMessage = err.userMessage
            phase = .failed
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    private func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "Channex", with: "le prestataire de diffusion", options: .caseInsensitive)
    }
}

// MARK: - WKWebView wrapper

private struct DiffusionWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        if wv.url == nil {
            wv.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: DiffusionWebView
        init(_ parent: DiffusionWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}

// MARK: - Feuille de gestion de la diffusion

struct PropertyDiffusionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let property: Property

    @State private var vm          = PropertyDiffusionViewModel()
    @State private var isWebLoading = false
    @State private var webError: String? = nil
    @State private var webViewID   = UUID()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                sheetHeader
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if case .ready = vm.phase {
                    actionBar
                }
            }
        }
        .presentationDetents([.large])
        .task { await vm.prepare(property: property) }
    }

    // MARK: - En-tête

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ZStack {
                VStack(spacing: 1) {
                    Text("Diffusion du logement")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                        .lineLimit(1)
                    Text(property.internalName ?? property.name)
                        .font(.bhSurTitre)
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 64)

                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.bhAttenue)
                            .frame(width: 30, height: 30)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 15)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
        }
    }

    // MARK: - Zone principale

    @ViewBuilder
    private var contentArea: some View {
        switch vm.phase {
        case .preparing:
            VStack(spacing: 14) {
                ProgressView()
                    .tint(Color.bhAttenue)
                    .scaleEffect(1.2)
                Text("Préparation…")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }

        case .failed:
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.bhTerracotta)
                Text(vm.errorMessage ?? "Impossible de préparer la gestion de la diffusion.")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

        case .ready:
            VStack(spacing: 0) {
                if let w = vm.warning {
                    warningBanner(w)
                }
                ZStack {
                    if let url = vm.iframeURL {
                        DiffusionWebView(url: url, isLoading: $isWebLoading, loadError: $webError)
                            .id(webViewID)
                    }
                    if isWebLoading {
                        ProgressView()
                            .tint(Color.bhAttenue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if let err = webError {
                        webErrorView(err)
                    }
                }
            }
        }
    }

    private func warningBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.bhOr)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.bhOr)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bhOrFond)
    }

    private func webErrorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.bhTerracotta)
            Text("Impossible de charger l'interface.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.bhEncre)
            Text(message)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button {
                webError  = nil
                webViewID = UUID()
            } label: {
                Text("Réessayer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .specularEdge(cornerRadius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Barre d'action basse

    private var actionBar: some View {
        VStack(spacing: 0) {
            Button { dismiss() } label: {
                Text("J'ai terminé")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
