import SwiftUI

// Barre de navigation spécifique au Calendrier :
// supertitle (menu logement) + grand titre (mois) + chevrons + segmenté Planning/Revenus.

struct CalendarNavBar: View {
    var vm: CalendarViewModel      // @Observable — les lectures sont tracées par SwiftUI
    @Binding var tab: CalendarTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    // Sur-titre tappable → menu logement
                    Menu {
                        Button("Tous les logements") {
                            vm.displayMode = .allGrid
                        }
                        Button("Tous les logements — en lignes") {
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

                    // Grand titre
                    Text(vm.monthTitle)
                        .bhGrandTitre()
                }

                Spacer(minLength: 12)

                // Chevrons de mois — 34×34 en verre
                HStack(spacing: 8) {
                    monthButton(icon: "chevron.left",  action: vm.previousMonth)
                    monthButton(icon: "chevron.right", action: vm.nextMonth)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Sélecteur segmenté Planning / Revenus
            SegmentedGlass(
                options: [
                    ("Planning", CalendarTab.planning),
                    ("Revenus",  CalendarTab.revenus),
                ],
                selection: $tab
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .chromeShadow()
                .ignoresSafeArea(edges: .top)
        }
    }

    private func monthButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(Color.bhEncre)
                .frame(width: 34, height: 34)
                .glassEffect(in: .circle)
                .specularEdge(cornerRadius: 17)
        }
        .buttonStyle(.plain)
    }
}
