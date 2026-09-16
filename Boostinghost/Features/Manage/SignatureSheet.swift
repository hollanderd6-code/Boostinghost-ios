import SwiftUI

// MARK: - Feuille de signature partagée (mandat + attestation)
// ⚠️ La zone de tracé est la seule surface #FFF opaque de toute l'app.
// ⚠️ Le serveur exige un signatureData commençant par "data:image/png;base64,".
//    Un préfixe absent laisse la signature vide sans message d'erreur.

struct SignatureSheet: View {
    let signerName: String
    let ownerEmail: String
    let footerText: String
    let isSending:  Bool
    let onSign:     (String) -> Void
    let onSendTap:  () -> Void
    let onCancel:   () -> Void

    @State private var lines:       [[CGPoint]] = []
    @State private var currentLine: [CGPoint]   = []
    @State private var signatureTime = Date()
    @State private var canvasWidth: CGFloat = 0

    private var hasSignature: Bool { !lines.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Poignée
            SheetHandle()

            // En-tête
            HStack(alignment: .firstTextBaseline) {
                Text("Votre signature")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(Color.bhEncre)
                Spacer()
                Button("Annuler") { onCancel() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.bhVert)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Instruction
            Text("Signez dans le cadre avec le doigt. Vous pourrez recommencer autant que nécessaire.")
                .font(.system(size: 14.5))
                .foregroundStyle(Color.bhAttenue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // Zone de tracé — fond #FFF opaque, seule exception au verre de toute l'app
            signatureCanvas
                .padding(.horizontal, 20)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { canvasWidth = $0 }

            // Effacer + horodatage
            HStack {
                Button {
                    lines = []; currentLine = []; signatureTime = Date()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward").imageScale(.small)
                        Text("Effacer").font(.system(size: 14.5, weight: .medium))
                    }
                    .foregroundStyle(hasSignature ? Color.bhVert : Color.bhAttenue.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!hasSignature)

                Spacer()

                Text(timeLabel(signatureTime))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.bhAttenue)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Spacer(minLength: 16)

            // Texte contextuel (mandat ou attestation)
            Text(footerText)
                .font(.system(size: 13.5))
                .foregroundStyle(Color.bhAttenue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Bouton principal
            Button {
                let data = exportPNG()
                guard !data.isEmpty else { return }
                onSign(data)
                onSendTap()
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("Signer et envoyer")
                            .font(.system(size: 16.5, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    (hasSignature && !isSending) ? Color.bhVert : Color.bhVert.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasSignature || isSending)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background {
            Rectangle()
                .glassEffect(in: .rect)
                .specularEdge(cornerRadius: 0)
                .ignoresSafeArea()
        }
    }

    // MARK: - Canvas de tracé

    private var signatureCanvas: some View {
        let capturedLines = lines

        return ZStack(alignment: .bottomLeading) {
            // Fond blanc opaque (seule exception au verre de toute l'app)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.10),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.05),
                    radius: 6, x: 0, y: 2
                )

            // Ligne de base à 62 pt du bas
            Rectangle()
                .fill(Color(red: 20/255, green: 32/255, blue: 27/255).opacity(0.13))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 62)

            // Nom du signataire sous la ligne
            if !signerName.isEmpty {
                Text(signerName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.bhAttenue)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 46)
            }

            // Canvas de dessin
            Canvas { ctx, _ in
                Self.strokeLines(capturedLines, ctx: ctx)
                if !currentLine.isEmpty {
                    Self.strokeLines([currentLine], ctx: ctx)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in currentLine.append(val.location) }
                    .onEnded { _ in
                        guard !currentLine.isEmpty else { return }
                        lines.append(currentLine)
                        currentLine = []
                        signatureTime = Date()
                    }
            )
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Rendu des traits (réutilisé dans l'export)

    static func strokeLines(_ lines: [[CGPoint]], ctx: GraphicsContext) {
        for pts in lines {
            guard !pts.isEmpty else { continue }
            if pts.count == 1 {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pts[0].x - 1.5, y: pts[0].y - 1.5, width: 3, height: 3)),
                    with: .color(Color.bhEncre)
                )
                continue
            }
            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i-1].x + pts[i].x) / 2,
                                  y: (pts[i-1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i-1])
            }
            path.addLine(to: pts[pts.count - 1])
            ctx.stroke(path, with: .color(Color.bhEncre),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Export PNG → data URL

    private func exportPNG() -> String {
        let w = canvasWidth > 0 ? canvasWidth : UIScreen.main.bounds.width - 40
        let size = CGSize(width: w, height: 230)
        let capturedLines = lines

        let renderer = ImageRenderer(
            content: Canvas { ctx, s in
                ctx.fill(Path(CGRect(origin: .zero, size: s)), with: .color(.white))
                Self.strokeLines(capturedLines, ctx: ctx)
            }
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = UIScreen.main.scale

        guard let uiImg = renderer.uiImage,
              let data = uiImg.pngData() else { return "" }

        // ⚠️ Le serveur vérifie ce préfixe — une signature sans lui est ignorée silencieusement.
        return "data:image/png;base64," + data.base64EncodedString()
    }

    // MARK: - Horodatage

    private func timeLabel(_ date: Date) -> String {
        let h = Calendar.current.component(.hour,   from: date)
        let m = Calendar.current.component(.minute, from: date)
        return m == 0
            ? "\(h)\u{00A0}h"
            : "\(h)\u{00A0}h\u{00A0}\(String(format: "%02d", m))"
    }
}
