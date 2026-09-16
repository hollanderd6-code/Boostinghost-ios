import SwiftUI

// MARK: - App tour (Level 1 — First Launch, 3 pages)

struct AppTourView: View {
    var isAwaitingBegin: Bool = false
    let onConfigure: () -> Void
    let onSkip: () -> Void

    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppBackground(expandedHalos: true)
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    TourPageToday().tag(0)
                    TourPageCalendar().tag(1)
                    TourPageMessages().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
                    .padding(.horizontal, 26)
                    .padding(.top, 16)
                    .padding(.bottom, 52)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Pagination dots

    private var paginationDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == currentPage ? Color.bhVert : Color.bhAttenue.opacity(0.28))
                    .frame(width: i == currentPage ? 20 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
        .accessibilityLabel("Page \(currentPage + 1) sur 3")
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        VStack(spacing: 20) {
            paginationDots
            if currentPage == 2 {
                lastPageActions
            } else {
                continueActions
            }
        }
    }

    private var lastPageActions: some View {
        VStack(spacing: 14) {
            Text("Quelques minutes pour adapter\nl'app à votre activité.")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)

            Button(action: onConfigure) {
                ZStack {
                    if isAwaitingBegin {
                        ProgressView().tint(.white)
                    } else {
                        Text("Configurer Boostinghost")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.bhVert.opacity(isAwaitingBegin ? 0.65 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isAwaitingBegin)
            .accessibilityLabel(isAwaitingBegin ? "Chargement en cours" : "Configurer Boostinghost")

            Button(action: onSkip) {
                Text("Découvrir l'app")
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.bhAttenue)
            }
            .padding(.bottom, 4)
        }
    }

    private var continueActions: some View {
        VStack(spacing: 14) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage += 1 }
            } label: {
                Text("Continuer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.bhVert)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            // "Passer" jumps to the final choice page — does NOT begin() automatically.
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { currentPage = 2 }
            } label: {
                Text("Passer")
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.bhAttenue)
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Page 1 — Aujourd'hui

private struct TourPageToday: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            TourCardToday()
                .padding(.horizontal, 26)
                .shadow(color: Color.bhVert.opacity(0.09), radius: 18, x: 0, y: 8)
            Spacer().frame(height: 26)
            tourCopy(
                title: "Votre activité en un coup d'œil",
                body: "Arrivées, départs, alertes et tâches importantes : retrouvez chaque jour ce qui demande votre attention."
            )
            .padding(.horizontal, 26)
            Spacer(minLength: 12)
        }
    }
}

// MARK: - Page 2 — Réservations

private struct TourPageCalendar: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            TourCardCalendar()
                .padding(.horizontal, 26)
                .shadow(color: Color.bhVert.opacity(0.09), radius: 18, x: 0, y: 8)
            Spacer().frame(height: 26)
            tourCopy(
                title: "Toutes vos réservations au même endroit",
                body: "Airbnb, Booking et réservations directes réunies dans un calendrier multi-logements."
            )
            .padding(.horizontal, 26)
            Spacer(minLength: 12)
        }
    }
}

// MARK: - Page 3 — Messages

private struct TourPageMessages: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            TourCardMessages()
                .padding(.horizontal, 26)
                .shadow(color: Color.bhVert.opacity(0.09), radius: 18, x: 0, y: 8)
            Spacer().frame(height: 26)
            tourCopy(
                title: "Gagnez du temps au quotidien",
                body: "Centralisez vos échanges voyageurs et automatisez vos messages depuis Boostinghost."
            )
            .padding(.horizontal, 26)
            Spacer(minLength: 12)
        }
    }
}

// MARK: - Shared copy helper

@ViewBuilder
private func tourCopy(title: String, body: String) -> some View {
    VStack(spacing: 10) {
        Text(title)
            .font(.system(size: 25, weight: .bold))
            .tracking(-0.7)
            .foregroundStyle(Color.bhEncre)
            .multilineTextAlignment(.center)
        Text(body)
            .font(.system(size: 15.5))
            .foregroundStyle(Color.bhAttenue)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }
}

// MARK: - Illustration: Aujourd'hui

