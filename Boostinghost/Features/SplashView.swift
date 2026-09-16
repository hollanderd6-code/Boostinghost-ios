import SwiftUI

// MARK: - Splash animé
// Le masque du H est une Shape Animatable : SwiftUI interpole ses points
// frame par frame lors de withAnimation, contrairement à un Canvas @State.
// B affiché statique dès la première frame ; H révélé par le masque crayon.

struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // ── Timing (réglable) ────────────────────────────────────────────
    private let tPoseB:    Double = 0.20   // pose sur le B seul avant la barre
    private let tCrossbar: Double = 0.28   // durée du tracé de la barre
    private let tStem:     Double = 0.32   // durée du tracé de la hampe
    private let tOverlap:  Double = 0.06   // chevauchement barre→hampe
    private let tPoseFull: Double = 0.20   // pose finale avant la sortie
    // Total : tPoseB + tCrossbar + tStem - tOverlap + tPoseFull ≈ 0,94 s
    // ────────────────────────────────────────────────────────────────

    private let bg         = Color(hex: "#01382F")
    private let glyphColor = Color(hex: "#FAF8F2")
    private let markSize: CGFloat = 180
    private let cf: CGFloat       = 0.62

    @State private var crossbarP:     CGFloat = 0
    @State private var stemP:         CGFloat = 0
    @State private var logoOpacity:   Double  = 0      // Reduce Motion uniquement
    @State private var screenOpacity: Double  = 1
    @State private var runID: Int = 0

    private var animTotal: Double { tPoseB + tCrossbar - tOverlap + tStem + tPoseFull }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            if reduceMotion {
                BrandMark(showBackground: false,
                          glyphColor: glyphColor,
                          size: markSize,
                          coverFraction: cf)
                    .opacity(logoOpacity)
            } else {
                ZStack {
                    // B : toujours visible, non masqué
                    bCanvas

                    // H : révélé par la Shape Animatable
                    hCanvas
                        .mask {
                            HRevealMask(crossbarP: crossbarP, stemP: stemP, cf: cf)
                                .fill(.white)
                                .frame(width: markSize, height: markSize)
                        }
                }
            }
        }
        .opacity(screenOpacity)
        .onAppear(perform: run)
        #if DEBUG
        .onTapGesture(count: 3, perform: replay)
        #endif
    }

    // MARK: - Canvas statiques

    private var bCanvas: some View {
        Canvas { ctx, cs in
            let xf = BrandMarkGeometry.glyphTransform(canvasSize: cs, coverFraction: cf)
            ctx.fill(BrandMarkGeometry.bPath().applying(xf),
                     with: .color(glyphColor), style: FillStyle(eoFill: true))
        }
        .frame(width: markSize, height: markSize)
    }

    private var hCanvas: some View {
        Canvas { ctx, cs in
            let xf = BrandMarkGeometry.glyphTransform(canvasSize: cs, coverFraction: cf)
            ctx.fill(BrandMarkGeometry.hPath().applying(xf), with: .color(glyphColor))
        }
        .frame(width: markSize, height: markSize)
    }

    // MARK: - Séquence

    // Courbe "geste de main" : démarre lentement, accélère vers la fin.
    // timingCurve(0.4, 0, 1, 1) ≈ ease-in quadratique.
    private func strokeCurve(_ duration: Double) -> Animation {
        .timingCurve(0.4, 0, 1, 1, duration: duration)
    }

    private func run() {
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.35)) { logoOpacity = 1 }
            scheduleExit(after: 0.80)
            return
        }

        withAnimation(strokeCurve(tCrossbar).delay(tPoseB)) {
            crossbarP = 1
        }
        withAnimation(strokeCurve(tStem).delay(tPoseB + tCrossbar - tOverlap)) {
            stemP = 1
        }
        scheduleExit(after: animTotal)
    }

    private func scheduleExit(after delay: Double) {
        let id = runID
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard id == runID else { return }
            withAnimation(.easeOut(duration: 0.45)) { screenOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                guard id == runID else { return }
                onFinish()
            }
        }
    }

    // MARK: - Replay (debug)

    #if DEBUG
    private func replay() {
        runID += 1
        withAnimation(nil) {
            crossbarP     = 0
            stemP         = 0
            logoOpacity   = 0
            screenOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { run() }
    }
    #endif
}

// MARK: - Shape Animatable pour le masque du H

// path(in:) est appelé à chaque frame d'animation avec les valeurs interpolées
// de crossbarP et stemP — c'est ce qui garantit l'effet crayon frame par frame.

private struct HRevealMask: Shape {
    var crossbarP: CGFloat
    var stemP:     CGFloat
    let cf:        CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(crossbarP, stemP) }
        set { crossbarP = newValue.first; stemP = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let cs = CGSize(width: rect.width, height: rect.height)
        let xf = BrandMarkGeometry.glyphTransform(canvasSize: cs, coverFraction: cf)
        let s  = xf.a
        var combined = Path()

        // Barre : gauche→droite
        if crossbarP > 0 {
            let a = CGPoint(x: 486, y: 577).applying(xf)
            let b = CGPoint(x: 486 + (800 - 486) * crossbarP, y: 577).applying(xf)
            var line = Path(); line.move(to: a); line.addLine(to: b)
            combined.addPath(
                line.strokedPath(StrokeStyle(lineWidth: 90 * s, lineCap: .round))
            )
        }

        // Hampe : haut→bas
        if stemP > 0 {
            let a = CGPoint(x: 790, y: 190).applying(xf)
            let b = CGPoint(x: 790, y: 190 + (955 - 190) * stemP).applying(xf)
            var line = Path(); line.move(to: a); line.addLine(to: b)
            combined.addPath(
                line.strokedPath(StrokeStyle(lineWidth: 130 * s, lineCap: .round))
            )
        }

        return combined
    }
}

#Preview {
    SplashView(onFinish: {})
}
