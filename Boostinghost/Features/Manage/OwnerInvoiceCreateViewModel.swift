import Foundation
import Observation

@Observable
@MainActor
final class OwnerInvoiceCreateViewModel {

    // MARK: - Mode

    enum FormMode {
        case create
        case edit(String)  // invoiceId
    }

    enum LoadState { case idle, loading, loaded, error(String) }

    let mode: FormMode

    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    // MARK: - Owner

    var clients: [OwnerClient] = []
    var clientsLoadState: LoadState = .idle
    var selectedClient: OwnerClient?

    // MARK: - Properties

    var ownerProperties: [Property] = []
    var propertiesLoadState: LoadState = .idle
    var selectedPropertyIds: Set<String> = []

    // MARK: - Period

    var dateFrom: Date
    var dateTo: Date
    var issueDate: Date = Date()
    var dueDate: Date

    // MARK: - Invoice options

    var vatApplicable: Bool   = false
    var vatRate: Double       = 20.0
    var discountType: String  = "none"   // "none" | "percent" | "fixed"
    var discountValue: Double = 0
    var notes: String         = ""
    var internalNotes: String = ""

    // MARK: - Import state

    var importLoadState: LoadState = .idle
    var importError: String?
    var summaryBuckets: [InvoiceSummaryBucket] = []
    var draftItems: [OwnerInvoiceDraftItem] = []

    // MARK: - Create state

    var isSubmitting: Bool = false
    var createError: String?
    var createdInvoiceId: String?

    // MARK: - Edit state

    var draftLoadState: LoadState = .idle
    var saveSucceeded: Bool = false
    var saveError: String?
    var editInvoiceInfo: OwnerInvoiceEditFields?
    var showReimportConfirm: Bool = false

    // Currency snapshot: authority for all amounts/formatting in edit mode.
    // Populated from invoice.currency during loadDraft(); never changes after.
    var invoiceCurrencySnapshot: String?

    // MARK: - Init

    init(mode: FormMode = .create) {
        self.mode = mode
        let cal              = Calendar.current
        let now              = Date()
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let prevMonthLastDay = cal.date(byAdding: .day, value: -1, to: startOfThisMonth)!
        let startOfPrevMonth = cal.date(from: cal.dateComponents([.year, .month], from: prevMonthLastDay))!
        dateFrom = startOfPrevMonth
        dateTo   = prevMonthLastDay
        dueDate  = cal.date(byAdding: .day, value: 30, to: now) ?? now
    }

    // MARK: - Computed — currency & properties

    var invoiceCurrency: String {
        if let snapshot = invoiceCurrencySnapshot { return snapshot }
        return Formatters.normalizeCurrency(selectedProperties.first?.currency)
    }

    var selectedCurrency: String? {
        ownerProperties.first { selectedPropertyIds.contains($0.id) && $0.currency != nil }?.currency
    }

    var selectedProperties: [Property] {
        ownerProperties.filter { selectedPropertyIds.contains($0.id) }
    }

    var commissionRate: Double {
        selectedClient?.defaultCommissionRate ?? 20.0
    }

    // MARK: - Computed — items

    var includedItems: [OwnerInvoiceDraftItem] {
        draftItems.filter { $0.isIncluded }
    }

    var incompatibleItems: [OwnerInvoiceDraftItem] {
        draftItems.filter {
            $0.isImported && !$0.isIncluded &&
            Formatters.normalizeCurrency($0.currency) != invoiceCurrency
        }
    }

    var hasCurrencyMismatch: Bool {
        includedItems.contains {
            Formatters.normalizeCurrency($0.currency) != invoiceCurrency
        }
    }

    // MARK: - Computed — totals

    var subtotalHt: Double {
        includedItems.reduce(0) { $0 + $1.lineTotal }
    }

    var discountAmount: Double {
        switch discountType {
        case "percent": return (subtotalHt * discountValue / 100.0).rounded(decimals: 2)
        case "fixed":   return discountValue
        default:        return 0
        }
    }

    var netHt: Double { (subtotalHt - discountAmount).rounded(decimals: 2) }

