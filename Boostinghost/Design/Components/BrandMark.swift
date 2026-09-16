import SwiftUI

// MARK: - Geometry shared between BrandMark and SplashView

// All coordinates are in the original 1024×1024 SVG viewBox.
// glyphTransform() centers the glyph bounding box at runtime so the
// layout stays correct if the paths ever change.

enum BrandMarkGeometry {

    // MARK: Paths

    static func bPath() -> Path {
        Path { p in
            // Outer B shape
            p.move(to:    CGPoint(x: 210, y: 205))
            p.addLine(to: CGPoint(x: 405, y: 205))
            p.addCurve(to: CGPoint(x: 610, y: 385),
                       control1: CGPoint(x: 535, y: 205),
                       control2: CGPoint(x: 610, y: 270))
            p.addCurve(to: CGPoint(x: 486, y: 558),
                       control1: CGPoint(x: 610, y: 475),
                       control2: CGPoint(x: 565, y: 535))
            p.addCurve(to: CGPoint(x: 625, y: 745),
                       control1: CGPoint(x: 575, y: 578),
                       control2: CGPoint(x: 625, y: 646))
            p.addCurve(to: CGPoint(x: 405, y: 940),
                       control1: CGPoint(x: 625, y: 875),
                       control2: CGPoint(x: 540, y: 940))
            p.addLine(to: CGPoint(x: 210, y: 940))
            p.closeSubpath()
            // Top counter-form (evenodd punches through)
            p.move(to:    CGPoint(x: 300, y: 275))
            p.addLine(to: CGPoint(x: 300, y: 525))
            p.addLine(to: CGPoint(x: 395, y: 525))
            p.addCurve(to: CGPoint(x: 520, y: 400),
                       control1: CGPoint(x: 475, y: 525),
                       control2: CGPoint(x: 520, y: 480))
            p.addCurve(to: CGPoint(x: 395, y: 275),
                       control1: CGPoint(x: 520, y: 320),
                       control2: CGPoint(x: 475, y: 275))
            p.closeSubpath()
            // Bottom counter-form
            p.move(to:    CGPoint(x: 300, y: 595))
            p.addLine(to: CGPoint(x: 300, y: 870))
            p.addLine(to: CGPoint(x: 400, y: 870))
            p.addCurve(to: CGPoint(x: 535, y: 735),
                       control1: CGPoint(x: 485, y: 870),
                       control2: CGPoint(x: 535, y: 820))
            p.addCurve(to: CGPoint(x: 400, y: 595),
                       control1: CGPoint(x: 535, y: 645),
                       control2: CGPoint(x: 485, y: 595))
            p.closeSubpath()
        }
    }

    static func hPath() -> Path {
        Path { p in
            // Right stem
            p.move(to:    CGPoint(x: 745, y: 205))
            p.addLine(to: CGPoint(x: 835, y: 205))
            p.addLine(to: CGPoint(x: 835, y: 940))
            p.addLine(to: CGPoint(x: 745, y: 940))
            p.closeSubpath()
            // Crossbar
            p.move(to:    CGPoint(x: 486, y: 548))
            p.addLine(to: CGPoint(x: 790, y: 548))
            p.addLine(to: CGPoint(x: 790, y: 606))
            p.addLine(to: CGPoint(x: 486, y: 606))
            p.closeSubpath()
        }
    }

    // MARK: Transform

    // Cached once — paths are constant, so bounds never change.
    static let glyphBounds: CGRect = bPath().boundingRect.union(hPath().boundingRect)

    // Scales so glyph width = coverFraction * canvasSize.width,
    // then centers the glyph bounding box in the canvas.
    // Works identically in tile mode (with background) and glyph-only mode.
    static func glyphTransform(canvasSize: CGSize, coverFraction: CGFloat) -> CGAffineTransform {
        let bounds = glyphBounds
        let s  = (canvasSize.width * coverFraction) / bounds.width
        let tx = canvasSize.width  / 2 - s * bounds.midX
        let ty = canvasSize.height / 2 - s * bounds.midY
        return CGAffineTransform(scaleX: s, y: s)
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }
}

// MARK: - BH monogram view

struct BrandMark: View {
    var showBackground: Bool = true
    var glyphColor: Color = Color(hex: "#FAF8F2")
    var size: CGFloat = 120
    /// Fraction of tile width the glyph occupies. iOS icon standard ≈ 0.62.
    var coverFraction: CGFloat = 0.62

    var body: some View {
        Canvas { ctx, canvasSize in
            if showBackground {
                let cornerR = 160 * canvasSize.width / 1024
                let bg = Path(roundedRect: CGRect(origin: .zero, size: canvasSize),
                              cornerRadius: cornerR)
                ctx.fill(bg, with: .color(Color(hex: "#01382F")))
            }

            let t = BrandMarkGeometry.glyphTransform(canvasSize: canvasSize,
                                                     coverFraction: coverFraction)
            ctx.fill(BrandMarkGeometry.bPath().applying(t), with: .color(glyphColor),
                     style: FillStyle(eoFill: true))
            ctx.fill(BrandMarkGeometry.hPath().applying(t), with: .color(glyphColor))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 24) {
        BrandMark(showBackground: true,  size: 120)
        BrandMark(showBackground: false, glyphColor: Color(hex: "#01382F"), size: 120)
        BrandMark(showBackground: true,  size: 48)
    }
    .padding(40)
    .background(Color(hex: "#F5F3EE"))
}
