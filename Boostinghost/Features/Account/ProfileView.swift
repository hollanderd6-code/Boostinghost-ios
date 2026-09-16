import SwiftUI
import PhotosUI

// MARK: - Écran Profil et entreprise (édition)
// GET  /api/user/profile  → pré-remplissage
// PUT  /api/user/profile  → sauvegarde multipart (logo inclus si sélectionné)
// PATCH /api/user/profile → bascule use_bh_stripe (immédiat)

struct ProfileView: View {
    let initialProfile:   UserProfile?
    var onProfileUpdated: ((UserProfile) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var vm         = ProfileViewModel()
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showPicker = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                navBar
                if let err = vm.saveError {
                    errorBanner(err)
                }
                if vm.isLoading {
                    ProgressView()
                        .tint(Color.bhAttenue)
                        .frame(maxHeight: .infinity)
                } else {
                    form
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .photosPicker(isPresented: $showPicker, selection: $photoItem,
                      matching: .images, photoLibrary: .shared())
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await loadLogo(from: item) }
        }
        .task { await vm.load(initial: initialProfile) }
    }

    // MARK: - Barre de navigation

    private var navBar: some View {
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

            Text("Profil et entreprise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.bhEncre)

            Spacer()

            Color.clear.frame(width: 110, height: 1)
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

    // MARK: - Bandeau d'erreur

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.85))
    }

    // MARK: - Formulaire

    private var form: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                avatarSection
                profileSection
                entrepriseSection
                adresseSection
                facturationSection
                paiementsSection
                saveButton
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Avatar / logo

    private var avatarSection: some View {
        VStack(spacing: 12) {
            Button { showPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let preview = vm.pendingLogoPreview {
                            preview
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            ProfileAvatarView(
                                logoUrl:   vm.profile?.logoUrl,
                                firstName: vm.firstName,
                                lastName:  vm.lastName,
                                company:   vm.company,
                                size:      80
                            )
                        }
                    }
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.bhVert, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            if vm.pendingLogoData != nil {
                Button {
                    vm.pendingLogoData    = nil
                    vm.pendingLogoMime    = nil
                    vm.pendingLogoPreview = nil
                    photoItem = nil
                } label: {
                    Text("Annuler la sélection")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.bhTerracotta)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section Profil

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Profil")
            ListCard {
                field("Prénom",        text: $vm.firstName,  separator: true)
                field("Nom",           text: $vm.lastName,   separator: true)
                field("Téléphone",     text: $vm.phone,      separator: true, keyboard: .phonePad)
                field("Site web",      text: $vm.website,    separator: true, keyboard: .URL)
                accountTypePicker
            }
        }
    }

    private var accountTypePicker: some View {
        CardRow(showSeparator: false) {
            HStack {
                Text("Type de compte")
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Color.bhEncre)
                Spacer(minLength: 8)
                Picker("", selection: $vm.accountType) {
                    Text(AccountType.individual.label).tag(AccountType.individual)
                    Text(AccountType.business.label).tag(AccountType.business)
                }
                .pickerStyle(.menu)
                .font(.system(size: 14))
                .foregroundStyle(Color.bhAttenue)
            }
        }
    }

    // MARK: - Section Entreprise

    private var entrepriseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Entreprise")
            ListCard {
                let isBusiness = vm.accountType == .business
                field("Société",         text: $vm.company,   separator: isBusiness)
                if isBusiness {
                    field("Forme juridique", text: $vm.legalForm, separator: true)
                    field("SIRET",           text: $vm.siret,     separator: false, keyboard: .numberPad)
                }
            }
        }
    }

    // MARK: - Section Adresse

    private var adresseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Adresse")
            ListCard {
                field("Adresse",      text: $vm.address,    separator: true)
                field("Code postal",  text: $vm.postalCode, separator: true, keyboard: .numberPad)
                field("Ville",        text: $vm.city,       separator: false)
            }
        }
    }

    // MARK: - Section Facturation

    private var facturationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Facturation")
            ListCard {
                let isBusiness = vm.accountType == .business
                field("Email de facturation", text: $vm.invoiceEmail, separator: isBusiness, keyboard: .emailAddress)
                if isBusiness {
                    field("Régime TVA",   text: $vm.vatRegime, separator: true)
                    field("Numéro de TVA", text: $vm.vatNumber, separator: false)
                }
            }
        }
    }

    // MARK: - Section Paiements Boostinghost

    private var paiementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Paiements")
            ListCard {
                CardRow(showSeparator: false) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passerelle Boostinghost")
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(Color.bhEncre)
                            Text("Utiliser la passerelle de paiement intégrée")
                                .font(.bhMeta)
                                .foregroundStyle(Color.bhAttenue)
                        }
                        Spacer(minLength: 8)
                        if vm.isTogglingStripe {
                            ProgressView()
                                .tint(Color.bhAttenue)
                                .scaleEffect(0.8)
                        } else {
                            Toggle("", isOn: Binding(
                                get:  { vm.useBhStripe },
                                set:  { v in Task { await vm.toggleStripe(v) } }
                            ))
                            .labelsHidden()
                            .tint(Color.bhVert)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bouton Enregistrer

    private var saveButton: some View {
        Button {
            Task {
                if let updated = await vm.save() {
                    onProfileUpdated?(updated)
                }
            }
        } label: {
            ZStack {
                Text("Enregistrer")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .opacity(vm.isSaving ? 0 : 1)
                if vm.isSaving {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.bhVert, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(vm.isSaving)
    }

    // MARK: - Champ générique label + TextField

    @ViewBuilder
    private func field(
        _ label: String,
        text: Binding<String>,
        separator: Bool,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        CardRow(showSeparator: separator) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.bhAttenue)
                TextField("", text: text)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.bhEncre)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled(keyboard != .default)
            }
        }
    }

    // MARK: - Chargement du logo depuis la bibliothèque

    private func loadLogo(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            photoItem = nil
            return
        }
        let mime = mimeType(for: data)
        let allowed: Set<String> = ["image/jpeg", "image/png", "image/webp",
                                    "image/gif", "image/heic", "image/heif",
                                    "application/pdf"]
        guard allowed.contains(mime) else {
            vm.saveError = "Format non supporté. Utilisez JPEG, PNG, WebP, GIF, HEIC ou PDF."
            photoItem = nil
            return
        }
        guard data.count <= 10 * 1024 * 1024 else {
            vm.saveError = "Le logo ne doit pas dépasser 10 Mo."
            photoItem = nil
            return
        }
        vm.pendingLogoData    = data
        vm.pendingLogoMime    = mime
        vm.pendingLogoPreview = Image(uiImage: UIImage(data: data) ?? UIImage())
        photoItem = nil
    }

    private func mimeType(for data: Data) -> String {
        guard data.count >= 4 else { return "image/jpeg" }
        let b = [UInt8](data.prefix(4))
        if b[0] == 0xFF && b[1] == 0xD8 { return "image/jpeg" }
        if b[0] == 0x89 && b[1] == 0x50 { return "image/png" }
        if b[0] == 0x47 && b[1] == 0x49 { return "image/gif" }
        if b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46 { return "application/pdf" }
        if data.count >= 12 {
            let riff = [UInt8](data.prefix(4))
            let webp = [UInt8](data[8..<12])
            if riff == [0x52, 0x49, 0x46, 0x46] && webp == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
        }
        return "image/jpeg"
    }
}