    var vatAmount: Double {
        vatApplicable ? (netHt * vatRate / 100.0).rounded(decimals: 2) : 0
    }

    var totalTtc: Double { (netHt + vatAmount).rounded(decimals: 2) }

    // MARK: - Computed — validation

    var isReadyToCreate: Bool {
        guard selectedClient != nil else { return false }
        guard !selectedPropertyIds.isEmpty else { return false }
        guard !includedItems.isEmpty else { return false }
        guard !isSubmitting else { return false }
        guard !hasCurrencyMismatch else { return false }
        return true
    }

    var isReadyToSave: Bool {
        guard !includedItems.isEmpty else { return false }
        guard !isSubmitting else { return false }
        guard !hasCurrencyMismatch else { return false }
        return true
    }

    // MARK: - Load clients (create mode)

    func loadClients() async {
        clientsLoadState = .loading
        do {
            let resp: OwnerClientsResponse = try await APIClient.shared.get(Endpoint.ownerClients)
            clients = resp.clients
            clientsLoadState = .loaded
        } catch {
            clientsLoadState = .error("Impossible de charger les propriétaires.")
        }
    }

    // MARK: - Select owner (create mode)

    func selectClient(_ client: OwnerClient) {
        selectedClient = client
        selectedPropertyIds = []
        resetSummary()
        Task { await loadOwnerProperties(for: client) }
    }

    private func loadOwnerProperties(for client: OwnerClient) async {
        propertiesLoadState = .loading
        let propsResp: PropertiesResponse? = try? await APIClient.shared.get(
            Endpoint.properties, agencyAll: true)
        ownerProperties = (propsResp?.properties ?? []).filter { $0.ownerId == client.matchingId }
        propertiesLoadState = .loaded
    }

    // MARK: - Property selection (create mode)

    func toggleProperty(_ property: Property) {
        if selectedPropertyIds.contains(property.id) {
            selectedPropertyIds.remove(property.id)
        } else {
            guard let propCur = property.currency else { return }
            if let cur = selectedCurrency, propCur != cur { return }
            selectedPropertyIds.insert(property.id)
        }
        resetSummary()
    }

    func isCurrencyCompatible(_ property: Property) -> Bool {
        guard let propCur = property.currency else { return false }
        guard let cur = selectedCurrency else { return true }
        return propCur == cur
    }

    // MARK: - Import

    func reimportReservations() async {
        guard isEditMode, !selectedPropertyIds.isEmpty else { return }
        showReimportConfirm = false
        importLoadState = .loading
        importError     = nil

        // Preserve debours and non-commission items across reimport
        let preserved = draftItems.filter { $0.isDebours || $0.itemType != "commission" }
        summaryBuckets = []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let queryItems = Endpoint.invoiceSummaryQueryItems(
            dateFrom:    df.string(from: dateFrom),
            dateTo:      df.string(from: dateTo),
            propertyIds: Array(selectedPropertyIds)
        )

        do {
            let resp: InvoiceSummaryResponse = try await APIClient.shared.get(
                Endpoint.invoiceSummary, extraQueryItems: queryItems)
            summaryBuckets = resp.summary
            let freshItems = resp.summary.map { bucket in
                OwnerInvoiceDraftItem(
                    importedFrom: bucket,
                    commissionRate: commissionRate,
                    isCompatible: Formatters.normalizeCurrency(bucket.currency) == invoiceCurrency
                )
            }
            draftItems      = preserved + freshItems
            importLoadState = .loaded
        } catch {
            importLoadState = .error("Impossible de charger le résumé des réservations.")
            importError     = "Impossible de charger le résumé des réservations."
            if draftItems.isEmpty { draftItems = preserved }
        }
    }

