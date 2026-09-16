import SwiftUI

struct CreateReservationView: View {
    let vm:         CalendarViewModel
    let onComplete: () -> Void

    @State private var selectedPropertyId: String
    @State private var start: Date
    @State private var end:   Date

    // Voyageur
    @State private var guestName    = ""
    @State private var phone        = ""
    @State private var email        = ""
    @State private var guestCountry = ""
    @State private var adultes      = ""

    // Réservation
    @State private var platform = "Direct"

    // Prix
    @State private var priceText          = ""
    @State private var amountRoomsText    = ""
    @State private var amountCleaningText = ""
    @State private var amountTaxesText    = ""
    @State private var otaCommissionText  = ""

    // Notes
    @State private var notes = ""

    @State private var isLoading            = false
    @State private var error:               String?
    @State private var showBHGuestHold      = false

    init(vm: CalendarViewModel, property: PropertySummary, start: Date, end: Date, onComplete: @escaping () -> Void) {
        self.vm         = vm
        self.onComplete = onComplete
        _selectedPropertyId = State(initialValue: property.id)
        _start = State(initialValue: start)
        _end   = State(initialValue: end)
    }

    private var selectedProperty: PropertySummary? {
        vm.properties.first { $0.id == selectedPropertyId }
    }

    var body: some View {
        Form {
            Section {
                Button {
                    showBHGuestHold = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.bhTerracotta)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Réservation avec BHGuest")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.bhTerracotta)
                            Text("Lien de paiement · 3 % · dates bloquées automatiquement")
                                .font(.caption)
                                .foregroundStyle(Color.bhEncre.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(Color.bhAttenue)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.bhTerracottaFond)
            }
            .navigationDestination(isPresented: $showBHGuestHold) {
                if let prop = selectedProperty {
                    BHGuestHoldView(
                        vm:           vm,
                        property:     prop,
                        start:        start,
                        end:          end,
                        prefillPhone: nonEmpty(phone),
                        prefillEmail: nonEmpty(email),
                        onComplete:   onComplete
                    )
                }
            }

            Section("Voyageur") {
                TextField("Nom", text: $guestName)
                TextField("Téléphone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Nationalité", text: $guestCountry)
                HStack {
                    Text("Adultes")
                    Spacer()
                    TextField("0", text: $adultes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
            }

            Section("Réservation") {
                if vm.properties.count > 1 {
                    Picker("Logement", selection: $selectedPropertyId) {
                        ForEach(vm.properties) { p in
                            Text(p.displayName).tag(p.id)
                        }
                    }
                } else if let p = vm.properties.first {
                    LabeledContent("Logement", value: p.displayName)
                }
                DatePicker("Arrivée", selection: $start, displayedComponents: .date)
                DatePicker("Départ",  selection: $end,   displayedComponents: .date)
                    .onChange(of: start) { _, new in
                        if end <= new {
                            end = vm.utcCal.date(byAdding: .day, value: 1, to: new) ?? new
                        }
                    }
                TextField("Plateforme", text: $platform)
            }

            Section("Prix") {
                euroRow("Total",            text: $priceText)
                euroRow("Nuits",            text: $amountRoomsText)
                euroRow("Ménage",           text: $amountCleaningText)
                euroRow("Taxe de séjour",   text: $amountTaxesText)
                euroRow("Commission OTA",   text: $otaCommissionText)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    Text("Créer la réservation").bold().frame(maxWidth: .infinity)
                }
                .foregroundStyle(Color.bhVert)
                .disabled(selectedPropertyId.isEmpty || isLoading)
            }
        }
        .navigationTitle("Nouvelle réservation")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView().tint(Color.bhVert)
            }
        }
        .alert("Erreur", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder
    private func euroRow(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text("€").foregroundStyle(Color.bhAttenue)
        }
    }

    private func submit() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await vm.createManualReservation(
                propertyId:      selectedPropertyId,
                start:           start,
                end:             end,
                guestName:       nonEmpty(guestName),
                notes:           nonEmpty(notes),
                platform:        nonEmpty(platform),
                price:           decimal(priceText),
                phone:           nonEmpty(phone),
                email:           nonEmpty(email),
                guestCountry:    nonEmpty(guestCountry),
                occupancyAdults: Int(adultes.trimmingCharacters(in: .whitespaces)),
                amountRooms:     decimal(amountRoomsText),
                amountCleaning:  decimal(amountCleaningText),
                amountTaxes:     decimal(amountTaxesText),
                otaCommission:   decimal(otaCommissionText)
            )
            await vm.reloadMonthData()
            onComplete()
        } catch {
            self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
        }
    }

    private func decimal(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func nonEmpty(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }
}
