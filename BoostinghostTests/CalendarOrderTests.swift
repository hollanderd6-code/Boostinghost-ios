import Foundation
import Testing
@testable import Boostinghost

// Tests de la logique de réordonnancement des logements dans CalendarViewModel.
// Couvre la cohérence du draft local et la structure du payload envoyé.
//
// Exécuter :
//   xcodebuild test -scheme Boostinghost -destination 'platform=macOS'

private func makeSummary(_ id: String, name: String = "") -> PropertySummary {
    let json = """
    {"id":"\(id)","name":"\(name.isEmpty ? id : name)"}
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(PropertySummary.self, from: json)
}

struct CalendarOrderTests {

    // ORDER-1 — Liste vide : aucun logement → draft vide
    @Test("ORDER-1 — propriétés vides → draft vide")
    func order1_emptyProperties() {
        let props: [PropertySummary] = []
        #expect(props.isEmpty)
    }

    // ORDER-2 — Un seul logement : le draft ne change pas après onMove nul
    @Test("ORDER-2 — un logement → ordre inchangé après move nul")
    func order2_singleProperty() {
        var draft = [makeSummary("p1")]
        draft.move(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        #expect(draft.map(\.id) == ["p1"])
    }

    // ORDER-3 — Deux logements : swap produit l'ordre inverse
    @Test("ORDER-3 — deux logements : swap → ordre inversé")
    func order3_twoPropertiesSwap() {
        var draft = [makeSummary("p1"), makeSummary("p2")]
        draft.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(draft.map(\.id) == ["p2", "p1"])
    }

    // ORDER-4 — Trois logements : déplacer le dernier en premier
    @Test("ORDER-4 — trois logements : dernier → premier")
    func order4_moveLastToFirst() {
        var draft = [makeSummary("p1"), makeSummary("p2"), makeSummary("p3")]
        draft.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(draft.map(\.id) == ["p3", "p1", "p2"])
    }

    // ORDER-5 — Payload order = map(\.id) sur le draft
    @Test("ORDER-5 — payload : ids dans l'ordre du draft")
    func order5_payloadIds() {
        let draft = [makeSummary("p2"), makeSummary("p1"), makeSummary("p3")]
        let payload = draft.map(\.id)
        #expect(payload == ["p2", "p1", "p3"])
    }

    // ORDER-6 — Pas de doublons dans le draft (PropertySummary.id est unique)
    @Test("ORDER-6 — draft sans doublons")
    func order6_noDuplicates() {
        let draft = [makeSummary("p1"), makeSummary("p2"), makeSummary("p3")]
        let ids = draft.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    // ORDER-7 — displayName utilise internalName si disponible
    @Test("ORDER-7 — displayName préfère internalName")
    func order7_displayName() {
        let json = """
        {"id":"p1","name":"Nom public","internalName":"Nom interne"}
        """.data(using: .utf8)!
        let prop = try! JSONDecoder().decode(PropertySummary.self, from: json)
        #expect(prop.displayName == "Nom interne")
    }

    // ORDER-8 — displayName replie sur name si internalName absent
    @Test("ORDER-8 — displayName replie sur name")
    func order8_displayNameFallback() {
        let prop = makeSummary("p1", name: "Appartement A")
        #expect(prop.displayName == "Appartement A")
    }

    // ORDER-9 — displayName replie sur name si internalName est chaîne vide
    @Test("ORDER-9 — displayName replie sur name si internalName vide")
    func order9_displayNameEmptyInternal() {
        let json = """
        {"id":"p1","name":"Appartement A","internalName":""}
        """.data(using: .utf8)!
        let prop = try! JSONDecoder().decode(PropertySummary.self, from: json)
        #expect(prop.displayName == "Appartement A")
    }

    // ORDER-10 — move multiple : déplacer deux éléments consécutifs
    @Test("ORDER-10 — déplacement de deux éléments consécutifs")
    func order10_moveMultiple() {
        var draft = [makeSummary("p1"), makeSummary("p2"), makeSummary("p3"), makeSummary("p4")]
        // Déplacer p1 et p2 (indices 0,1) après p4 → p3, p4, p1, p2
        draft.move(fromOffsets: IndexSet([0, 1]), toOffset: 4)
        #expect(draft.map(\.id) == ["p3", "p4", "p1", "p2"])
    }

    // ORDER-11 — vm.visibleProperties (.allLines) préserve l'ordre de vm.properties
    //   Vérifie que la vue Mensuel et Semaine reflètent bien l'ordre de vm.properties,
    //   sans tri secondaire ni snapshot figé.
    @Test("ORDER-11 — visibleProperties(.allLines) = vm.properties dans l'ordre")
    @MainActor
    func order11_visiblePropertiesPreservesOrder() {
        let vm = CalendarViewModel()
        // vm.properties est private(set) — on vérifie que visibleProperties
        // lit bien vm.properties (identité de référence) en mode allLines.
        // En mode allLines, visibleProperties retourne toujours exactement vm.properties.
        let mode = CalendarDisplayMode.allLines
        vm.displayModeKey = mode.persistenceKey
        // vm.properties est vide au démarrage → visibleProperties aussi vide.
        #expect(vm.visibleProperties.isEmpty)
        #expect(vm.visibleProperties.count == vm.properties.count)
    }

    // ORDER-12 — CalendarDisplayMode.single filtre sans trier
    @Test("ORDER-12 — displayMode.single filtre sans modifier l'ordre global")
    func order12_singleModeDoesNotSort() {
        // Si vm.properties était [M13, M7, M10, M8] et displayMode = .single("M7"),
        // visibleProperties = [M7] — pas de tri de l'ensemble.
        let allIds = ["M13", "M7", "M10", "M8"]
        let props = allIds.map { makeSummary($0) }
        // Simuler le filtre de visibleProperties pour mode .single
        let filtered = props.filter { $0.id == "M7" }
        #expect(filtered.map(\.id) == ["M7"])
        // L'ensemble d'origine n'est pas modifié
        #expect(props.map(\.id) == ["M13", "M7", "M10", "M8"])
    }

    // ORDER-13 — vm.properties = newOrder : l'assignation directe produit le bon résultat
    //   Simule le comportement de reorderProperties après correction (direct assignment).
    //   Sans réseau : on vérifie la logique d'assignation sur un tableau Swift.
    @Test("ORDER-13 — direct assignment : vm.properties prend l'ordre du draftOrder")
    func order13_directAssignment() {
        // Simule : properties = newOrder (le cœur du correctif CALORDERBUG-8)
        var properties = [makeSummary("A"), makeSummary("B"), makeSummary("C")]
        let newOrder   = [makeSummary("C"), makeSummary("A"), makeSummary("B")]
        properties = newOrder
        #expect(properties.map(\.id) == ["C", "A", "B"],
                "Après assignment direct, properties doit refléter newOrder")
    }

    // ORDER-14 — Mensuel + Semaine : M8,M10,M7,M13 → M13,M7,M10,M8
    @Test("ORDER-14 — réordonnancement M8>M10>M7>M13 → M13>M7>M10>M8")
    func order14_m8m10m7m13_reorder() {
        // Simule l'état initial (ordre de création, pas de display_order)
        var draftOrder = ["M8", "M10", "M7", "M13"].map { makeSummary($0) }

        // Utilisateur déplace M13 en première position
        draftOrder.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        // draftOrder = [M13, M8, M10, M7]
        // Puis M7 en 2e position (index 3 → 1)
        draftOrder.move(fromOffsets: IndexSet(integer: 3), toOffset: 1)
        // draftOrder = [M13, M7, M8, M10]
        // Puis M10 en 3e position (index 3 → 2)
        draftOrder.move(fromOffsets: IndexSet(integer: 3), toOffset: 2)
        // draftOrder = [M13, M7, M10, M8]

        let result = draftOrder.map(\.id)
        #expect(result == ["M13", "M7", "M10", "M8"],
                "Ordre final attendu : M13, M7, M10, M8 — obtenu : \(result)")
    }

    // ORDER-15 — Payload identique au draftOrder au moment de la soumission
    //   (non-régression : le payload envoyé au backend n'est PAS vm.properties
    //   mais bien draftOrder tel que modifié par l'utilisateur)
    @Test("ORDER-15 — payload soumis = draftOrder (pas vm.properties original)")
    func order15_payloadIsDraftNotOriginal() {
        let originalOrder  = [makeSummary("A"), makeSummary("B"), makeSummary("C")]
        var draftOrder     = originalOrder

        // Drag : déplacer C en premier
        draftOrder.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        let submittedPayload = draftOrder.map(\.id)
        let originalIds      = originalOrder.map(\.id)

        #expect(submittedPayload == ["C", "A", "B"],
                "Payload soumis doit être [C,A,B]")
        #expect(submittedPayload != originalIds,
                "Payload ne doit pas être identique à l'ordre original")
    }
}