    func importReservations() async {
        guard !selectedPropertyIds.isEmpty else { return }
        importLoadState = .loading
        importError     = nil
        summaryBuckets  = []
        draftItems      = []

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let queryItems = Endpoint.invoiceSummaryQueryItems(
            dateFrom:    df.string(from: dateFrom),
            dateTo:      df.string(from: dateTo),
            propertyIds: Array(selectedPropertyIds)
        )

        do {
            let resp: InvoiceSummaryResponse = try await APIClient.shared.get(
                Endpoint.invoiceSummary, extraQueryItems: queryItems)
            summaryBuckets = resp.summary
            draftItems = resp.summary.map { bucket in
                OwnerInvoiceDraftItem(
                    importedFrom: bucket,
                    commissionRate: commissionRate,
                    isCompatible: Formatters.normalizeCurrency(bucket.currency) == invoiceCurrency
                )
            }
            importLoadState = .loaded
        } catch {
            importLoadState = .error("Impossible de charger le résumé des réservations.")
            importError     = "Impossible de charger le résumé des réservations."
        }
    }

    // MARK: - Draft item mutations

    func addManualItem(itemType: String) {
        draftItems.append(OwnerInvoiceDraftItem(itemType: itemType, currency: invoiceCurrency))
    }

    func removeItem(id: UUID) {
        draftItems.removeAll { $0.id == id }
    }

    func updateCommissionRate(id: UUID, rate: Double) {
        guard let idx = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[idx].commissionRate = rate
    }

    func updateDescription(id: UUID, text: String) {
        guard let idx = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[idx].description = text
    }

    func updateRentalAmount(id: UUID, amount: Double) {
        guard let idx = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[idx].rentalAmount = amount
    }

    func updateQuantity(id: UUID, qty: Double) {
        guard let idx = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[idx].quantity = qty
    }

    func updateUnitPrice(id: UUID, price: Double) {
        guard let idx = draftItems.firstIndex(where: { $0.id == id }) else { return }
        draftItems[idx].unitPrice = price
    }

    // MARK: - Reset

    func resetSummary() {
        summaryBuckets  = []
        draftItems      = []
        importLoadState = .idle
        importError     = nil
    }

    // MARK: - Load draft (edit mode)

    func loadDraft() async {
        guard case .edit(let invoiceId) = mode else { return }
        draftLoadState = .loading

        do {
            let resp: OwnerInvoiceEditLoadResponse = try await APIClient.shared.get(
                Endpoint.ownerInvoice(invoiceId), agencyAll: true)

            let inv = resp.invoice

            guard inv.status == "draft" else {
                draftLoadState = .error("Cette facture ne peut pas être modifiée (statut : \(inv.status ?? "inconnu")).")
                return
            }

            invoiceCurrencySnapshot = Formatters.normalizeCurrency(inv.currency)
            editInvoiceInfo         = inv

            vatApplicable  = inv.vatApplicable  ?? false
            vatRate        = inv.vatRate        ?? 20.0
            discountType   = inv.discountType   ?? "none"
            discountValue  = inv.discountValue  ?? 0
            notes          = inv.notes          ?? ""
            internalNotes  = inv.internalNotes  ?? ""

            // Dates — pre-populate from stored draft values
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let v = inv.issueDate,   let d = df.date(from: v) { issueDate = d }
            if let v = inv.dueDate,     let d = df.date(from: v) { dueDate   = d }
            if let ps = inv.periodStart, let date = df.date(from: ps) { dateFrom = date }
            if let pe = inv.periodEnd,   let date = df.date(from: pe) { dateTo   = date }

            // Property IDs for reimport query
            selectedPropertyIds = Set(resp.properties.map { $0.id })

            // Map existing items — inherit invoice.currency (items have no own currency in DB)
            let cur = Formatters.normalizeCurrency(inv.currency)
            draftItems = resp.items.map { OwnerInvoiceDraftItem(fromExisting: $0, invoiceCurrency: cur) }

            draftLoadState = .loaded
        } catch {
            draftLoadState = .error("Impossible de charger le brouillon.")
        }
    }

    // MARK: - POST /api/owner-invoices (create mode)

