import SwiftUI

struct CalendarView: View {
    @Binding var selectedTab: AppTab
    @Environment(AuthStore.self) private var authStore
    @Environment(CalendarViewModel.self) private var vm
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = CalendarTab.mensuel
    @State private var pollingTask: Task<Void, Never>?

    private var isCalendarTabActive: Bool { selectedTab == .calendar }

    var body: some View {
        VStack(spacing: 0) {
            CalendarNavBar(vm: vm, tab: $tab)

            ScrollView {
                Group {
                    switch tab {
                    case .jour:    JourView(vm: vm)
                    case .semaine: SemaineView(vm: vm)
                    case .mensuel: mensuelContent
                    case .revenus: RevenusView(vm: vm)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                await vm.reload()
                switch tab {
                case .revenus:
                    vm.clearReporting()
                    await vm.loadReporting()
                case .jour, .semaine, .mensuel:
                    await vm.loadCalendar()
                }
            }
        }
        .task {
            vm.agencyAll = authStore.agencyAll
            await vm.load()
            if tab == .jour || tab == .semaine || tab == .mensuel {
                await vm.loadCalendar()
            }
            if case .single(let id) = vm.displayMode, !authStore.agencyAll, tab == .mensuel {
                await vm.loadPricing(for: id)
            }
            if isCalendarTabActive { startPolling() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarShouldRefresh)) { _ in
            guard isCalendarTabActive else { return }
            Task { await vm.silentRefresh() }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .calendar {
                if case .loaded = vm.loadState {
                    Task { await vm.silentRefresh() }
                }
                startPolling()
            } else {
                stopPolling()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                guard isCalendarTabActive else { return }
                startPolling()
                Task { await vm.silentRefresh() }
            case .background, .inactive:
                stopPolling()
            @unknown default:
                break
            }
        }
        .onChange(of: tab) { _, new in
            switch new {
            case .jour, .semaine, .mensuel:
                if case .idle = vm.calendarState {
                    Task { await vm.loadCalendar() }
                }
                if new == .mensuel {
                    if case .single(let id) = vm.displayMode, !authStore.agencyAll {
                        Task { await vm.loadPricing(for: id) }
                    } else {
                        vm.clearPricing()
                    }
                }
            case .revenus:
                break   // RevenusView gère ses propres chargements
            }
        }
        .onChange(of: vm.selectedMonthKey) { _, _ in
            if tab == .jour || tab == .semaine || tab == .mensuel {
                vm.clearCalendar()
                Task { await vm.loadCalendar() }
            }
        }
        .onChange(of: vm.displayMode) { _, newMode in
            // dayPrices : uniquement en Mensuel logement unique (hors agence)
            if case .single(let id) = newMode, tab == .mensuel, !authStore.agencyAll {
                Task { await vm.loadPricing(for: id) }
            } else {
                vm.clearPricing()
            }
        }
        .onChange(of: authStore.agencyAll) { _, new in
            vm.agencyAll = new
            Task { await vm.reload() }
        }
    }

    // MARK: Task-based polling (25 s, annulé en arrière-plan)

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled else { break }
                await vm.silentRefresh()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: Contenu Mensuel

    @ViewBuilder
    private var mensuelContent: some View {
        switch vm.loadState {
        case .idle, .loading:
            ProgressView()
                .padding(.top, 80)
                .tint(Color.bhVert)

        case .error(let msg):
            ContentUnavailableView(msg, systemImage: "wifi.exclamationmark")
                .padding(.top, 60)

        case .loaded:
            TimelineView(vm: vm)
        }
    }
}
