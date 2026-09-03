import SwiftUI

// MARK: - Polices

extension Font {
    /// 30 / bold — « Aujourd'hui », « Messages »
    static let bhGrandTitre = Font.system(size: 30, weight: .bold)
    /// 12.5 / semibold — ligne au-dessus du grand titre
    static let bhSurTitre   = Font.system(size: 12.5, weight: .semibold)
    /// 34 / semibold — montants héro
    static let bhValeurHero = Font.system(size: 34, weight: .semibold)
    /// 17 / semibold — titre de ligne (milieu de 16–18)
    static let bhTitreLigne = Font.system(size: 17, weight: .semibold)
    /// 18 / semibold — titre de ligne (bord haut de 16–18, cartes urgentes)
    static let bhTitreLigneL = Font.system(size: 18, weight: .semibold)
    /// 15 — corps courant (milieu de 14.5–15)
    static let bhCorps      = Font.system(size: 15)
    /// 13 — métadonnée (milieu de 12.5–13.5)
    static let bhMeta       = Font.system(size: 13)
    /// 11.5 / bold — intertitre capitales, gris atténué
    static let bhIntertitre = Font.system(size: 11.5, weight: .bold)
    /// 10.5 / medium — étiquette d'onglet
    static let bhOnglet     = Font.system(size: 10.5, weight: .medium)
}

// MARK: - Modificateurs Text

extension Text {
    /// Grand titre : 30 / bold, tracking −0.032em × 30pt ≈ −0.96pt
    func bhGrandTitre(color: Color = .bhEncre) -> some View {
        self.font(.bhGrandTitre)
            .tracking(-0.96)
            .foregroundStyle(color)
    }

    /// Valeur héro : 34 / semibold, tracking −0.035em × 34pt ≈ −1.19pt
    func bhValeurHero(color: Color = .bhEncre) -> some View {
        self.font(.bhValeurHero)
            .tracking(-1.19)
            .foregroundStyle(color)
    }

    /// Intertitre capitales : 11.5 / bold, tracking +0.13em × 11.5pt ≈ +1.50pt
    func bhIntertitre(color: Color = .bhAttenue) -> some View {
        self.font(.bhIntertitre)
            .tracking(1.495)
            .foregroundStyle(color)
    }
}
