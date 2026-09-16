import SwiftUI

// MARK: - Avatar de profil
// Affiche le logo (AsyncImage) si logoUrl est fourni ; initiales en fallback.
// Initiales : 1ère lettre firstName + 1ère lettre lastName ; sinon company ; sinon "?".

struct ProfileAvatarView: View {
    let logoUrl:   String?
    let firstName: String?
    let lastName:  String?
    let company:   String?
    let size:      CGFloat

    private var initials: String {
        if let c = company, !c.isEmpty { return String(c.first!).uppercased() }
        var result = ""
        if let f = firstName?.first { result.append(f) }
        if let l = lastName?.first  { result.append(l) }
        return result.isEmpty ? "?" : result.uppercased()
    }

    private var textSize: CGFloat { (size * 0.38).rounded() }

    var body: some View {
        Group {
            if let urlStr = logoUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                            .background(Color(hex: "#DCE8E1"), in: Circle())
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        initialsCircle
                    @unknown default:
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#DCE8E1"))
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(Color.bhVert)
        }
    }

    private var accessibilityLabel: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return company ?? "Profil"
    }
}
