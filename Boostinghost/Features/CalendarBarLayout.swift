import CoreGraphics

// Shared layout tokens for TimelineView (Mensuel) and SemaineView (Semaine).
// One source of truth — change here, both views update.
enum CalBarLayout {
    /// Height of each property row
    static let rowH:      CGFloat = 64
    /// Height of reservation / block bars
    static let barH:      CGFloat = 44
    /// Corner radius of bars
    static let barR:      CGFloat = 11
    /// Price label font size
    static let priceSize: CGFloat = 11

    // -- TimelineView (ZStack layout, price behind bar) --
    /// Vertical offset of bar from top of row: centers bar in rowH
    static let tlBarTop: CGFloat = (rowH - barH) / 2   // = 10

    // -- SemaineView (ZStack layout, price behind bar) --
    /// Y offset of the guest-name overlay — aligns with top of centered bar
    static let swOverlayY: CGFloat = (rowH - barH) / 2  // = 10
}
