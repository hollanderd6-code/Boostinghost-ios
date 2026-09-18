import Testing
@testable import Boostinghost

// Tests de la logique d'état dérivé des ménages.
// Couvre CleaningExecutionState.effectiveCleaningState sur CleaningAssignment.
//
// Exécuter :
//   xcodebuild test -scheme Boostinghost -destination 'platform=macOS'

struct CleaningStateTests {

    // Construit un CleaningAssignment avec les champs d'état pré-remplis.
    private func makeAssignment(
        checklistCompleted: Bool = false,
        checklistOwnerStatus: String? = nil,
        checklistHasDraft: Bool = false
    ) -> CleaningAssignment {
        var a = CleaningAssignment(
            propertyId: "test-prop",
            reservationKey: "test-prop_2026-09-14_2026-09-17",
            cleanerName: nil,
            cleanerPhone: nil,
            cleanerEmail: nil,
            windowStart: nil,
            windowEnd: nil,
            status: nil,
            groupName: nil,
            propertyName: nil,
            isDefault: false
        )
        a.checklistCompleted = checklistCompleted
        a.checklistOwnerStatus = checklistOwnerStatus
        a.checklistHasDraft = checklistHasDraft
        return a
    }

    // I1 — Aucune checklist → Pas commencé
    @Test("I1 — aucune checklist → notStarted")
    func i1_noChecklist() {
        let a = makeAssignment()
        #expect(a.effectiveCleaningState == .notStarted)
    }

    // I2 — Brouillon actif (completedAt IS NULL) → En cours
    @Test("I2 — brouillon actif → inProgress")
    func i2_draft() {
        let a = makeAssignment(checklistCompleted: false, checklistHasDraft: true)
        #expect(a.effectiveCleaningState == .inProgress)
    }

    // I3 — Checklist finalisée + pending → À valider
    @Test("I3 — completedAt + pending → pendingValidation")
    func i3_completedPending() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "pending")
        #expect(a.effectiveCleaningState == .pendingValidation)
    }

    // I4 — owner_status validated → Validé
    @Test("I4 — owner_status=validated → validated")
    func i4_validated() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "validated")
        #expect(a.effectiveCleaningState == .validated)
    }

    // I5 — owner_status rejected → Rejeté
    @Test("I5 — owner_status=rejected → rejected")
    func i5_rejected() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "rejected")
        #expect(a.effectiveCleaningState == .rejected)
    }

    // I6 — Absence réelle de checklist → notStarted (Pas de retour dans l'Historique)
    @Test("I6 — absence de checklist finalisée → notStarted")
    func i6_noReturn() {
        let a = makeAssignment(checklistCompleted: false, checklistOwnerStatus: nil, checklistHasDraft: false)
        #expect(a.effectiveCleaningState == .notStarted,
                "Sans checklist finalisée, l'état doit être notStarted — Historique affichera 'Pas de retour'")
    }

    // I7 — M8 : completedAt + pending ne peut jamais produire notStarted
    @Test("I7 — M8 : checklist finalisée + pending ≠ notStarted")
    func i7_m8NeverNotStarted() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "pending")
        #expect(a.effectiveCleaningState != .notStarted,
                "Un ménage avec checklist finalisée ne doit jamais afficher 'Pas commencé'")
        #expect(a.effectiveCleaningState == .pendingValidation)
    }

    // I8 — Cohérence de l'enum : tous les cas sont exhaustifs
    @Test("I8 — effectiveCleaningState couvre tous les cas métier")
    func i8_exhaustive() {
        let cases: [(Bool, String?, Bool, CleaningExecutionState)] = [
            (false, nil,         false, .notStarted),
            (false, nil,         true,  .inProgress),
            (true,  "pending",   false, .pendingValidation),
            (true,  "validated", false, .validated),
            (true,  "rejected",  false, .rejected),
            // owner_status inconnu sur checklist finalisée → repli pendingValidation
            (true,  "unknown",   false, .pendingValidation),
            // brouillon + checklistCompleted impossible (completedAt != nil implique pas brouillon)
            // mais si les deux sont true, checklistCompleted prend la priorité
            (true,  "pending",   true,  .pendingValidation),
        ]
        for (completed, ownerStatus, hasDraft, expected) in cases {
            let a = makeAssignment(
                checklistCompleted: completed,
                checklistOwnerStatus: ownerStatus,
                checklistHasDraft: hasDraft
            )
            #expect(a.effectiveCleaningState == expected,
                    "completed=\(completed) status=\(ownerStatus ?? "nil") draft=\(hasDraft) → attendu \(expected)")
        }
    }

    // P1–P5 — Non-régression "PRÊT" : seul .validated produit l'état positif.

    @Test("P1 — validated → .validated (badge PRÊT)")
    func p1_validatedIsReady() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "validated")
        #expect(a.effectiveCleaningState == .validated)
    }

    @Test("P2 — notStarted ≠ .validated")
    func p2_notStartedNotReady() {
        let a = makeAssignment()
        #expect(a.effectiveCleaningState != .validated)
    }

    @Test("P3 — inProgress ≠ .validated")
    func p3_inProgressNotReady() {
        let a = makeAssignment(checklistCompleted: false, checklistHasDraft: true)
        #expect(a.effectiveCleaningState != .validated)
    }

    @Test("P4 — pendingValidation ≠ .validated")
    func p4_pendingNotReady() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "pending")
        #expect(a.effectiveCleaningState != .validated)
    }

    @Test("P5 — rejected ≠ .validated")
    func p5_rejectedNotReady() {
        let a = makeAssignment(checklistCompleted: true, checklistOwnerStatus: "rejected")
        #expect(a.effectiveCleaningState != .validated)
    }
}