private struct TourCardToday: View {
    private let days: [(abbrev: String, num: String, isToday: Bool, hasDot: Bool)] = [
        ("L",  "15", false, false),
        ("M",  "16", false, false),
        ("Me", "17", true,  true ),
        ("J",  "18", false, false),
        ("V",  "19", false, true ),
        ("S",  "20", false, false),
        ("D",  "21", false, false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("mercredi 17 sept.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
                Text("Aujourd'hui")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                counterPill(value: "2", label: "Arrivées",  accent: true)
                counterPill(value: "1", label: "Départs",   accent: false)
                counterPill(value: "3", label: "Ménages",   accent: false)
            }
            .padding(.horizontal, 10)

            Divider()
                .background(Color.bhEncre.opacity(0.07))
                .padding(.horizontal, 10)
                .padding(.top, 10)

            HStack(spacing: 2) {
                ForEach(days, id: \.num) { d in
                    VStack(spacing: 3) {
                        Text(d.abbrev)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(d.isToday ? Color.white.opacity(0.8) : Color.bhAttenue)
                        Text(d.num)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(d.isToday ? Color.white : Color.bhEncre)
                        Circle()
                            .fill(d.hasDot
                                  ? (d.isToday ? Color.white.opacity(0.65) : Color.bhOccupe)
                                  : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        d.isToday ? Color.bhVert : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 13)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
    }

    private func counterPill(value: String, label: String, accent: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(accent ? Color.bhVert : Color.bhEncre)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.bhAttenue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            accent ? Color.bhMentheFond : Color.bhEncre.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - Illustration: Réservations

private struct TourCardCalendar: View {
    private let propRows: [(name: String, segs: [Bool])] = [
        ("Apt. Montmartre", [true,  true,  true,  false, false, true, true]),
        ("Studio Bastille",  [false, false, true,  true,  true,  false, false]),
        ("Maison Bretagne", [true,  false, false, false, true,  true, true])
    ]
    private let dayLabels = ["L", "M", "Me", "J", "V", "S", "D"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 96, height: 1)
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(i == 2 ? Color.bhVert : Color.bhAttenue)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider()
                .background(Color.bhEncre.opacity(0.07))
                .padding(.horizontal, 12)

            ForEach(propRows.indices, id: \.self) { ri in
                HStack(spacing: 0) {
                    Text(propRows[ri].name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                        .lineLimit(1)
                        .frame(width: 96, alignment: .leading)
                        .padding(.leading, 12)

                    HStack(spacing: 0) {
                        ForEach(propRows[ri].segs.indices, id: \.self) { di in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(propRows[ri].segs[di]
                                      ? Color.bhOccupe.opacity(0.65)
                                      : Color.bhEncre.opacity(0.05))
                                .frame(height: 20)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 1.5)
                        }
                    }
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 5)

                if ri < propRows.count - 1 {
                    Divider()
                        .background(Color.bhEncre.opacity(0.05))
                        .padding(.horizontal, 12)
                }
            }

            HStack(spacing: 10) {
                legendDot(color: .bhOccupe, label: "Occupé")
                legendDot(color: .bhDepart, label: "Départ")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.65))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.bhAttenue)
        }
    }
}

// MARK: - Illustration: Messages

private struct TourCardMessages: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    Circle()
                        .fill(Color.bhMentheFond)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.bhVert)
                        }
                    Text("Bonjour ! À quelle heure\npuis-je récupérer les clés ?")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.bhEncre)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Color.bhEncre.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    Spacer(minLength: 24)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    Spacer(minLength: 24)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Bonjour ! Remise de 16 h à 20 h.\nÀ très bientôt !")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Color.bhVert,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.bhVertClair)
                            Text("Message automatique")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.bhAttenue)
                        }
                    }
                }
            }
            .padding(12)

            Divider()
                .background(Color.bhEncre.opacity(0.07))
                .padding(.horizontal, 10)

            HStack(spacing: 7) {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.bhVert)
                Text("4 messages programmés pour ce séjour")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhVertClair)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Tour — page 1") {
    AppTourView(onConfigure: {}, onSkip: {})
}

#Preview("Tour — dernier slide, chargement") {
    AppTourView(isAwaitingBegin: true, onConfigure: {}, onSkip: {})
}
