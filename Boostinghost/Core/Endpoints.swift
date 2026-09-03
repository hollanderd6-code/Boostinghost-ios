import Foundation

enum Endpoint {
    static let base = URL(string: "https://lcc-booking-manager.onrender.com")!

    // Auth
    static let login         = base.appending(path: "/api/auth/login")
    static let subLogin      = base.appending(path: "/api/sub-accounts/login")
    static let verify        = base.appending(path: "/api/auth/verify")
    static let refreshFaceID = base.appending(path: "/api/auth/refresh-faceid")

    // Today
    static let todayStates          = base.appending(path: "/api/aujourdhui/etats")
    static let cleaningAssignments  = base.appending(path: "/api/cleaning/assignments")

    // Conversations
    static let conversations = base.appending(path: "/api/chat/conversations")
    static func messages(_ id: Int) -> URL     { base.appending(path: "/api/chat/messages/\(id)") }
    static func markRead(_ id: Int) -> URL           { base.appending(path: "/api/chat/conversations/\(id)/mark-read") }
    static func toggleAI(_ id: Int) -> URL           { base.appending(path: "/api/chat/toggle-ai/\(id)") }
    static func sendPlatform(_ id: Int) -> URL       { base.appending(path: "/api/chat/conversations/\(id)/send-platform") }
    static let send                                  = base.appending(path: "/api/chat/send")
    static func suggestion(_ id: Int) -> URL         { base.appending(path: "/api/chat/conversations/\(id)/suggestion") }
    static func suggestionStatus(_ id: Int) -> URL   { base.appending(path: "/api/chat/conversations/\(id)/suggestion/status") }
    static func suggestionRegen(_ id: Int) -> URL    { base.appending(path: "/api/chat/conversations/\(id)/suggestion/regenerate") }

    // Properties
    static let properties      = base.appending(path: "/api/properties")
    static let propertyGroups  = base.appending(path: "/api/property-groups")
    static func property(_ id: String) -> URL  { base.appending(path: "/api/properties/\(id)") }
    static func sante(_ id: String) -> URL     { base.appending(path: "/api/properties/\(id)/sante") }

    // Reporting
    static let reporting = base.appending(path: "/api/reporting")

    // Profile
    static let userProfile        = base.appending(path: "/api/user/profile")
    static let subscriptionStatus = base.appending(path: "/api/subscription/status")

    // Cleaning management
    static let cleaners           = base.appending(path: "/api/cleaners")
    static let cleaningChecklists = base.appending(path: "/api/cleaning/checklists")
    static func checklist(_ id: Int) -> URL    { base.appending(path: "/api/cleaning/checklists/\(id)") }

    // Owners / contracts
    static let ownerClients  = base.appending(path: "/api/owner-clients")
    static let ownerInvoices = base.appending(path: "/api/owner-invoices")
    static let contrats      = base.appending(path: "/api/contrats")
    static let sendContrat   = base.appending(path: "/api/contrat/send")
    static let sendMandat    = base.appending(path: "/api/mandat/send")

    // Agency
    static let delegations  = base.appending(path: "/api/agency/delegations")
    static let agencySwitch = base.appending(path: "/api/agency/switch")

    // Calendar
    static let reservations     = base.appending(path: "/api/reservations")
    static let blocks           = base.appending(path: "/api/blocks")
    static func block(_ id: String) -> URL { base.appending(path: "/api/blocks/\(id)") }
    static let pricingOverrides = base.appending(path: "/api/pricing/overrides")
    static func pricingCalendar(_ propertyId: String) -> URL {
        base.appending(path: "/api/host/pricing/calendar/\(propertyId)")
    }

    // Stays / deposits
    static let reservationsWithDeposits = base.appending(path: "/api/reservations-with-deposits")
    static let reservationsWithPayments = base.appending(path: "/api/reservations-with-payments")
    static func captureDeposit(_ id: String) -> URL { base.appending(path: "/api/deposits/\(id)/capture") }
    static func releaseDeposit(_ id: String) -> URL { base.appending(path: "/api/deposits/\(id)/release") }
}
