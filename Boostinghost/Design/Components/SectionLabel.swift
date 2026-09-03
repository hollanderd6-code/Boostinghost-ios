import SwiftUI

/// Intertitre de section — capitales, 11.5 / bold, gris atténué, tracking +1.50pt
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .bhIntertitre()
    }
}
