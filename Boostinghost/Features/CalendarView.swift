import SwiftUI

struct CalendarView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(CalendarViewModel.self) private var vm
    @State private var tab = CalendarTab.planning

    var body: some View {
        VStack(spacing: 0) {
            CalendarNavBar(vm: vm, tab: $tab)

            ScrollView {
                Group {
                    if tab == .planning {
                        planningContent
                    } else {
                        revenus
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                await vm.reload()
                if tab == .revenus {
                    vm.clearReporting()
                    await vm.loadReporting()
                }
            }
        }
        .task {
            vm.agencyAll = authStore.agencyAll
            await vm.load()
            // Si le mode persisté est single, charger les prix immédiatement.
            if case .single(let id) = vm.displayMode, !authStore.agencyAll {
                await vm.loadPricing(for: id)
            }
        }
        .onChange(of: authStore.agencyAll) { _, new in
            vm.agencyAll = new
            Task { await vm.reload() }
        }
        .onChange(of: vm.displayMode) { _, newMode in
            // Charger les prix au passage en mode logement unique (Planning seulement,
            // et uniquement pour les logements du compte connecté — pas de support agence
            // sur /api/host/pricing/*).
            if case .single(let id) = newMode, tab == .planning, !authStore.agencyAll {
                Task { await vm.loadPricing(for: id) }
            } else {
                vm.clearPricing()
            }
        }
    }

    // MARK: Contenu Planning

    @ViewBuilder
    private var planningContent: some View {
        switch vm.loadState {
        case .idle, .loading:
            ProgressView()
                .padding(.top, 80)
                .tint(Color.bhVert)

        case .error(let msg):
            ContentUnavailableView(msg, systemImage: "wifi.exclamationmark")
                .padding(.top, 60)

        case .loaded:
            switch vm.displayMode {
            case .allGrid:
                MonthGridView(vm: vm)
            case .allLines, .single:
                TimelineView(vm: vm)
            }
        }
    }

    // MARK: Revenus

    private var revenus: some View {
        RevenusView(vm: vm)
    }
}
