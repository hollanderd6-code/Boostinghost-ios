import Foundation
import Testing
@testable import Boostinghost

struct FormattersTests {

    // MARK: - normalizeCurrency

    @Test("normalizeCurrency nil → EUR")
    func normNil() { #expect(Formatters.normalizeCurrency(nil) == "EUR") }

    @Test("normalizeCurrency vide → EUR")
    func normEmpty() { #expect(Formatters.normalizeCurrency("") == "EUR") }

    @Test("normalizeCurrency espace → EUR")
    func normWhitespace() { #expect(Formatters.normalizeCurrency("   ") == "EUR") }

    @Test("normalizeCurrency EURO (4 lettres) → EUR")
    func normEURO() { #expect(Formatters.normalizeCurrency("EURO") == "EUR") }

    @Test("normalizeCurrency eur (lowercase) → EUR")
    func normLowercaseEur() { #expect(Formatters.normalizeCurrency("eur") == "EUR") }

    @Test("normalizeCurrency ils → ILS")
    func normLowercaseILS() { #expect(Formatters.normalizeCurrency("ils") == "ILS") }

    @Test("normalizeCurrency USD → USD")
    func normUSD() { #expect(Formatters.normalizeCurrency("USD") == "USD") }

    @Test("normalizeCurrency CHF → CHF")
    func normCHF() { #expect(Formatters.normalizeCurrency("CHF") == "CHF") }

    @Test("normalizeCurrency chiffres → EUR")
    func normDigits() { #expect(Formatters.normalizeCurrency("123") == "EUR") }

    // MARK: - EUR backward compat (no currency arg)

    @Test("amount(120) conserve comportement EUR — contient 120 et €")
    func amountEurNoArg() {
        let s = Formatters.amount(120.0)
        #expect(s.contains("120"))
        #expect(s.contains("€"))
    }

    @Test("amount(42380) — milliers groupés, symbole €")
    func amountEurThousands() {
        let s = Formatters.amount(42380.0)
        #expect(s.contains("€"))
        // Valeur entière attendue, pas de décimale
        #expect(!s.contains(","))
    }

    @Test("amountDecimal(145.8) conserve comportement EUR — 2 décimales, €")
    func amountDecimalEurNoArg() {
        let s = Formatters.amountDecimal(145.8)
        #expect(s.contains("€"))
        #expect(s.contains("145"))
        // fr_FR : séparateur décimal = virgule
        #expect(s.contains(","))
    }

    // MARK: - EUR explicite

    @Test("amount(120, currency: EUR) identique à amount(120)")
    func amountEurExplicitMatchesDefault() {
        #expect(Formatters.amount(120.0, currency: "EUR") == Formatters.amount(120.0))
    }

    @Test("amountDecimal(145.8, currency: EUR) identique à amountDecimal(145.8)")
    func amountDecimalEurExplicitMatchesDefault() {
        #expect(Formatters.amountDecimal(145.8, currency: "EUR") == Formatters.amountDecimal(145.8))
    }

    // MARK: - ILS

    @Test("amount(450, currency: ILS) — contient 450, pas €")
    func amountILS() {
        let s = Formatters.amount(450.0, currency: "ILS")
        #expect(s.contains("450"))
        #expect(!s.contains("€"))
    }

    @Test("amount(450, currency: ILS) — contient marqueur ILS (₪ ou ILS)")
    func amountILSHasMarker() {
        let s = Formatters.amount(450.0, currency: "ILS")
        let hasMarker = s.contains("₪") || s.contains("ILS") || s.contains("ils")
        #expect(hasMarker, "Résultat ILS doit contenir ₪ ou ILS — obtenu: \(s)")
    }

    @Test("amount(450, currency: ils) == amount(450, currency: ILS)")
    func amountILSLowercaseEqualsUppercase() {
        #expect(Formatters.amount(450.0, currency: "ils") == Formatters.amount(450.0, currency: "ILS"))
    }

    // MARK: - USD

    @Test("amount(180, currency: USD) — contient 180, pas €")
    func amountUSD() {
        let s = Formatters.amount(180.0, currency: "USD")
        #expect(s.contains("180"))
        #expect(!s.contains("€"))
    }

    @Test("amount(180, currency: USD) — contient marqueur USD ($ ou USD)")
    func amountUSDHasMarker() {
        let s = Formatters.amount(180.0, currency: "USD")
        let hasMarker = s.contains("$") || s.contains("USD") || s.contains("usd")
        #expect(hasMarker, "Résultat USD doit contenir $ ou USD — obtenu: \(s)")
    }

    // MARK: - CHF

    @Test("amount(150, currency: CHF) — contient 150, pas €")
    func amountCHF() {
        let s = Formatters.amount(150.0, currency: "CHF")
        #expect(s.contains("150"))
        #expect(!s.contains("€"))
    }

    @Test("amount(150, currency: CHF) — contient CHF ou Fr")
    func amountCHFHasMarker() {
        let s = Formatters.amount(150.0, currency: "CHF")
        let hasMarker = s.contains("CHF") || s.contains("Fr")
        #expect(hasMarker, "Résultat CHF doit contenir CHF ou Fr — obtenu: \(s)")
    }

    // MARK: - Fallback pour devise invalide

    @Test("amount(120, currency: EURO) → fallback EUR")
    func amountInvalidEUROFallback() {
        let s = Formatters.amount(120.0, currency: "EURO")
        #expect(s.contains("€"))
        #expect(s.contains("120"))
    }

    @Test("amount(120, currency: '') → fallback EUR")
    func amountEmptyCurrencyFallback() {
        let s = Formatters.amount(120.0, currency: "")
        #expect(s.contains("€"))
    }

    // MARK: - amountCompact

    @Test("amountCompact(120) → même résultat que amount(120)")
    func amountCompactEurMatchesAmount() {
        #expect(Formatters.amountCompact(120.0) == Formatters.amount(120.0))
    }

    @Test("amountCompact(450, currency: ILS) → même résultat que amount(450, ILS)")
    func amountCompactILSMatchesAmount() {
        #expect(Formatters.amountCompact(450.0, currency: "ILS") == Formatters.amount(450.0, currency: "ILS"))
    }

    // MARK: - No-FX: valeur numérique inchangée

    @Test("amount — valeur numérique non modifiée pour ILS")
    func noFXNumericalValueILS() {
        let s = Formatters.amount(450.0, currency: "ILS")
        #expect(s.contains("450"), "La valeur 450 doit apparaître telle quelle — obtenu: \(s)")
    }

    @Test("amount — valeur numérique non modifiée pour USD")
    func noFXNumericalValueUSD() {
        let s = Formatters.amount(180.0, currency: "USD")
        #expect(s.contains("180"), "La valeur 180 doit apparaître telle quelle — obtenu: \(s)")
    }

    // MARK: - currencySymbol

    @Test("currencySymbol(EUR) → €")
    func symbolEUR() {
        #expect(Formatters.currencySymbol(for: "EUR") == "€")
    }

    @Test("currencySymbol(ILS) — contient ₪")
    func symbolILS() {
        let s = Formatters.currencySymbol(for: "ILS")
        #expect(s.contains("₪") || s.contains("ILS"), "Symbole ILS attendu — obtenu: \(s)")
    }

    @Test("currencySymbol(ils) normalisé comme ILS")
    func symbolILSLowercase() {
        #expect(Formatters.currencySymbol(for: "ils") == Formatters.currencySymbol(for: "ILS"))
    }
}
