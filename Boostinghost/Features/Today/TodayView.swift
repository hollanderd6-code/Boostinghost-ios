import SwiftUI

// MARK: - Écran principal

struct TodayView: View {
    @Environment(AuthStore.self) var authStore
    var onSwitchToCalendar: () -> Void = {}

    @State private var vm = TodayViewModel()
    @State private var showAccount = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                switch vm.state {
                case .idle, .loading:
                    loadingView
                case .subscriptionRequired:
                    subscriptionView
                case .error(let msg):
                    errorView(msg)
                case .loaded:
                    loadedContent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .safeAreaInset(edge: .top, spacing: 0) { navBar }
        .refreshable { await reload() }
        .task { await reload() }
        .onChange(of: authStore.agencyContext) { Task { await reload() } }
        .sheet(isPresented: $showAccount) {
            AccountSheet()
        }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
        GlassNavBar(
            superTitle: Formatters.day(Date()),
            title: "Aujourd'hui"
        ) {
            HStack(spacing: 10) {
                GlassCircleButton(icon: "magnifyingglass") { }
                InitialsButton {
                    showAccount = true
                }
            }
        }
    }

    // MARK: - Contenu chargé

    @ViewBuilder
    private var loadedContent: some View {
        countersStrip

        calendarStrip

        if !vm.urgentArrivees.isEmpty {
            SectionLabel(text: "À traiter maintenant")
            ForEach(vm.urgentArrivees) { a in
                UrgentArrivalCard(arrivee: a)
            }
        }

        if !vm.normalArrivees.isEmpty {
            SectionLabel(text: "Arrivées")
            ForEach(vm.normalArrivees) { a in
                ArrivalCard(arrivee: a)
            }
        }

        if !vm.departs.isEmpty {
            SectionLabel(text: "Départs")
            ForEach(vm.departs) { d in
                DepartCard(depart: d)
            }
        }

        if !vm.assignments.isEmpty {
            SectionLabel(text: "Ménages du jour")
            ForEach(vm.assignments) { a in
                CleaningRow(assignment: a)
            }
        }

        if vm.allSectionsEmpty {
            Text("Rien à signaler pour aujourd'hui.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 40)
        }
    }

    // MARK: - Trois compteurs

    private var countersStrip: some View {
        HStack(spacing: 12) {
            CounterCard(
                value: vm.compteurs?.arrivees ?? 0,
                label: "Arrivées",
                icon: "arrow.down.right.circle"
            )
            CounterCard(
                value: vm.compteurs?.departs ?? 0,
                label: "Départs",
                icon: "arrow.up.right.circle"
            )
            aTraiterCounter
        }
    }

    private var aTraiterCounter: some View {
        let count = vm.compteurs?.aTraiter ?? 0
        let urgent = count > 0
        return VStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
                .opacity(urgent ? 1 : 0)
            Text("\(count)")
                .font(.system(size: 26, weight: .bold))
            Text("À traiter")
                .font(.bhMeta)
        }
        .foregroundStyle(urgent ? Color.bhTerracotta : Color.bhEncre)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            urgent
                ? Color(red: 253/255, green: 240/255, blue: 236/255).opacity(0.72)
                : Color.white.opacity(0.30),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    urgent ? Color.bhTerracottaBd : Color.white.opacity(0.50),
                    lineWidth: 1
                )
        }
        .animation(.easeInOut(duration: 0.2), value: urgent)
    }

    // MARK: - Bande calendrier

    private var calendarStrip: some View {
        ListCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 10) {
                // En-tête mois
                HStack {
                    Text(stripMonthHeader)
                        .bhIntertitre()
                    Spacer()
                    Button { onSwitchToCalendar() } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.bhAttenue)
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                // 7 cases
                HStack(spacing: 3) {
                    ForEach(vm.weekDays, id: \.self) { date in
                        DayCell(date: date, vm: vm)
                    }
                }
                .padding(.horizontal, 6)

                // Légende
                HStack(spacing: 14) {
                    legendItem(color: .bhOccupe,  label: "Occupé")
                    legendItem(color: .bhDepart,  label: "Départ")
                    legendItem(color: .bhOrClair, label: "Ménage")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            CalendarDot(color: color)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.bhAttenue)
        }
    }

    private var stripMonthHeader: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM"
        var seen = Set<Int>()
        var names: [String] = []
        for date in vm.weekDays {
            let m = Calendar.current.component(.month, from: date)
            if seen.insert(m).inserted {
                names.append(f.string(from: date).uppercased())
            }
        }
        return names.joined(separator: " · ")
    }

    private func reload() async {
        vm.agencyAll = authStore.agencyAll
        await vm.load()
    }

    // MARK: - États de chargement

    private var loadingView: some View {
        HStack { Spacer(); ProgressView(); Spacer() }
            .padding(.top, 60)
    }

    private var subscriptionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.circle")
                .font(.system(size: 44))
                .foregroundStyle(Color.bhAttenue)
            Text("Aucun abonnement actif")
                .font(.bhTitreLigne)
                .foregroundStyle(Color.bhEncre)
            Text("Contactez Boostinghost pour activer votre compte.")
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Color.bhAttenue)
            Text(msg)
                .font(.bhCorps)
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
            Button("Réessayer") { Task { await reload() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.bhVert)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Compteur simple

private struct CounterCard: View {
    let value: Int
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(Color.bhAttenue)
            Text("\(value)")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.bhEncre)
            Text(label)
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.50), lineWidth: 1)
        }
    }
}

