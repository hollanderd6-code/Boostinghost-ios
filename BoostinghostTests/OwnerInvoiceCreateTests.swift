import Foundation
import Testing
@testable import Boostinghost

struct OwnerInvoiceCreateTests {

    // MARK: - A. InvoiceSummaryBucket — décodage

    @Test("BUCKET-A-01 : décode currency EUR")
    func bucketDecodesEUR() throws {
        let json = #"""
        {"platform":"Airbnb","currency":"EUR","count":3,"totalNet":900,"totalBrut":1100,
         "totalCleaning":60,"totalTaxes":10,"totalOtaCom":50,"bookingPayout":990}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.currency == "EUR")
        #expect(bucket.platform == "Airbnb")
        #expect(bucket.count == 3)
    }

    @Test("BUCKET-A-02 : décode currency ILS")
    func bucketDecodesILS() throws {
        let json = #"""
        {"platform":"Booking","currency":"ILS","count":1,"totalNet":1200,"totalBrut":1350,
         "totalCleaning":80,"totalTaxes":20,"totalOtaCom":70,"bookingPayout":1180}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.currency == "ILS")
    }

    @Test("BUCKET-A-03 : décode currency USD")
    func bucketDecodesUSD() throws {
        let json = #"""
        {"platform":"Vrbo","currency":"USD","count":2,"totalNet":500,"totalBrut":600,
         "totalCleaning":50,"totalTaxes":8,"totalOtaCom":42,"bookingPayout":550}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.currency == "USD")
    }

    @Test("BUCKET-A-04 : décode currency CHF")
    func buckdeDecodesCHF() throws {
        let json = #"""
        {"platform":"Direct","currency":"CHF","count":1,"totalNet":300,"totalBrut":350,
         "totalCleaning":30,"totalTaxes":5,"totalOtaCom":15,"bookingPayout":320}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.currency == "CHF")
    }

    @Test("BUCKET-A-05 : currency nil → normalisé EUR")
    func bucketNilCurrencyFallsToEUR() throws {
        let json = #"""
        {"platform":"Airbnb","count":1,"totalNet":500,"totalBrut":600,
         "totalCleaning":40,"totalTaxes":5,"totalOtaCom":30,"bookingPayout":540}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.currency == "EUR")
    }

    @Test("BUCKET-A-06 : bookingPayout décodé correctement")
    func bucketBookingPayoutDecoded() throws {
        let json = #"""
        {"platform":"Booking","currency":"EUR","count":2,"totalNet":800,"totalBrut":950,
         "totalCleaning":60,"totalTaxes":12,"totalOtaCom":55,"bookingPayout":"883.5"}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.bookingPayout == 883.5)
    }

    // MARK: - B. InvoiceSummaryReservation — décodage

    @Test("RESA-B-01 : décode champs de base")
    func reservationDecodesBasicFields() throws {
        let json = #"""
        {"id":"42","guestName":"Alice","dateFrom":"2026-09-01","dateTo":"2026-09-07",
         "platform":"Airbnb","currency":"EUR","totalBrut":500,"totalNet":450}
        """#.data(using: .utf8)!
        let resa = try JSONDecoder().decode(InvoiceSummaryReservation.self, from: json)
        #expect(resa.id == "42")
        #expect(resa.guestName == "Alice")
        #expect(resa.platform == "Airbnb")
        #expect(resa.currency == "EUR")
    }

    @Test("RESA-B-02 : id manquant → UUID généré")
    func reservationMissingIdGetsUUID() throws {
        let json = #"{"platform":"Direct","currency":"ILS"}"#.data(using: .utf8)!
        let resa = try JSONDecoder().decode(InvoiceSummaryReservation.self, from: json)
        #expect(!resa.id.isEmpty)
    }

    // MARK: - C. OwnerInvoiceDraftItem — calculs

    @Test("DRAFT-C-01 : lineTotal commission 15%")
    func draftItemLineTotalCommission15() {
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 1000
        item.commissionRate = 15
        #expect(item.lineTotal == 150.0)
    }

    @Test("DRAFT-C-02 : lineTotal commission 20%")
    func draftItemLineTotalCommission20() {
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "ILS")
        item.rentalAmount   = 500
        item.commissionRate = 20
        #expect(item.lineTotal == 100.0)
    }

    @Test("DRAFT-C-03 : currency préservée sur le brouillon")
    func draftItemCurrencyPreserved() {
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "USD")
        #expect(item.currency == "USD")
    }

    @Test("DRAFT-C-04 : id unique par instance")
    func draftItemUniqueIds() {
        let a = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        let b = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        #expect(a.id != b.id)
    }

    // MARK: - D. ViewModel — logique de sélection et devises mixtes

    @Test("VM-D-01 : selectedCurrency nil quand aucune propriété sélectionnée")
    @MainActor
    func viewModelSelectedCurrencyNilWhenEmpty() {
        let vm = OwnerInvoiceCreateViewModel()
        #expect(vm.selectedCurrency == nil)
    }

    @Test("VM-D-02 : isCurrencyCompatible false si currency nil")
    @MainActor
    func viewModelIncompatibleWhenNoCurrency() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let json = #"{"id":"p1","name":"Test"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: json)
        #expect(vm.isCurrencyCompatible(prop) == false)
    }

    @Test("VM-D-03 : isCurrencyCompatible true quand aucune sélection et currency présente")
    @MainActor
    func viewModelCompatibleWhenNothingSelected() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let json = #"{"id":"p1","name":"Test","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: json)
        #expect(vm.isCurrencyCompatible(prop) == true)
    }

    @Test("VM-D-04 : isCurrencyCompatible false si devises différentes")
    @MainActor
    func viewModelIncompatibleMismatchCurrency() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let jsonEUR = #"{"id":"p1","name":"Paris","currency":"EUR","owner_id":"42"}"#.data(using: .utf8)!
        let jsonILS = #"{"id":"p2","name":"TLV","currency":"ILS","owner_id":"42"}"#.data(using: .utf8)!
        let propEUR = try JSONDecoder().decode(Property.self, from: jsonEUR)
        let propILS = try JSONDecoder().decode(Property.self, from: jsonILS)
        vm.ownerProperties = [propEUR, propILS]
        vm.selectedPropertyIds = ["p1"]
        #expect(vm.selectedCurrency == "EUR")
        #expect(vm.isCurrencyCompatible(propILS) == false)
    }

    @Test("VM-D-05 : resetSummary vide les buckets et items")
    @MainActor
    func viewModelResetSummaryClears() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let json = #"""
        {"platform":"Airbnb","currency":"EUR","count":1,"totalNet":500,"totalBrut":600,
         "totalCleaning":40,"totalTaxes":5,"totalOtaCom":30,"bookingPayout":540}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        vm.summaryBuckets = [bucket]
        vm.draftItems = [OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")]
        vm.resetSummary()
        #expect(vm.summaryBuckets.isEmpty)
        #expect(vm.draftItems.isEmpty)
    }

    // MARK: - E. InvoiceSummaryResponse — décodage complet

    @Test("RESP-E-01 : réponse summary décodée")
    func responseSummaryDecoded() throws {
        let json = #"""
        {
          "summary": [
            {"platform":"Airbnb","currency":"EUR","count":2,"totalNet":800,"totalBrut":950,
             "totalCleaning":60,"totalTaxes":10,"totalOtaCom":45,"bookingPayout":845},
            {"platform":"Booking","currency":"ILS","count":1,"totalNet":1200,"totalBrut":1350,
             "totalCleaning":80,"totalTaxes":20,"totalOtaCom":60,"bookingPayout":1190}
          ],
          "reservations": []
        }
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(InvoiceSummaryResponse.self, from: json)
        #expect(resp.summary.count == 2)
        #expect(resp.summary[0].platform == "Airbnb")
        #expect(resp.summary[1].currency == "ILS")
    }

    @Test("RESP-E-02 : réponse sans reservations → tableau vide")
    func responseMissingReservationsEmpty() throws {
        let json = #"""
        {"summary":[]}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(InvoiceSummaryResponse.self, from: json)
        #expect(resp.reservations.isEmpty)
    }

    @Test("RESP-E-03 : id bucket composite platform::currency")
    func bucketIdIsComposite() throws {
        let json = #"""
        {"platform":"Airbnb","currency":"ILS","count":1,"totalNet":500,"totalBrut":600,
         "totalCleaning":40,"totalTaxes":5,"totalOtaCom":30,"bookingPayout":540}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: json)
        #expect(bucket.id == "Airbnb::ILS")
    }

    // MARK: - F. État initial du ViewModel — période par défaut

    @Test("VM-F-01 : dateFrom dans le mois précédent")
    @MainActor
    func viewModelDefaultDateFromInPrevMonth() {
        let vm = OwnerInvoiceCreateViewModel()
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        #expect(vm.dateFrom < startOfThisMonth)
    }

    @Test("VM-F-02 : dateTo avant le début du mois courant")
    @MainActor
    func viewModelDefaultDateToBeforeCurrentMonth() {
        let vm = OwnerInvoiceCreateViewModel()
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        #expect(vm.dateTo < startOfThisMonth)
    }

    @Test("VM-F-03 : selectedPropertyIds vide à l'init")
    @MainActor
    func viewModelInitialPropertyIdsEmpty() {
        let vm = OwnerInvoiceCreateViewModel()
        #expect(vm.selectedPropertyIds.isEmpty)
    }

    // MARK: - G. Encode CreateOwnerInvoiceItemRequest

    @Test("ENC-G-01 : item importé EUR — currency dans la requête")
    func encodeImportedEURItemCurrency() throws {
        let item = CreateOwnerInvoiceItemRequest(
            itemType: "commission", description: "Commissions Airbnb",
            rentalAmount: 990, commissionRate: 20,
            quantity: 1, unitPrice: 0, total: 198,
            isDebours: false, deboursId: nil, currency: "EUR"
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["currency"] as? String == "EUR")
    }

    @Test("ENC-G-02 : item importé ILS — currency dans la requête")
    func encodeImportedILSItemCurrency() throws {
        let item = CreateOwnerInvoiceItemRequest(
            itemType: "commission", description: "Commissions Booking",
            rentalAmount: 1180, commissionRate: 15,
            quantity: 1, unitPrice: 0, total: 177,
            isDebours: false, deboursId: nil, currency: "ILS"
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["currency"] as? String == "ILS")
    }

    @Test("ENC-G-03 : item manuel — itemType, description, currency encodés")
    func encodeManualItemFields() throws {
        let item = CreateOwnerInvoiceItemRequest(
            itemType: "cleaning", description: "Frais de ménage",
            rentalAmount: 0, commissionRate: 0,
            quantity: 1, unitPrice: 80, total: 80,
            isDebours: false, deboursId: nil, currency: "USD"
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["itemType"] as? String == "cleaning")
        #expect(dict["description"] as? String == "Frais de ménage")
        #expect(dict["currency"] as? String == "USD")
    }

    // MARK: - H. Garde devise — hasCurrencyMismatch

    @Test("MISMATCH-H-01 : item EUR inclus sur facture ILS → hasCurrencyMismatch true")
    @MainActor
    func currencyMismatchEUROnILSInvoice() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.isIncluded = true
        vm.draftItems = [item]
        #expect(vm.hasCurrencyMismatch == true)
    }

    @Test("MISMATCH-H-02 : item ILS inclus sur facture ILS → hasCurrencyMismatch false")
    @MainActor
    func currencyMatchILSOnILSInvoice() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "ILS")
        vm.draftItems = [item]
        #expect(vm.hasCurrencyMismatch == false)
    }

    @Test("MISMATCH-H-03 : item incompatible isIncluded=false reste dans draftItems")
    func historicalIncompatibleItemExcluded() throws {
        let bucketJSON = #"""
        {"platform":"Airbnb","currency":"EUR","count":2,"totalNet":800,"totalBrut":950,
         "totalCleaning":60,"totalTaxes":10,"totalOtaCom":45,"bookingPayout":845}
        """#.data(using: .utf8)!
        let bucket = try JSONDecoder().decode(InvoiceSummaryBucket.self, from: bucketJSON)
        let item = OwnerInvoiceDraftItem(importedFrom: bucket, commissionRate: 20, isCompatible: false)
        #expect(item.isIncluded == false)
        #expect(item.isImported == true)
    }

    // MARK: - I. lineTotal — calculs étendus

    @Test("CALC-I-01 : lineTotal commission taux décimal 12.5%")
    func lineTotalCommissionDecimalRate() {
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 990
        item.commissionRate = 12.5
        #expect(item.lineTotal == 123.75)
    }

    @Test("CALC-I-02 : lineTotal forfait qty × unitPrice")
    func lineTotalForfaitQtyTimesPrice() {
        var item = OwnerInvoiceDraftItem(itemType: "cleaning", currency: "EUR")
        item.quantity  = 3
        item.unitPrice = 75
        #expect(item.lineTotal == 225.0)
    }

    @Test("CALC-I-03 : lineTotal forfait arrondi 2 décimales")
    func lineTotalForfaitRounded() {
        var item = OwnerInvoiceDraftItem(itemType: "other", currency: "EUR")
        item.quantity  = 3
        item.unitPrice = 33.333
        #expect(item.lineTotal == 100.0)
    }

    // MARK: - J. ViewModel — totaux TVA et remise

    @Test("TOTALS-J-01 : vatAmount = netHt × vatRate / 100 si vatApplicable true")
    @MainActor
    func vatAmountCalculated() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 1000
        item.commissionRate = 20
        item.isIncluded     = true
        vm.draftItems    = [item]
        vm.vatApplicable = true
        vm.vatRate       = 20.0
        #expect(vm.vatAmount == 40.0)
    }

    @Test("TOTALS-J-02 : vatAmount = 0 si vatApplicable false")
    @MainActor
    func vatAmountZeroWhenDisabled() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 1000
        item.commissionRate = 20
        vm.draftItems    = [item]
        vm.vatApplicable = false
        #expect(vm.vatAmount == 0.0)
    }

    @Test("TOTALS-J-03 : discountAmount percent 10% du subtotalHt")
    @MainActor
    func discountAmountPercent() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 1000
        item.commissionRate = 20
        vm.draftItems    = [item]
        vm.discountType  = "percent"
        vm.discountValue = 10.0
        #expect(vm.discountAmount == 20.0)
    }

    @Test("TOTALS-J-04 : discountAmount fixed 50")
    @MainActor
    func discountAmountFixed() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.rentalAmount   = 1000
        item.commissionRate = 20
        vm.draftItems    = [item]
        vm.discountType  = "fixed"
        vm.discountValue = 50.0
        #expect(vm.discountAmount == 50.0)
    }

    // MARK: - K. CreateOwnerInvoiceRequest — encodage

    @Test("REQ-K-01 : request encode clientId")
    func requestEncodesClientId() throws {
        let request = CreateOwnerInvoiceRequest(
            clientId: "client-42",
            periodStart: nil, periodEnd: nil,
            issueDate: "2026-09-29", dueDate: "2026-10-29",
            propertyIds: [],
            items: [],
            vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["clientId"] as? String == "client-42")
    }

    @Test("REQ-K-02 : request encode discountType none")
    func requestEncodesDiscountTypeNone() throws {
        let request = CreateOwnerInvoiceRequest(
            clientId: "c1",
            periodStart: nil, periodEnd: nil,
            issueDate: "2026-09-29", dueDate: "2026-10-29",
            propertyIds: [],
            items: [],
            vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["discountType"] as? String == "none")
    }

    @Test("REQ-K-03 : request encode vatApplicable false")
    func requestEncodesVatApplicableFalse() throws {
        let request = CreateOwnerInvoiceRequest(
            clientId: "c1",
            periodStart: nil, periodEnd: nil,
            issueDate: "2026-09-29", dueDate: "2026-10-29",
            propertyIds: [],
            items: [],
            vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["vatApplicable"] as? Bool == false)
    }

    @Test("REQ-K-04 : request encode propertyIds comme tableau")
    func requestEncodesPropertyIds() throws {
        let request = CreateOwnerInvoiceRequest(
            clientId: "c1",
            periodStart: nil, periodEnd: nil,
            issueDate: "2026-09-29", dueDate: "2026-10-29",
            propertyIds: ["p1", "p2"],
            items: [],
            vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ids = dict["propertyIds"] as? [String]
        #expect(ids?.count == 2)
        #expect(ids?.contains("p1") == true)
    }

    @Test("REQ-K-05 : currency item survit à l'encodage (INTL-4.4B)")
    func requestEncodesItemCurrencyIntl4B() throws {
        let item = CreateOwnerInvoiceItemRequest(
            itemType: "commission", description: "Commissions Direct",
            rentalAmount: 845, commissionRate: 20,
            quantity: 1, unitPrice: 0, total: 169,
            isDebours: false, deboursId: nil, currency: "CHF"
        )
        let request = CreateOwnerInvoiceRequest(
            clientId: "c1",
            periodStart: nil, periodEnd: nil,
            issueDate: "2026-09-29", dueDate: "2026-10-29",
            propertyIds: [],
            items: [item],
            vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil
        )
        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let items = dict["items"] as? [[String: Any]]
        #expect(items?.first?["currency"] as? String == "CHF")
    }

    // MARK: - L. CreateOwnerInvoiceResponse — décodage

    @Test("RESP-L-01 : réponse décode invoice.id et status draft")
    func createResponseDecodesInvoice() throws {
        let json = #"""
        {"invoice":{"id":"inv-001","status":"draft","invoiceNumber":"DRAFT-001",
         "totalTtc":198.0,"currency":"EUR","clientId":"42"}}
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(CreateOwnerInvoiceResponse.self, from: json)
        #expect(resp.invoice?.id == "inv-001")
        #expect(resp.invoice?.status == "draft")
    }

    @Test("RESP-L-02 : réponse sans invoice → nil")
    func createResponseMissingInvoiceIsNil() throws {
        let json = #"{}"#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(CreateOwnerInvoiceResponse.self, from: json)
        #expect(resp.invoice == nil)
    }

    // MARK: - M. isReadyToCreate — gardes

    @Test("GUARD-M-01 : isReadyToCreate false sans includedItems")
    @MainActor
    func isReadyFalseWithoutItems() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let clientJSON = #"{"id":"42"}"#.data(using: .utf8)!
        let client = try JSONDecoder().decode(OwnerClient.self, from: clientJSON)
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        vm.selectedClient = client
        #expect(vm.isReadyToCreate == false)
    }

    @Test("GUARD-M-02 : isReadyToCreate false sans selectedClient")
    @MainActor
    func isReadyFalseWithoutClient() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        vm.draftItems = [item]
        #expect(vm.isReadyToCreate == false)
    }

    @Test("GUARD-M-03 : isReadyToCreate false sans selectedPropertyIds")
    @MainActor
    func isReadyFalseWithoutProperty() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let clientJSON = #"{"id":"42"}"#.data(using: .utf8)!
        let client = try JSONDecoder().decode(OwnerClient.self, from: clientJSON)
        vm.selectedClient = client
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        vm.draftItems = [item]
        #expect(vm.isReadyToCreate == false)
    }

    @Test("GUARD-M-04 : isReadyToCreate false si hasCurrencyMismatch")
    @MainActor
    func isReadyFalseWhenCurrencyMismatch() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let clientJSON = #"{"id":"42"}"#.data(using: .utf8)!
        let client = try JSONDecoder().decode(OwnerClient.self, from: clientJSON)
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.selectedClient = client
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.isIncluded = true
        vm.draftItems = [item]
        #expect(vm.hasCurrencyMismatch == true)
        #expect(vm.isReadyToCreate == false)
    }

    @Test("GUARD-M-05 : isReadyToCreate false si isSubmitting (prévient double envoi)")
    @MainActor
    func isReadyFalseWhenSubmitting() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let clientJSON = #"{"id":"42"}"#.data(using: .utf8)!
        let client = try JSONDecoder().decode(OwnerClient.self, from: clientJSON)
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.selectedClient = client
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        vm.draftItems   = [item]
        vm.isSubmitting = true
        #expect(vm.isReadyToCreate == false)
    }

    // MARK: - N. Actions ViewModel

    @Test("RESET-N-01 : selectClient vide selectedPropertyIds et draftItems")
    @MainActor
    func selectClientClearsPropertiesAndItems() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"Paris","currency":"EUR"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        vm.draftItems = [OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")]
        let clientJSON = #"{"id":"99"}"#.data(using: .utf8)!
        let newClient = try JSONDecoder().decode(OwnerClient.self, from: clientJSON)
        vm.selectClient(newClient)
        #expect(vm.selectedPropertyIds.isEmpty)
        #expect(vm.draftItems.isEmpty)
    }

    @Test("ITEMS-N-02 : addManualItem ajoute un item avec la devise de la facture")
    @MainActor
    func addManualItemUsesInvoiceCurrency() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        vm.addManualItem(itemType: "cleaning")
        #expect(vm.draftItems.count == 1)
        #expect(vm.draftItems.first?.itemType == "cleaning")
        #expect(vm.draftItems.first?.currency == "ILS")
    }

    // MARK: - O. OwnerInvoiceEditFields — décodage

    @Test("EDIT-O-01 : OwnerInvoiceEditFields décode tous les champs")
    func editFieldsDecodesAllFields() throws {
        let json = #"""
        {"id":"inv-001","status":"draft","currency":"EUR","clientId":"42","clientName":"Jean Dupont",
         "issueDate":"2026-09-01","dueDate":"2026-09-30","periodStart":"2026-08-01","periodEnd":"2026-08-31",
         "vatApplicable":true,"vatRate":20.0,"discountType":"percent","discountValue":5.0,
         "notes":"Note client","internalNotes":"Note interne"}
        """#.data(using: .utf8)!
        let fields = try JSONDecoder().decode(OwnerInvoiceEditFields.self, from: json)
        #expect(fields.id == "inv-001")
        #expect(fields.status == "draft")
        #expect(fields.currency == "EUR")
        #expect(fields.clientName == "Jean Dupont")
        #expect(fields.vatApplicable == true)
        #expect(fields.vatRate == 20.0)
        #expect(fields.discountType == "percent")
        #expect(fields.notes == "Note client")
        #expect(fields.internalNotes == "Note interne")
    }

    @Test("EDIT-O-02 : OwnerInvoiceEditFields champs optionnels absents → nil")
    func editFieldsMissingOptionalsAreNil() throws {
        let json = #"{"id":"inv-002","status":"draft"}"#.data(using: .utf8)!
        let fields = try JSONDecoder().decode(OwnerInvoiceEditFields.self, from: json)
        #expect(fields.id == "inv-002")
        #expect(fields.currency == nil)
        #expect(fields.clientName == nil)
        #expect(fields.vatApplicable == nil)
        #expect(fields.notes == nil)
    }

    // MARK: - P. OwnerInvoiceDraftItem.init(fromExisting:)

    @Test("FROMEX-P-01 : commission depuis DB — rentalAmount peuplé, unitPrice 0")
    func fromExistingCommissionRentalAmount() throws {
        let json = #"""
        {"itemType":"commission","description":"Commissions Airbnb",
         "rentalAmount":990,"commissionRate":20,"quantity":1,"unitPrice":0,"total":198,"orderIndex":1}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")
        #expect(item.itemType == "commission")
        #expect(item.rentalAmount == 990)
        #expect(item.unitPrice == 0)
        #expect(item.commissionRate == 20)
    }

    @Test("FROMEX-P-02 : forfait depuis DB — unitPrice peuplé")
    func fromExistingCleaningUnitPrice() throws {
        let json = #"""
        {"itemType":"cleaning","description":"Frais ménage",
         "rentalAmount":0,"commissionRate":0,"quantity":2,"unitPrice":75,"total":150,"orderIndex":2}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")
        #expect(item.itemType == "cleaning")
        #expect(item.unitPrice == 75)
        #expect(item.quantity == 2)
    }

    @Test("FROMEX-P-03 : débours depuis DB — isDebours true, unitPrice = total DB")
    func fromExistingDebours() throws {
        let json = #"""
        {"itemType":"other","description":"Taxe de séjour",
         "rentalAmount":0,"commissionRate":0,"quantity":1,"unitPrice":0,"total":45.0,
         "orderIndex":3,"isDebours":true,"deboursId":"deb-001"}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")
        #expect(item.isDebours == true)
        #expect(item.deboursId == "deb-001")
        #expect(item.unitPrice == 45.0)
        #expect(item.rentalAmount == 0)
    }

    @Test("FROMEX-P-04 : type inconnu depuis DB — préservé, isIncluded true")
    func fromExistingUnknownTypePreserved() throws {
        let json = #"""
        {"itemType":"custom_legacy","description":"Prestation spéciale",
         "rentalAmount":0,"commissionRate":0,"quantity":1,"unitPrice":120,"total":120,"orderIndex":4}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")
        #expect(item.itemType == "custom_legacy")
        #expect(item.isIncluded == true)
        #expect(item.isDebours == false)
    }

    @Test("FROMEX-P-05 : fromExisting hérite invoiceCurrency (pas de devise propre en DB)")
    func fromExistingInheritsInvoiceCurrency() throws {
        let json = #"""
        {"itemType":"commission","description":"Commissions Booking",
         "rentalAmount":1180,"commissionRate":15,"quantity":1,"unitPrice":0,"total":177,"orderIndex":1}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "ILS")
        #expect(item.currency == "ILS")
    }

    // MARK: - Q. invoiceCurrencySnapshot — autorité en mode édition

    @Test("SNAP-Q-01 : snapshot EUR prend le dessus sur propriété ILS sélectionnée")
    @MainActor
    func snapshotOverridesPropertyCurrency() throws {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        #expect(vm.invoiceCurrency == "EUR")
    }

    @Test("SNAP-Q-02 : sans snapshot, repli sur première propriété sélectionnée")
    @MainActor
    func noSnapshotFallsBackToProperty() throws {
        let vm = OwnerInvoiceCreateViewModel()
        let propJSON = #"{"id":"p1","name":"TLV","currency":"ILS"}"#.data(using: .utf8)!
        let prop = try JSONDecoder().decode(Property.self, from: propJSON)
        vm.ownerProperties = [prop]
        vm.selectedPropertyIds = ["p1"]
        #expect(vm.invoiceCurrency == "ILS")
    }

    // MARK: - R. isEditMode et isReadyToSave

    @Test("EDIT-R-01 : isEditMode true en mode .edit")
    @MainActor
    func isEditModeTrue() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        #expect(vm.isEditMode == true)
    }

    @Test("EDIT-R-02 : isEditMode false en mode .create")
    @MainActor
    func isEditModeFalse() {
        let vm = OwnerInvoiceCreateViewModel()
        #expect(vm.isEditMode == false)
    }

    @Test("EDIT-R-03 : isReadyToSave false sans includedItems")
    @MainActor
    func isReadyToSaveFalseWithoutItems() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"
        #expect(vm.isReadyToSave == false)
    }

    @Test("EDIT-R-04 : isReadyToSave false si isSubmitting")
    @MainActor
    func isReadyToSaveFalseWhenSubmitting() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        item.isIncluded = true
        vm.draftItems   = [item]
        vm.isSubmitting = true
        #expect(vm.isReadyToSave == false)
    }

    @Test("EDIT-R-05 : isReadyToSave false si hasCurrencyMismatch")
    @MainActor
    func isReadyToSaveFalseWhenMismatch() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"
        var item = OwnerInvoiceDraftItem(itemType: "commission", currency: "ILS")
        item.isIncluded = true
        vm.draftItems = [item]
        #expect(vm.hasCurrencyMismatch == true)
        #expect(vm.isReadyToSave == false)
    }

    @Test("EDIT-R-06 : isReadyToSave true avec item inclus devise correcte")
    @MainActor
    func isReadyToSaveTrueWithValidState() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"
        let item = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        vm.draftItems = [item]
        #expect(vm.isReadyToSave == true)
    }

    // MARK: - S. UpdateOwnerInvoiceRequest — encodage et réponse

    @Test("PUT-S-01 : UpdateOwnerInvoiceRequest encode items + vatApplicable + discountType")
    func updateRequestEncodesMainFields() throws {
        let item = CreateOwnerInvoiceItemRequest(
            itemType: "commission", description: "Commissions",
            rentalAmount: 990, commissionRate: 20,
            quantity: 1, unitPrice: 0, total: 198,
            isDebours: false, deboursId: nil, currency: "EUR"
        )
        let req = UpdateOwnerInvoiceRequest(
            items: [item], vatApplicable: true, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil,
            issueDate: nil, dueDate: nil, periodStart: nil, periodEnd: nil
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["vatApplicable"] as? Bool == true)
        #expect(dict["discountType"] as? String == "none")
        let items = dict["items"] as? [[String: Any]]
        #expect(items?.count == 1)
    }

    @Test("PUT-S-02 : UpdateOwnerInvoiceRequest nil dates → clés absentes du JSON")
    func updateRequestHasNoDates() throws {
        let req = UpdateOwnerInvoiceRequest(
            items: [], vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil,
            issueDate: nil, dueDate: nil, periodStart: nil, periodEnd: nil
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["issueDate"] == nil)
        #expect(dict["dueDate"] == nil)
        #expect(dict["periodStart"] == nil)
        #expect(dict["periodEnd"] == nil)
    }

    @Test("PUT-S-03 : UpdateOwnerInvoiceResponse décode success + message")
    func updateResponseDecodesSuccessAndMessage() throws {
        let json = #"{"success":true,"message":"Facture modifiée"}"#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(UpdateOwnerInvoiceResponse.self, from: json)
        #expect(resp.success == true)
        #expect(resp.message == "Facture modifiée")
    }

    // MARK: - T. lineTotal débours et type inconnu

    @Test("LINE-T-01 : débours lineTotal = quantité × unitPrice (branche isDebours)")
    func lineTotalDebours() {
        var item = OwnerInvoiceDraftItem(itemType: "other", currency: "EUR")
        item.isDebours = true
        item.quantity  = 2
        item.unitPrice = 30.0
        #expect(item.lineTotal == 60.0)
    }

    @Test("LINE-T-02 : type inconnu lineTotal = quantité × unitPrice")
    func lineTotalUnknownType() throws {
        let json = #"""
        {"itemType":"custom_legacy","description":"Prestation",
         "rentalAmount":0,"commissionRate":0,"quantity":3,"unitPrice":50,"total":150,"orderIndex":1}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let item = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")
        #expect(item.lineTotal == 150.0)
    }

    // MARK: - U. Mutations ViewModel en mode édition

    @Test("EDIT-U-01 : addManualItem en mode edit utilise invoiceCurrencySnapshot")
    @MainActor
    func addManualItemUsesSnapshotInEditMode() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "ILS"
        vm.addManualItem(itemType: "cleaning")
        #expect(vm.draftItems.first?.currency == "ILS")
    }

    @Test("EDIT-U-02 : removeItem supprime uniquement l'item ciblé")
    @MainActor
    func removeItemTargetsCorrectItem() {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        let a = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        let b = OwnerInvoiceDraftItem(itemType: "cleaning",   currency: "EUR")
        vm.draftItems = [a, b]
        vm.removeItem(id: a.id)
        #expect(vm.draftItems.count == 1)
        #expect(vm.draftItems.first?.id == b.id)
    }

    // MARK: - V. OwnerInvoiceEditLoadResponse — décodage complet

    @Test("LOAD-V-01 : OwnerInvoiceEditLoadResponse décode invoice + items + properties")
    func editLoadResponseDecodesAll() throws {
        let json = #"""
        {
          "invoice": {"id":"inv-001","status":"draft","currency":"EUR","clientName":"Test"},
          "items": [
            {"itemType":"commission","description":"Commissions",
             "rentalAmount":990,"commissionRate":20,"quantity":1,"unitPrice":0,"total":198,"orderIndex":1}
          ],
          "properties": [
            {"id":"p1","name":"Paris"}
          ]
        }
        """#.data(using: .utf8)!
        let resp = try JSONDecoder().decode(OwnerInvoiceEditLoadResponse.self, from: json)
        #expect(resp.invoice.id == "inv-001")
        #expect(resp.invoice.currency == "EUR")
        #expect(resp.items.count == 1)
        #expect(resp.items.first?.itemType == "commission")
        #expect(resp.properties.count == 1)
        #expect(resp.properties.first?.id == "p1")
    }

    // MARK: - W. UpdateOwnerInvoiceRequest — dates incluses (2D)

    @Test("PUT-W-01 : UpdateOwnerInvoiceRequest encode issueDate + dueDate + period")
    func updateRequestEncodesDates() throws {
        let req = UpdateOwnerInvoiceRequest(
            items: [], vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil,
            issueDate: "2026-09-01", dueDate: "2026-10-01",
            periodStart: "2026-08-01", periodEnd: "2026-08-31"
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["issueDate"] as? String == "2026-09-01")
        #expect(dict["dueDate"]   as? String == "2026-10-01")
        #expect(dict["periodStart"] as? String == "2026-08-01")
        #expect(dict["periodEnd"]   as? String == "2026-08-31")
    }

    @Test("PUT-W-02 : UpdateOwnerInvoiceRequest encode nil dates quand non renseignées")
    func updateRequestNilDatesEncoded() throws {
        let req = UpdateOwnerInvoiceRequest(
            items: [], vatApplicable: false, vatRate: 20,
            discountType: "none", discountValue: 0,
            notes: nil, internalNotes: nil,
            issueDate: nil, dueDate: nil,
            periodStart: nil, periodEnd: nil
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // nil String? → key absent in JSON (default Encodable behaviour)
        #expect(dict["issueDate"] == nil)
        #expect(dict["dueDate"]   == nil)
    }

    @Test("PUT-W-03 : discountType 'percent' encodé sans transformation")
    func updateRequestPercentEncoded() throws {
        let req = UpdateOwnerInvoiceRequest(
            items: [], vatApplicable: false, vatRate: 20,
            discountType: "percent", discountValue: 10,
            notes: nil, internalNotes: nil,
            issueDate: nil, dueDate: nil,
            periodStart: nil, periodEnd: nil
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["discountType"] as? String == "percent")
    }

    // MARK: - X. Unknown item roundtrip (2D)

    @Test("ROUND-X-01 : type inconnu roundtrip via buildItemRequest-equivalent")
    func unknownItemTypeRoundtrip() throws {
        let json = #"""
        {"itemType":"custom_legacy","description":"Prestation spéciale",
         "rentalAmount":0,"commissionRate":0,"quantity":1,"unitPrice":200,"total":200,"orderIndex":1}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let draftItem = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")

        // Encode via CreateOwnerInvoiceItemRequest (same as buildItemRequest)
        let req = CreateOwnerInvoiceItemRequest(
            itemType: draftItem.itemType,
            description: draftItem.description,
            rentalAmount: draftItem.rentalAmount,
            commissionRate: draftItem.commissionRate,
            quantity: draftItem.quantity,
            unitPrice: draftItem.unitPrice,
            total: draftItem.lineTotal,
            isDebours: draftItem.isDebours,
            deboursId: draftItem.deboursId,
            currency: draftItem.currency.isEmpty ? nil : draftItem.currency
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // itemType preserved exactly
        #expect(dict["itemType"] as? String == "custom_legacy")
        // total preserved
        #expect(dict["total"] as? Double == 200.0)
        // isDebours false
        #expect(dict["isDebours"] as? Bool == false)
    }

    @Test("ROUND-X-02 : débours roundtrip — deboursId + isDebours true + total correct")
    func debourRoundtrip() throws {
        let json = #"""
        {"itemType":"other","description":"Taxe de séjour",
         "rentalAmount":0,"commissionRate":0,"quantity":1,"unitPrice":0,"total":45.0,
         "orderIndex":1,"isDebours":true,"deboursId":"deb-42"}
        """#.data(using: .utf8)!
        let dbItem = try JSONDecoder().decode(OwnerInvoiceItem.self, from: json)
        let draftItem = OwnerInvoiceDraftItem(fromExisting: dbItem, invoiceCurrency: "EUR")

        let req = CreateOwnerInvoiceItemRequest(
            itemType: draftItem.itemType,
            description: draftItem.description,
            rentalAmount: draftItem.rentalAmount,
            commissionRate: draftItem.commissionRate,
            quantity: draftItem.quantity,
            unitPrice: draftItem.unitPrice,
            total: draftItem.lineTotal,
            isDebours: draftItem.isDebours,
            deboursId: draftItem.deboursId,
            currency: draftItem.isDebours ? nil : (draftItem.currency.isEmpty ? nil : draftItem.currency)
        )
        let data = try JSONEncoder().encode(req)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["isDebours"] as? Bool == true)
        #expect(dict["deboursId"] as? String == "deb-42")
        #expect(dict["total"] as? Double == 45.0)
        // Débours: currency nil (INTL-DEBOUR)
        #expect(dict["currency"] == nil)
    }

    @Test("ROUND-X-03 : draft avec commission + custom + débours — 3 items tous présents")
    @MainActor
    func threeItemTypesDraftAllPresent() throws {
        let vm = OwnerInvoiceCreateViewModel(mode: .edit("inv-001"))
        vm.invoiceCurrencySnapshot = "EUR"

        // Commission item
        let commItem = OwnerInvoiceDraftItem(itemType: "commission", currency: "EUR")
        // Custom unknown item
        var customItem = OwnerInvoiceDraftItem(itemType: "legacy_fee", currency: "EUR")
        customItem.unitPrice = 50
        customItem.quantity  = 1
        // Debours
        var debItem = OwnerInvoiceDraftItem(itemType: "other", currency: "EUR")
        debItem.isDebours  = true
        debItem.unitPrice  = 30
        debItem.quantity   = 1

        vm.draftItems = [commItem, customItem, debItem]

        #expect(vm.draftItems.count == 3)
        #expect(vm.includedItems.count == 3)
        // Debours non supprimable
        let isDeletableDebours = !debItem.isDebours && ["commission","cleaning","other"].contains(debItem.itemType)
        #expect(isDeletableDebours == false)
        // Custom non supprimable
        let isDeletableCustom = !customItem.isDebours && ["commission","cleaning","other"].contains(customItem.itemType)
        #expect(isDeletableCustom == false)
        // Commission supprimable
        let isDeletableComm = !commItem.isDebours && ["commission","cleaning","other"].contains(commItem.itemType)
        #expect(isDeletableComm == true)
    }
}
