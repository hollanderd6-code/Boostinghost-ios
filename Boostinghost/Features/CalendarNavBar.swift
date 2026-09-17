import SwiftUI

// Barre de navigation spécifique au Calendrier :
// supertitle (menu logement) + grand titre (mois) + chevrons + segmenté 4 onglets.

struct CalendarNavBar: View {
    var vm: CalendarViewModel
    @Binding var tab: CalendarTab

    @Environment(TipCoordinator.self) private var tipCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showBulkAction = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    // Sur-titre tappable → menu logement
                    Menu {
                        Button("Tous les logements") {
                            vm.displayMode = .allLines
                        }
                        if !vm.properties.isEmpty {
                            Divider()
                            ForEach(vm.properties) { prop in
                                Button(prop.displayName) {
                                    vm.displayMode = .single(prop.id)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(vm.superTitle)
                                .font(.bhSurTitre)
                                .foregroundStyle(Color.bhAttenue)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.bhAttenue)
                        }
                        .contentShape(Rectangle())
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        tipCoordinator.markSeen(.calendarPropertyPicker)
                    })

                    // Grand titre
                    Text(vm.monthTitle)
                        .bhGrandTitre()
                }

                Spacer(minLength: 12)

                // Boutons droite — modification en masse + chevrons de mois
                HStack(spacing: 8) {
                    Button {
                        tipCoordinator.markSeen(.calendarBulkAction)
                        showBulkAction = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .imageScale(.medium)
                            .foregroundStyle(Color.bhEncre)
                            .frame(width: 38, height: 38)
                            .glassEffect(in: .circle)
                            .specularEdge(cornerRadius: 19)
                    }
                    .buttonStyle(.plain)

                    monthButton(icon: "chevron.left",  action: { tab == .semaine ? vm.previousWeek() : vm.previousMonth() })
                    monthButton(icon: "chevron.right", action: { tab == .semaine ? vm.nextWeek()     : vm.nextMonth()     })
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Sélecteur natif iOS 26 — Liquid Glass système
            Picker("Vue calendrier", selection: $tab) {
                Text("Jour").tag(CalendarTab.jour)
                Text("Semaine").tag(CalendarTab.semaine)
                Text("Mensuel").tag(CalendarTab.mensuel)
                Text("Revenus").tag(CalendarTab.revenus)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            if tipCoordinator.presentedTip == .calendarBulkAction {
                ContextualTipView(
                    title: "Modifier plusieurs nuits",
                    message: "L'outil de sélection groupée permet de bloquer ou libérer plusieurs nuits d'un coup.",
                    onDismiss: { tipCoordinator.dismiss() }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            } else if tipCoordinator.presentedTip == .calendarPropertyPicker {
                ContextualTipView(
                    title: "Filtrer par logement",
                    message: "Appuyez sur le nom en haut pour n'afficher qu'un seul logement sur le calendrier.",
                    onDismiss: { tipCoordinator.dismiss() }
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: tipCoordinator.presentedTip)
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showBulkAction) {
            BulkActionSheet(vm: vm)
        }
    }

    private func monthButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(Color.bhEncre)
                .frame(width: 38, height: 38)
                .glassEffect(in: .circle)
                .specularEdge(cornerRadius: 19)
        }
        .buttonStyle(.plain)
    }
}
