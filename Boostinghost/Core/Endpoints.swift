import Foundation

enum Endpoint {
    static let base = URL(string: "https://lcc-booking-manager.onrender.com")!

    // Auth
    static let login           = base.appending(path: "/api/auth/login")
    static let subLogin        = base.appending(path: "/api/sub-accounts/login")
    static let verify          = base.appending(path: "/api/auth/verify")
    static let refreshFaceID   = base.appending(path: "/api/auth/refresh-faceid")
    static let socialLogin     = base.appending(path: "/api/auth/social")
    static let socialConfig    = base.appending(path: "/api/auth/social/config")

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
    static func quickContext(_ id: Int) -> URL        { base.appending(path: "/api/chat/conversations/\(id)/quick-context") }
    static let shortLink                              = base.appending(path: "/api/short-link")

    // Properties
    static let properties          = base.appending(path: "/api/properties")
    static let propertyGroups      = base.appending(path: "/api/property-groups")
    static let propertiesOrderBulk = base.appending(path: "/api/properties-order/bulk")
    static func property(_ id: String) -> URL       { base.appending(path: "/api/properties/\(id)") }
    static func sante(_ id: String) -> URL          { base.appending(path: "/api/properties/\(id)/sante") }
    static func propertyFacts(_ id: String) -> URL  { base.appending(path: "/api/properties/\(id)/facts") }
    static func propertyFact(_ propId: String, factId: Int) -> URL { base.appending(path: "/api/properties/\(propId)/facts/\(factId)") }
    static func propertyMarkups(_ id: String) -> URL { base.appending(path: "/api/properties/\(id)/markups") }
    static func propertyUpsell(_ id: String) -> URL { base.appending(path: "/api/properties/\(id)/upsell") }

