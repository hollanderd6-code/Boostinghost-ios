import SwiftUI

struct SetupCardView: View {
    let vm: SetupViewModel
    let onStepTap: (SetupStepID) -> Void

    @AppStorage("setupCardCollapsed") private var isCollapsed    = false
    @State private var isDismissing       = false
    @State private var showDismissConfirm = false
    @State private var showAllPending     = false

    private var pct: Int { vm.completionPercentage }

    private var pendingSteps: [SetupStep] {
        vm.steps.filter { $0.state == .pending || $0.state == .locked }
    }
    private var doneSteps: [SetupStep] {
        vm.steps.filter { $0.state == .completed || $0.state == .notApplicable }
    }
    private var isZeroProperties: Bool { vm.properties?.isEmpty == true }

    var body: some View {
        if vm.isDismissed { EmptyView() }
        else { cardContent }
    }

    private var cardContent: some View {
        ListCard(cornerRadius: 20) {
            VStack(spacing: 0) {
                headerRow
                if !isCollapsed {
                    Divider()
                        .background(Color.bhEncre.opacity(0.08))
                        .padding(.horizontal, 16)
                    expandedContent
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isCollapsed)
        .animation(.easeInOut(duration: 0.18), value: showAllPending)
        .confirmationDialog("Masquer la configuration ?", isPresented: $showDismissConfirm) {
            Button("Masquer", role: .destructive) {
                guard !isDismissing else { return }
                isDismissing = true
                Task { await vm.dismiss(); isDismissing = false }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vous pourrez la retrouver à tout moment dans Aide et tutoriels.")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 11) {
            progressCircle
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 1) {
                Text("Configurer Boostinghost")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                Text(subtitle)
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Menu {
                    Button(role: .destructive) {
                        showDismissConfirm = true
                    } label: {
                        Label("Ne plus afficher", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.35), in: Circle())
                }
                .disabled(isDismissing)

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { isCollapsed.toggle() }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.35), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Progress circle

    private var progressCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.bhEncre.opacity(0.10), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: CGFloat(pct) / 100)
                .stroke(
                    pct == 100 ? Color.bhVert : Color.bhVertClair,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: pct)
            Text("\(pct)%")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(pct == 100 ? Color.bhVert : Color.bhEncre)
        }
    }

    private var subtitle: String {
        let n = pendingSteps.count
        if pct == 100 { return "Configuration complète" }
        return n == 1 ? "1 étape restante" : "\(n) étapes restantes"
    }

    // MARK: - Expanded content

    @ViewBuilder
    private var expandedContent: some View {
        if pct == 100 {
            completedState
        } else if isZeroProperties {
            zeroPropertiesState
        } else {
            standardState
        }
    }

    // MARK: - 100 %

    private var completedState: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(Color(hex: "#DCE8E1"))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhVert)
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("Boostinghost est prêt")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Color.bhEncre)
                Text("Configuration terminée")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 0 logements

    private var zeroPropertiesState: some View {
        let otherCount = vm.steps.count - 1
        return VStack(spacing: 0) {
            if let propStep = vm.steps.first(where: { $0.stepID == .property }) {
                stepRow(propStep, showSeparator: true)
            }
            HStack(spacing: 11) {
                Color.clear.frame(width: 26)
                Text("\(otherCount) étapes seront disponibles ensuite")
                    .font(.bhMeta)
                    .foregroundStyle(Color.bhAttenue)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }

    // MARK: - Standard (pending > 0)

    private var standardState: some View {
        let visible      = showAllPending ? pendingSteps : Array(pendingSteps.prefix(3))
        let overflowCnt  = pendingSteps.count - 3
        let hasOverflow  = pendingSteps.count > 3
        let done         = doneSteps.count

        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { idx, step in
                let isLast = idx == visible.count - 1
                let sep    = !isLast || hasOverflow || done > 0
                stepRow(step, showSeparator: sep)
            }

            if hasOverflow {
                let label = showAllPending
                    ? "Afficher moins"
                    : "+ \(overflowCnt) étape\(overflowCnt == 1 ? "" : "s") restante\(overflowCnt == 1 ? "" : "s")"
                overflowRow(label: label, showSeparator: done > 0)
            }

            if done > 0 {
                doneRow(count: done)
            }
        }
    }

    // MARK: - Ligne d'étape

    private func stepRow(_ step: SetupStep, showSeparator: Bool) -> some View {
        CardRow(verticalPadding: 9, showSeparator: showSeparator) {
            HStack(spacing: 11) {
                stateIcon(step.state)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(step.stepID.title)
                        .font(.system(size: 14, weight: step.state == .completed ? .regular : .medium))
                        .foregroundStyle(
                            step.state == .completed || step.state == .notApplicable
                                ? Color.bhAttenue : Color.bhEncre
                        )
                        .strikethrough(step.state == .notApplicable, color: Color.bhAttenue)

                    if step.state != .completed && step.state != .notApplicable {
                        Text(step.detail ?? step.stepID.description)
                            .font(.bhMeta)
                            .foregroundStyle(Color.bhAttenue)
                    }
                }

                Spacer(minLength: 4)
                stepActions(step)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if step.state != .completed && step.state != .notApplicable {
                onStepTap(step.stepID)
            }
        }
    }

    // MARK: - Ligne "N étapes restantes" / "Afficher moins"

    private func overflowRow(label: String, showSeparator: Bool) -> some View {
        CardRow(verticalPadding: 9, showSeparator: showSeparator) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showAllPending.toggle() }
            } label: {
                HStack(spacing: 11) {
                    Color.clear.frame(width: 26, height: 26)
                    Text(label)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color.bhVert)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ligne compacte étapes terminées

    private func doneRow(count: Int) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(Color(hex: "#DCE8E1"))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.bhVert)
            }
            .frame(width: 26, height: 26)
            Text("\(count) étape\(count == 1 ? "" : "s") terminée\(count == 1 ? "" : "s")")
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Icône d'état

    @ViewBuilder
    private func stateIcon(_ state: SetupStepState) -> some View {
        switch state {
        case .completed:
            ZStack {
                Circle().fill(Color(hex: "#DCE8E1"))
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhVert)
            }
        case .notApplicable:
            ZStack {
                Circle().fill(Color.bhEncre.opacity(0.07))
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.bhAttenue)
            }
        case .locked:
            ZStack {
                Circle().fill(Color.bhEncre.opacity(0.07))
                Image(systemName: "lock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
            }
        case .pending:
            ZStack {
                Circle()
                    .stroke(Color.bhEncre.opacity(0.20), lineWidth: 1.5)
                Circle()
                    .fill(Color.clear)
            }
        }
    }

    // MARK: - Actions par étape

    @ViewBuilder
    private func stepActions(_ step: SetupStep) -> some View {
        switch step.state {
        case .completed:
            EmptyView()

        case .notApplicable:
            Button {
                Task { await vm.toggleNotApplicable(step.stepID) }
            } label: {
                Text("Annuler")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.bhEncre.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)

        case .pending, .locked:
            if step.stepID == .property {
                Button { onStepTap(step.stepID) } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 28, height: 28)
                        .background(Color.bhEncre.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    Button { onStepTap(step.stepID) } label: {
                        Label("Configurer", systemImage: "arrow.right")
                    }
                    Button {
                        Task { await vm.toggleNotApplicable(step.stepID) }
                    } label: {
                        Label(notApplicableLabel(for: step.stepID), systemImage: "minus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.bhAttenue)
                        .frame(width: 28, height: 28)
                        .background(Color.bhEncre.opacity(0.07), in: Circle())
                }
            }
        }
    }

    // MARK: - Labels "Pas nécessaire"

    private func notApplicableLabel(for id: SetupStepID) -> String {
        switch id {
        case .property:    return "—"
        case .platforms:   return "Je n'utilise pas de plateforme"
        case .messages:    return "Je n'utilise pas les messages automatiques"
        case .cleaning:    return "Je gère le ménage moi-même"
        case .team:        return "Je travaille seul"
        case .payments:    return "Je n'en ai pas besoin"
        case .welcomeBook: return "Je n'utilise pas le livret d'accueil"
        }
    }
}