    func createInvoice() async {
        guard isReadyToCreate, let client = selectedClient else { return }
        isSubmitting = true
        createError  = nil

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let itemRequests = includedItems.map { buildItemRequest($0) }

        let request = CreateOwnerInvoiceRequest(
            clientId:      client.id,
            periodStart:   df.string(from: dateFrom),
            periodEnd:     df.string(from: dateTo),
            issueDate:     df.string(from: issueDate),
            dueDate:       df.string(from: dueDate),
            propertyIds:   Array(selectedPropertyIds),
            items:         itemRequests,
            vatApplicable: vatApplicable,
            vatRate:       vatRate,
            discountType:  discountType,
            discountValue: discountValue,
            notes:         notes.isEmpty ? nil : notes,
            internalNotes: internalNotes.isEmpty ? nil : internalNotes
        )

        do {
            let resp: CreateOwnerInvoiceResponse = try await APIClient.shared.post(
                Endpoint.ownerInvoices, body: request)
            createdInvoiceId = resp.invoice?.id
            isSubmitting = false
        } catch APIError.server(let statusCode, let message) {
            isSubmitting = false
            if let msg = message, msg.localizedCaseInsensitiveContains("OWNER_INVOICE_ITEM_CURRENCY_MISMATCH")
                || msg.localizedCaseInsensitiveContains("article est en") {
                createError = "Devise incompatible : \(msg)"
            } else {
                createError = message ?? "Erreur serveur (\(statusCode))"
            }
        } catch {
            isSubmitting = false
            createError = "Impossible de créer la facture. Vérifiez votre connexion."
        }
    }

    // MARK: - PUT /api/owner-invoices/:id (edit mode)

    func saveChanges() async {
        guard case .edit(let invoiceId) = mode, isReadyToSave else { return }
        isSubmitting = true
        saveError    = nil

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let itemRequests = includedItems.map { buildItemRequest($0) }

        let request = UpdateOwnerInvoiceRequest(
            items:         itemRequests,
            vatApplicable: vatApplicable,
            vatRate:       vatRate,
            discountType:  discountType,
            discountValue: discountValue,
            notes:         notes.isEmpty ? nil : notes,
            internalNotes: internalNotes.isEmpty ? nil : internalNotes,
            issueDate:     df.string(from: issueDate),
            dueDate:       df.string(from: dueDate),
            periodStart:   df.string(from: dateFrom),
            periodEnd:     df.string(from: dateTo)
        )

        do {
            let resp: UpdateOwnerInvoiceResponse = try await APIClient.shared.put(
                Endpoint.ownerInvoice(invoiceId), body: request, agencyAll: true)
            isSubmitting  = false
            saveSucceeded = resp.success == true
            if !saveSucceeded {
                saveError = resp.message ?? "Erreur lors de la modification."
            }
        } catch APIError.server(let statusCode, let message) {
            isSubmitting = false
            if let msg = message {
                if msg.localizedCaseInsensitiveContains("OWNER_INVOICE_DRAFT_CURRENCY_CHANGE_REQUIRES_RECREATE") {
                    saveError = "La devise d'une facture existante ne peut pas être modifiée. Créez un nouveau brouillon pour utiliser cette autre devise."
                } else if msg.localizedCaseInsensitiveContains("OWNER_INVOICE_ITEM_CURRENCY_MISMATCH")
                    || msg.localizedCaseInsensitiveContains("article est en") {
                    saveError = "Devise incompatible : \(msg)"
                } else {
                    saveError = msg
                }
            } else {
                saveError = "Erreur serveur (\(statusCode))"
            }
        } catch {
            isSubmitting = false
            saveError = "Impossible de modifier la facture. Vérifiez votre connexion."
        }
    }

    // MARK: - Shared item request builder

    private func buildItemRequest(_ item: OwnerInvoiceDraftItem) -> CreateOwnerInvoiceItemRequest {
        CreateOwnerInvoiceItemRequest(
            itemType:       item.itemType,
            description:    item.description,
            rentalAmount:   item.rentalAmount,
            commissionRate: item.commissionRate,
            quantity:       item.quantity,
            unitPrice:      item.unitPrice,
            total:          item.lineTotal,
            isDebours:      item.isDebours,
            deboursId:      item.deboursId,
            // Débours n'ont pas de devise propre ; items normaux envoient la devise pour INTL-4.4B
            currency:       item.isDebours ? nil : (item.currency.isEmpty ? nil : item.currency)
        )
    }
}

// MARK: - Double rounding helper (local)

private extension Double {
    func rounded(decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (self * factor).rounded() / factor
    }
}
