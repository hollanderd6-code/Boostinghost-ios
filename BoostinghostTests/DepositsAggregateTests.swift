import Foundation
import Testing
@testable import Boostinghost

struct DepositsAggregateTests {

    // MARK: - Helpers

    private func makeDeposit(id: String, currency: String?, amountCents: Int?) -> ReservationWithDeposit {
        var dict: [String: Any] = ["id": id, "depositId": "d-\(id)"]
        if let c = currency { dict["currency"] = c }
        if let a = amountCents {
            dict["deposit"] = ["id": "dep-\(id)", "amountCents": a]
        } else {
            dict["deposit"] = ["id": "dep-\(id)"]
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(ReservationWithDeposit.self, from: data)
    }

    // MARK: - A: collection vide

    @Test("A-01 tableau vide → .empty")
    func emptyArray() {
        #expect(DepositAggregateCurrencyState.compute(from: []) == .empty)
    }

    @Test("A-02 tous sans amountCents → .empty")
    func allNilAmounts() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: nil),
            makeDeposit(id: "r2", currency: "ILS", amountCents: nil),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .empty)
    }

    // MARK: - B: devise unique EUR

    @Test("B-01 une caution EUR → .single(code: EUR, total)")
    func singleEUR() {
        let deposits = [makeDeposit(id: "r1", currency: "EUR", amountCents: 50000)]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "EUR", total: 500.0))
    }

    @Test("B-02 deux cautions EUR → .single, totaux additionnés")
    func twoEURSummed() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: 50000),
            makeDeposit(id: "r2", currency: "EUR", amountCents: 30000),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "EUR", total: 800.0))
    }

    // MARK: - C: devise unique non-EUR

    @Test("C-01 une caution ILS → .single(code: ILS, total)")
    func singleILS() {
        let deposits = [makeDeposit(id: "r1", currency: "ILS", amountCents: 200000)]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "ILS", total: 2000.0))
    }

    @Test("C-02 une caution USD → .single(code: USD, total)")
    func singleUSD() {
        let deposits = [makeDeposit(id: "r1", currency: "USD", amountCents: 75000)]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "USD", total: 750.0))
    }

    // MARK: - D: devises mixtes

    @Test("D-01 EUR + ILS → .mixed(count: 2)")
    func mixedEURandILS() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: 50000),
            makeDeposit(id: "r2", currency: "ILS", amountCents: 200000),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .mixed(count: 2))
    }

    @Test("D-02 trois devises différentes → .mixed(count: 3)")
    func mixedThreeCurrencies() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: 50000),
            makeDeposit(id: "r2", currency: "ILS", amountCents: 200000),
            makeDeposit(id: "r3", currency: "USD", amountCents: 75000),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .mixed(count: 3))
    }

    // MARK: - E: nil currency traité comme EUR

    @Test("E-01 currency nil normalisé en EUR — combiné avec EUR explicite → .single EUR")
    func nilCurrencyNormalizedToEUR() {
        let deposits = [
            makeDeposit(id: "r1", currency: nil,   amountCents: 50000),
            makeDeposit(id: "r2", currency: "EUR", amountCents: 30000),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "EUR", total: 800.0))
    }

    @Test("E-02 currency nil seul → .single EUR")
    func nilCurrencyAlone() {
        let deposits = [makeDeposit(id: "r1", currency: nil, amountCents: 50000)]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "EUR", total: 500.0))
    }

    @Test("E-03 currency nil + ILS → .mixed (deux devises distinctes)")
    func nilCurrencyWithILS() {
        let deposits = [
            makeDeposit(id: "r1", currency: nil,   amountCents: 50000),
            makeDeposit(id: "r2", currency: "ILS", amountCents: 200000),
        ]
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .mixed(count: 2))
    }

    // MARK: - F: cautions sans montant exclues de la classification

    @Test("F-01 caution sans montant ignorée — reste EUR .single")
    func noAmountDepositIgnored() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: 50000),
            makeDeposit(id: "r2", currency: "ILS", amountCents: nil),
        ]
        // r2 has no amount → excluded → only EUR present → .single
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .single(code: "EUR", total: 500.0))
    }

    @Test("F-02 caution sans montant ignorée — reste .mixed si deux devises avec montant")
    func noAmountDepositDoesNotInfluenceMixed() {
        let deposits = [
            makeDeposit(id: "r1", currency: "EUR", amountCents: 50000),
            makeDeposit(id: "r2", currency: "ILS", amountCents: 200000),
            makeDeposit(id: "r3", currency: "USD", amountCents: nil),
        ]
        // r3 has no amount → excluded → EUR + ILS remain → .mixed(count: 2)
        #expect(DepositAggregateCurrencyState.compute(from: deposits) == .mixed(count: 2))
    }
}
