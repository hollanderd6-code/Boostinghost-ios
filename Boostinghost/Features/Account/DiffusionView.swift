import SwiftUI

// MARK: - Plateformes connectées
//
// Règle : aucun nom de prestataire de distribution (Airbnb, Booking…) dans cet écran.
// On parle du logement et de sa diffusion uniquement.

struct DiffusionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = DiffusionViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch vm.loadState {
                        case .loading:
                            HStack { Spacer(); ProgressView().tint(Color.bhAttenue); Spacer() }
                                .padding(.top, 40)
                        case .failed:
                            Text("Impossible de charger les données.")
                                .font(.bhCorps)
                                .foregroundStyle(Color.bhAttenue)
                                .padding(.top, 40)
                        case .loaded:
                            if let d = vm.diffusion {
                                summaryCard(d)
                                let issues = d.logements.filter { $0.aRegler > 0 }
                                if !issues.isEmpty {
                                    issuesSection(issues)
                                }
                                // total − logements listés ci-dessus = logements sans problème
                                let ok = d.total - issues.count
                                if ok > 0 {
                                    okLine(count: ok)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { await vm.load() }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        ZStack {
            // Titre centré — réduit si nécessaire pour tenir sur une ligne
            Text("Diffusion")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 110) // réserve de place pour le bouton retour

            // Bouton retour ancré à gauche
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

    // MARK: - Résumé

    private func summaryCard(_ d: DiffusionResponse) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                VStack(alignment: .leading, spacing: 5) {
                    let diffLabel = d.diffuses == 1
                        ? "1 logement diffusé sur \(d.total)"
                        : "\(d.diffuses) logements diffusés sur \(d.total)"
                    Text(diffLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.bhEncre)
                    let readyLabel = d.vendables == 1
                        ? "dont 1 prêt à la vente"
                        : "dont \(d.vendables) prêts à la vente"
                    Text(readyLabel)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Logements à corriger

    private func issuesSection(_ props: [DiffusionProperty]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "À corriger")
            ListCard {
                ForEach(Array(props.enumerated()), id: \.element.id) { idx, prop in
                    CardRow(showSeparator: idx < props.count - 1) {
                        issueRow(prop)
                    }
                }
            }
        }
    }

    private func issueRow(_ prop: DiffusionProperty) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prop.nom.isEmpty ? "Logement" : prop.nom)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            let points = vm.santeByProperty[prop.id] ?? []
            if points.isEmpty {
                Text("Chargement…")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            } else {
                ForEach(points.indices, id: \.self) { i in
                    // titre décrit l'état souhaité (positif), pas l'état constaté.
                    // On affiche details, qui formule le problème réel.
                    Text(failureDescription(for: points[i]))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Renvoie la description du problème pour un point en échec.
    // details est déjà formulé côté serveur comme un constat ("Ce logement n'est
    // connecté à aucune plateforme"). Si absent, repli sur la négation par clé.
    private func failureDescription(for point: SantePoint) -> String {
        if let d = point.details, !d.isEmpty { return d }
        switch point.cle {
        case "relie":      return "Non relié à une plateforme"
        case "calendrier": return "Calendrier non synchronisé"
        case "tarifs":     return "Tarifs non renseignés"
        case "caution":    return "Caution non configurée"
        default:           return point.titre
        }
    }

    // MARK: - Comptage sans problème

    private func okLine(count: Int) -> some View {
        ListCard {
            CardRow(showSeparator: false) {
                Text("\(count) logement\(count == 1 ? "" : "s") sans problème")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