    // Reporting — passer year/month/propertyId via extraQueryItems de APIClient
    static let reporting = base.appending(path: "/api/reporting")
    static func reportingItems(year: Int, month: Int, propertyId: String? = nil) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "year",  value: String(year)),
                     URLQueryItem(name: "month", value: String(month))]
        if let pid = propertyId { items.append(.init(name: "property_id", value: pid)) }
        return items
    }

    // Diffusion
    static let propertiesDiffusion  = base.appending(path: "/api/properties/diffusion")

    // Sync
    static let syncIcal      = base.appending(path: "/api/sync/ical")
    static let syncDiffusion = base.appending(path: "/api/diffusion/sync-all")

    // Profile & account
    static let userProfile          = base.appending(path: "/api/user/profile")
    static let subscriptionStatus   = base.appending(path: "/api/subscription/status")
    static func subAccount(_ id: Int) -> URL { base.appending(path: "/api/sub-accounts/\(id)") }
    static let subAccountsList      = base.appending(path: "/api/sub-accounts/list")
    static let notificationSettings = base.appending(path: "/api/settings/notifications")
    static let messageTemplates                               = base.appending(path: "/api/message-templates")
    static func messageTemplate(_ id: Int) -> URL             { base.appending(path: "/api/message-templates/\(id)") }
    static func messageTemplateSend(_ id: Int) -> URL         { base.appending(path: "/api/message-templates/\(id)/send") }

    // Cleaning management
    static let cleaners            = base.appending(path: "/api/cleaners")
    static func cleaner(_ id: String) -> URL               { base.appending(path: "/api/cleaners/\(id)") }
    static func cleanerRegenerateLink(_ id: String) -> URL { base.appending(path: "/api/cleaners/\(id)/regenerate-link") }
    static func cleanerSmsToggle(_ id: String) -> URL      { base.appending(path: "/api/cleaners/\(id)/sms-toggle") }
    static let defaultCleaners     = base.appending(path: "/api/cleaning/default-cleaners")
    static func defaultCleaner(_ propertyId: String) -> URL { base.appending(path: "/api/cleaning/default-cleaner/\(propertyId)") }
    static let cleaningChecklists     = base.appending(path: "/api/cleaning/checklists")
    static let cleaningPropertyNames  = base.appending(path: "/api/cleaning/property-names")
    static let cleaningTemplates   = base.appending(path: "/api/cleaning/templates")
    static func checklist(_ id: String) -> URL           { base.appending(path: "/api/cleaning/checklists/\(id)") }
    static func checklistValidate(_ id: String) -> URL   { base.appending(path: "/api/cleaning/checklists/\(id)/validate") }
    static func checklistReject(_ id: String) -> URL     { base.appending(path: "/api/cleaning/checklists/\(id)/reject") }
    static func checklistPdf(_ id: String) -> URL        { base.appending(path: "/api/cleaning/checklists/\(id)/pdf") }
    static func checklistDraft(_ reservationKey: String) -> URL {
        base.appending(path: "/api/cleaning/checklists/\(reservationKey)/draft")
    }
    static let checklistSubmit    = base.appending(path: "/api/cleaning/checklist")
    static let cleaningMeAccess   = base.appending(path: "/api/cleaning/me/access")
    static let cleaningConsumables = base.appending(path: "/api/cleaning/consumables")
    static let cleaningMaintenance = base.appending(path: "/api/cleaning/maintenance")
    static let cleaningPhotoUpload = base.appending(path: "/api/cleaning/photo-upload")
    static let maintenanceTickets  = base.appending(path: "/api/maintenance/tickets")

    // Owners / contracts / debours
    static let debours       = base.appending(path: "/api/debours")
    static func debour(_ id: String) -> URL       { base.appending(path: "/api/debours/\(id)") }
    static func debourStatus(_ id: String) -> URL { base.appending(path: "/api/debours/\(id)/status") }
    static let ownerClients  = base.appending(path: "/api/owner-clients")
    static func ownerClient(_ id: String) -> URL { base.appending(path: "/api/owner-clients/\(id)") }
    static let ownerInvoices = base.appending(path: "/api/owner-invoices")
    static func ownerInvoice(_ id: String) -> URL { base.appending(path: "/api/owner-invoices/\(id)") }
    static func ownerInvoicePdf(_ id: String) -> URL { base.appending(path: "/api/owner-invoices/\(id)/pdf") }
    static func ownerInvoiceFinalize(_ id: String) -> URL { base.appending(path: "/api/owner-invoices/\(id)/finalize") }
    static func ownerInvoiceSend(_ id: String) -> URL { base.appending(path: "/api/owner-invoices/\(id)/send") }
    static func ownerInvoiceMarkPaid(_ id: String) -> URL { base.appending(path: "/api/owner-invoices/\(id)/mark-paid") }
    static let contrats      = base.appending(path: "/api/contrats")
    static func contrat(_ id: String) -> URL        { base.appending(path: "/api/contrats/\(id)") }
    static func contratResend(_ id: String) -> URL  { base.appending(path: "/api/contrats/\(id)/resend-sign") }
    static func contratPdf(_ id: String) -> URL     { base.appending(path: "/api/contrats/\(id)/pdf") }
    static let sendContrat   = base.appending(path: "/api/contrat/send")
    static let sendMandat    = base.appending(path: "/api/mandat/send")
    static let mandatLast    = base.appending(path: "/api/mandat/last")

    // Attestation fiscale
    static let attestationGenerate = base.appending(path: "/api/attestation/generate")
    static let attestationSend     = base.appending(path: "/api/attestation/send")

    // Agency
    static let delegations    = base.appending(path: "/api/agency/delegations")
    static let agencySwitch   = base.appending(path: "/api/agency/switch")
    static let targetAccounts = base.appending(path: "/api/agency/target-accounts")
    static func agencyClientOverride(delegatorUserId: Int, clientId: String) -> URL {
        base.appending(path: "/api/agency/client-override/\(delegatorUserId)/\(clientId)")
    }

    // Sub-accounts
    static let subAccountsCreate = base.appending(path: "/api/sub-accounts/create")

    // Channex (diffusion)
    static let channexConnect    = base.appending(path: "/api/channex/connect-property")
    static let channexDisconnect = base.appending(path: "/api/channex/disconnect-property")
    static let channexIframeToken          = base.appending(path: "/api/channex/iframe-token")
    static func channexConnectedChannels(_ id: String) -> URL { base.appending(path: "/api/channex/connected-channels/\(id)") }
    static func channexPullBookings(_ id: String) -> URL      { base.appending(path: "/api/channex/pull-bookings/\(id)") }
    static func channexSyncBookings(_ id: String) -> URL      { base.appending(path: "/api/channex/sync-bookings/\(id)") }
    static func channexPushAvailability(_ id: String) -> URL  { base.appending(path: "/api/channex/push-availability/\(id)") }

    // Host questions (arbitrage hôte)
    static let hostQuestionsPending                         = base.appending(path: "/api/host-questions/pending")
    static func hostQuestionAnswer(_ id: Int) -> URL        { base.appending(path: "/api/host-questions/\(id)/answer") }
    static func hostQuestionsForConversation(_ id: Int) -> URL { base.appending(path: "/api/host-questions/conversation/\(id)") }
    static func deescalate(_ id: Int) -> URL                { base.appending(path: "/api/chat/deescalate/\(id)") }

    // Push notifications
    static let saveToken = base.appending(path: "/api/save-token")
    // Historique in-app des notifications reçues (alimenté par PushNotificationManager).
    static let notificationHistoryPush = base.appending(path: "/api/notifications/history/push")

    // BHGuest hold
    static let guestHold = base.appending(path: "/api/guest/hold")

    // Calendar — modify & delete reservations
    static func reservationManual(_ uid: String) -> URL { base.appending(path: "/api/reservations/manual/\(uid)") }
    static func reservationNote(_ uid: String) -> URL   { base.appending(path: "/api/reservations/\(uid)/note") }
    static let guestModifyReservation  = base.appending(path: "/api/guest/modify-reservation")
    static let guestCancelReservation  = base.appending(path: "/api/guest/cancel-reservation")
    static let manualReservationDelete = base.appending(path: "/api/manual-reservations/delete")

    // Calendar
    static let reservations        = base.appending(path: "/api/reservations")
    static let manualReservations  = base.appending(path: "/api/reservations/manual")
    static let bookings            = base.appending(path: "/api/bookings")
    static let blocks           = base.appending(path: "/api/blocks")
    static func block(_ id: String) -> URL { base.appending(path: "/api/blocks/\(id)") }
    static let pricingOverrides = base.appending(path: "/api/pricing/overrides")
    static let pricingRules     = base.appending(path: "/api/pricing/rules")
    static func pricingCalendar(_ propertyId: String) -> URL {
        base.appending(path: "/api/host/pricing/calendar/\(propertyId)")
    }
    // Multi-property calendar: ?from=YYYY-MM-DD&to=YYYY-MM-DD&agency=all
    static let pricingCalendarAll = base.appending(path: "/api/pricing/calendar")

    // Stays / deposits
    static let reservationsWithDeposits = base.appending(path: "/api/reservations-with-deposits")
    static let reservationsWithPayments = base.appending(path: "/api/reservations-with-payments")
    static func captureDeposit(_ id: String) -> URL { base.appending(path: "/api/deposits/\(id)/capture") }
    static func releaseDeposit(_ id: String) -> URL { base.appending(path: "/api/deposits/\(id)/release") }

    // Stays / invoices
    static let invoiceHistory             = base.appending(path: "/api/invoice/history")
    static let resendInvoice              = base.appending(path: "/api/invoice/resend")
    static let createInvoice              = base.appending(path: "/api/invoice/create")
    static let sendInvoiceToConversation  = base.appending(path: "/api/invoice/send-to-conversation")
    static func invoiceDownloadByNumber(_ number: String) -> URL {
        base.appending(path: "/api/invoice/download-by-number/\(number)")
    }

    // Hosterzz
    static let hosterzzStatus   = base.appending(path: "/api/hosterzz/status")
    static let hosterzzMission  = base.appending(path: "/api/hosterzz/mission")
    static let hosterzzMissions = base.appending(path: "/api/hosterzz/missions")
    static let hosterzzLink     = base.appending(path: "/api/hosterzz/link")

    // Upsell (prestations payantes)
    static let upsellManual = base.appending(path: "/api/upsell/manual")

    // Search
    static let search = base.appending(path: "/api/search")

    // User preferences (setup card persistence)
    static let userPreferences = base.appending(path: "/api/user/preferences")

    // Stripe status (personal account connection)
    static let stripeStatus            = base.appending(path: "/api/stripe/status")
    static let stripeCreateOnboarding  = base.appending(path: "/api/stripe/create-onboarding-link")

    // Help content
    static let helpContent = base.appending(path: "/api/help/content")

    // Welcome books (livret d'accueil unifié)
    static let welcomeBookCreate = base.appending(path: "/api/welcome-books/create")
    static func welcomeBookByProperty(_ propertyId: String) -> URL {
        base.appending(path: "/api/welcome-books/by-property/\(propertyId)")
    }
    static func welcomeBookExtras(_ uniqueId: String) -> URL {
        base.appending(path: "/api/welcome-books/by-unique/\(uniqueId)/extras")
    }

    // Support — « Nous écrire »
    static let supportConversation = base.appending(path: "/api/support/conversation")
    static let supportSendMessage  = base.appending(path: "/api/support/messages")
    static let supportUpload       = base.appending(path: "/api/support/upload")
    static func supportMessages(_ id: String) -> URL { base.appending(path: "/api/support/messages/\(id)") }
}