// MARK: - Case de la bande calendrier

private struct DayCell: View {
    let date: Date
    let vm: TodayViewModel

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var dots: [Color] {
        guard isToday else { return [] }
        var d: [Color] = []
        if (vm.compteurs?.arrivees ?? 0) > 0 { d.append(.bhOccupe) }
        if (vm.compteurs?.departs ?? 0)  > 0 { d.append(.bhDepart) }
        if !vm.assignments.isEmpty             { d.append(.bhOrClair) }
        return d
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(Formatters.dayAbbrev(date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isToday ? Color(hex: "#9CCBB8") : Color.bhAttenue)

            Text(Formatters.dayNumber(date))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isToday ? Color.white : Color.bhEncre)

            HStack(spacing: 3) {
                ForEach(dots.prefix(3), id: \.self) { color in
                    CalendarDot(color: color)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isToday ? Color.bhVert : Color.clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}

// MARK: - Carte arrivée urgente (blocking non vide)

private struct UrgentArrivalCard: View {
    let arrivee: Arrivee

    var body: some View {
        UrgentCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(arrivee.guestName)
                        .font(.bhTitreLigneL)
                        .foregroundStyle(Color.bhEncre)
                    Spacer()
                    PlatformBadge(platform: arrivee.platform)
                }

                HStack(spacing: 4) {
                    Text(arrivee.propertyName)
                    if let t = Formatters.time(arrivee.arrivalTime) { Text("·"); Text(t) }
                    if let n = nightsLabel(arrivee.nights) { Text("·"); Text(n) }
                }
                .font(.bhMeta)
                .foregroundStyle(Color.bhAttenue)

                // Pastilles de blocage (motifs connus uniquement)
                let labels = arrivee.blocking.compactMap(blockingLabel)
                if !labels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(labels, id: \.self) { StatusPill(text: $0, style: .terracotta) }
                    }
                }

                // Actions
                VStack(spacing: 8) {
                    PrimaryButton(title: primaryAction(for: arrivee)) { }
                    GlassButton(title: "Écrire", icon: "bubble.left") { }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Carte arrivée normale (blocking vide)

private struct ArrivalCard: View {
    let arrivee: Arrivee

    var body: some View {
        ListCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(arrivee.guestName)
                            .font(.bhTitreLigne)
                            .foregroundStyle(Color.bhEncre)
                        HStack(spacing: 4) {
                            Text(arrivee.propertyName)
                            if let t = Formatters.time(arrivee.arrivalTime) { Text("·"); Text(t) }
                            if let n = nightsLabel(arrivee.nights) { Text("·"); Text(n) }
                        }
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                    }
                    Spacer()
                    PlatformBadge(platform: arrivee.platform)
                }

                HStack(spacing: 6) {
                    if arrivee.policeFormSigned == true {
                        StatusPill(text: "Fiche signée",   style: .vert, icon: "checkmark.circle")
                    }
                    if arrivee.codesSent == true {
                        StatusPill(text: "Codes envoyés",  style: .vert, icon: "key.fill")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Carte départ

private struct DepartCard: View {
    let depart: Depart

    var body: some View {
        ListCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(depart.guestName)
                        .font(.bhTitreLigne)
                        .foregroundStyle(Color.bhEncre)
                    HStack(spacing: 4) {
                        Text(depart.propertyName)
                        if let t = Formatters.time(depart.departureTime) { Text("·"); Text(t) }
                        if let n = nightsLabel(depart.nights) { Text("·"); Text(n) }
                    }
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                }
                Spacer()
                PlatformBadge(platform: depart.platform)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Ligne ménage

private struct CleaningRow: View {
    let assignment: CleaningAssignment

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.resolvedPropertyName ?? assignment.propertyId ?? "—")
                    .font(.bhTitreLigne)
                    .foregroundStyle(Color.bhEncre)
                if let name = assignment.cleanerName, !name.isEmpty {
                    Text(name)
                        .font(.bhMeta)
                        .foregroundStyle(Color.bhAttenue)
                }
            }
            Spacer()
            if let s = assignment.windowStart, let e = assignment.windowEnd,
               let sf = Formatters.time(s), let ef = Formatters.time(e) {
                Text("\(sf) – \(ef)")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundStyle(Color.bhAttenue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background { GlassCardBackground(cornerRadius: 16) }
    }
}

// MARK: - Helpers

private func nightsLabel(_ n: Int?) -> String? {
    guard let n else { return nil }
    return n == 1 ? "1 nuit" : "\(n) nuits"
}

private func blockingLabel(_ motif: String) -> String? {
    switch motif {
    case "pas_de_conversation":        return "Pas de conversation"
    case "ia_a_passe_la_main":         return "IA a passé la main"
    case "message_non_lu":             return "Message non lu"
    case "code_acces_manquant":        return "Code d'accès manquant"
    case "reservation_non_confirmee":  return "Non confirmée"
    default:                           return nil
    }
}

private func primaryAction(for arrivee: Arrivee) -> String {
    if arrivee.blocking.contains("pas_de_conversation") { return "Créer une conversation" }
    if arrivee.blocking.contains("code_acces_manquant") { return "Envoyer les codes" }
    return "Voir la réservation"
}

// MARK: - Extension Arrivee pour accès aux champs optionnels non déclarés

private extension Arrivee {
    var policeFormSigned: Bool? { nil }   // À compléter quand la route les renverra
    var codesSent: Bool? { nil }
}
