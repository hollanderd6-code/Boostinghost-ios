import Foundation
import Testing
@testable import Boostinghost

struct CurrencyModelTests {

    // MARK: - Property

    @Test("Property décode currency: ILS")
    func propertyDecodesCurrencyILS() throws {
        let json = #"{"id":"p1","name":"Tel Aviv","currency":"ILS"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Property.self, from: json)
        #expect(p.currency == "ILS")
    }

    @Test("Property legacy sans currency → nil")
    func propertyLegacyNoCurrency() throws {
        let json = #"{"id":"p1","name":"Paris"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Property.self, from: json)
        #expect(p.currency == nil)
    }

    @Test("Property décode currency: EUR")
    func propertyDecodesCurrencyEUR() throws {
        let json = #"{"id":"p2","name":"Lyon","currency":"EUR"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Property.self, from: json)
        #expect(p.currency == "EUR")
    }

    // MARK: - PricingCalendarProperty

    @Test("PricingCalendarProperty décode currency: ILS")
    func pricingCalendarPropertyDecodesCurrencyILS() throws {
        let json = #"{"basePrice":450,"currency":"ILS"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PricingCalendarProperty.self, from: json)
        #expect(p.currency == "ILS")
        #expect(p.basePrice == 450)
    }

    @Test("PricingCalendarProperty sans currency → nil")
    func pricingCalendarPropertyLegacyNoCurrency() throws {
        let json = #"{"basePrice":120}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PricingCalendarProperty.self, from: json)
        #expect(p.currency == nil)
        #expect(p.basePrice == 120)
    }

    @Test("PricingCalendarProperty price(for:isWeekend:) inchangé après ajout currency")
    func pricingCalendarPropertyPriceUnchanged() throws {
        let json = #"{"basePrice":100,"weekendPrice":130,"currency":"ILS","prices":{"2026-10-01":110}}"#
            .data(using: .utf8)!
        let p = try JSONDecoder().decode(PricingCalendarProperty.self, from: json)
        #expect(p.price(for: "2026-10-01", isWeekend: false) == 110)
        #expect(p.price(for: "2026-10-02", isWeekend: true)  == 130)
        #expect(p.price(for: "2026-10-02", isWeekend: false) == 100)
    }

    // MARK: - PropertySummary

    @Test("PropertySummary décode currency: ILS")
    func propertySummaryDecodesCurrencyILS() throws {
        let json = #"{"id":"p1","name":"Tel Aviv","currency":"ILS"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PropertySummary.self, from: json)
        #expect(p.currency == "ILS")
    }

    @Test("PropertySummary sans currency → nil")
    func propertySummaryNoCurrency() throws {
        let json = #"{"id":"p1","name":"Paris"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(PropertySummary.self, from: json)
        #expect(p.currency == nil)
    }

    @Test("PropertySummary — champs existants inchangés après ajout currency")
    func propertySummaryExistingFieldsPreserved() throws {
        let json = #"{"id":"p1","name":"Lyon","internalName":"Studio 1","currency":"EUR"}"#
            .data(using: .utf8)!
        let p = try JSONDecoder().decode(PropertySummary.self, from: json)
        #expect(p.id == "p1")
        #expect(p.name == "Lyon")
        #expect(p.internalName == "Studio 1")
        #expect(p.displayName == "Studio 1")
        #expect(p.currency == "EUR")
    }

    // MARK: - CalendarViewModel.currency(forPropertyId:)

    @Test("currency(forPropertyId:) — logement inconnu → EUR")
    @MainActor
    func calendarViewModelCurrencyUnknownPropertyFallback() {
        let vm = CalendarViewModel()
        #expect(vm.currency(forPropertyId: "nonexistent") == "EUR")
    }

    @Test("currency(forPropertyId:) — calendarData ILS → ILS")
    @MainActor
    func calendarViewModelCurrencyFromCalendarData() throws {
        let vm = CalendarViewModel()
        let json = #"""
        {"from":"2026-10-01","to":"2026-10-31","properties":{"p1":{"basePrice":450,"currency":"ILS"}}}
        """#.data(using: .utf8)!
        let response = try JSONDecoder().decode(PricingCalendarResponse.self, from: json)
        vm.injectCalendarDataForTesting(response)
        #expect(vm.currency(forPropertyId: "p1") == "ILS")
    }

    @Test("currency(forPropertyId:) — lowercase normalisé")
    @MainActor
    func calendarViewModelCurrencyNormalizesLowercase() throws {
        let vm = CalendarViewModel()
        let json = #"""
        {"from":"2026-10-01","to":"2026-10-31","properties":{"p1":{"basePrice":450,"currency":"ils"}}}
        """#.data(using: .utf8)!
        let response = try JSONDecoder().decode(PricingCalendarResponse.self, from: json)
        vm.injectCalendarDataForTesting(response)
        #expect(vm.currency(forPropertyId: "p1") == "ILS")
    }

    @Test("currency(forPropertyId:) — fallback PropertySummary.currency")
    @MainActor
    func calendarViewModelCurrencyFallbackToPropertySummary() throws {
        let vm = CalendarViewModel()
        // calendarData absent; PropertySummary carries the currency
        let summaryJson = #"{"id":"p1","name":"Tel Aviv","currency":"ILS"}"#.data(using: .utf8)!
        let summary = try JSONDecoder().decode(PropertySummary.self, from: summaryJson)
        vm.injectPropertiesForTesting([summary])
        #expect(vm.currency(forPropertyId: "p1") == "ILS")
    }

    @Test("currency(forPropertyId:) — calendarData prioritaire sur PropertySummary")
    @MainActor
    func calendarViewModelCurrencyCalendarDataTakesPriority() throws {
        let vm = CalendarViewModel()
        // PropertySummary says CHF; calendarData says ILS — calendarData wins
        let summaryJson = #"{"id":"p1","name":"Genève","currency":"CHF"}"#.data(using: .utf8)!
        let summary = try JSONDecoder().decode(PropertySummary.self, from: summaryJson)
        vm.injectPropertiesForTesting([summary])
        let calJson = #"""
        {"from":"2026-10-01","to":"2026-10-31","properties":{"p1":{"basePrice":150,"currency":"ILS"}}}
        """#.data(using: .utf8)!
        let response = try JSONDecoder().decode(PricingCalendarResponse.self, from: calJson)
        vm.injectCalendarDataForTesting(response)
        #expect(vm.currency(forPropertyId: "p1") == "ILS")
    }
}
