import Foundation
import Observation

// MARK: - ContextualTipID

enum ContextualTipID: String, CaseIterable {
    case calendarBulkAction     = "calendarBulkAction"
    case aiTakeover             = "aiTakeover"
    case calendarPropertyPicker = "calendarPropertyPicker"
    case messagesUpsell         = "messagesUpsell"
    case assistantIAFacts       = "assistantIAFacts"
}

// MARK: - TipCoordinator

@Observable
@MainActor
final class TipCoordinator {

    static let shared = TipCoordinator()

    // MARK: - Public state

    /// Tip currently shown. nil = none. At most one tip at a time.
    private(set) var presentedTip: ContextualTipID? = nil

    /// Tips not yet seen by the current account.
    private(set) var unseenTips: Set<ContextualTipID> = []

    // MARK: - Session state

    /// Set when BulkAction tip is seen (by × or button tap) during the current
    /// Calendar visit. Reset by calendarTabDidHide(). Prevents PropertyPicker
    /// from appearing immediately after BulkAction on the same visit.
    private(set) var bulkActionSeenThisCalendarVisit: Bool = false
    private(set) var aiTakeoverSeenThisConversationVisit: Bool = false

    // MARK: - Private

    private var scopedUserId: String = ""

    private init() {}

    // MARK: - Load / reset

    func load(session: Session) {
        scopedUserId = OnboardingCoordinator.userIdFromJWT(session.token)
            ?? String(session.token.prefix(24))
        unseenTips = Set(ContextualTipID.allCases.filter { !isSeen($0) })
        presentedTip = nil
        bulkActionSeenThisCalendarVisit = false
        aiTakeoverSeenThisConversationVisit = false
    }

    func reset() {
        presentedTip = nil
        unseenTips   = []
        bulkActionSeenThisCalendarVisit = false
        aiTakeoverSeenThisConversationVisit = false
        scopedUserId = ""
    }

    // MARK: - Presentation

    private func canPresent() -> Bool {
        !OnboardingCoordinator.shared.isShowingOnboarding
            && presentedTip == nil
            && !scopedUserId.isEmpty
    }

    func tryPresent(_ tip: ContextualTipID) {
        guard canPresent(), unseenTips.contains(tip) else { return }
        presentedTip = tip
    }

    /// Called by the × button on ContextualTipView.
    func dismiss() {
        guard let tip = presentedTip else { return }
        markSeen(tip)
    }

    /// Clears presentedTip without marking it seen (view dismissed without user interaction).
    func releaseIfPresented(_ tip: ContextualTipID) {
        guard presentedTip == tip else { return }
        presentedTip = nil
    }

    // MARK: - markSeen

    /// Called by feature action handlers (BulkAction open, property selection, AI button tap).
    /// Also called internally by dismiss().
    func markSeen(_ tip: ContextualTipID) {
        guard unseenTips.contains(tip) else { return }
        unseenTips.remove(tip)
        saveSeenFlag(tip)
        if tip == .calendarBulkAction {
            bulkActionSeenThisCalendarVisit = true
        }
        if tip == .aiTakeover {
            aiTakeoverSeenThisConversationVisit = true
        }
        if presentedTip == tip {
            presentedTip = nil
        }
    }

    // MARK: - Calendar session tracking

    func calendarTabDidHide() {
        bulkActionSeenThisCalendarVisit = false
        if presentedTip == .calendarBulkAction || presentedTip == .calendarPropertyPicker {
            presentedTip = nil
        }
    }

    func conversationDidHide() {
        aiTakeoverSeenThisConversationVisit = false
        if presentedTip == .aiTakeover || presentedTip == .messagesUpsell {
            presentedTip = nil
        }
    }

    // MARK: - Replay (current account only)

    func resetForReplay() {
        guard !scopedUserId.isEmpty else { return }
        for tip in ContextualTipID.allCases {
            UserDefaults.standard.removeObject(forKey: seenKey(tip))
        }
        unseenTips = Set(ContextualTipID.allCases)
        bulkActionSeenThisCalendarVisit = false
        aiTakeoverSeenThisConversationVisit = false
        presentedTip = nil
    }

    // MARK: - Private — UserDefaults (account-scoped)

    private func seenKey(_ tip: ContextualTipID) -> String {
        "bh.tip.\(tip.rawValue).\(scopedUserId).seen"
    }

    private func isSeen(_ tip: ContextualTipID) -> Bool {
        guard !scopedUserId.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: seenKey(tip))
    }

    private func saveSeenFlag(_ tip: ContextualTipID) {
        guard !scopedUserId.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: seenKey(tip))
    }
}
