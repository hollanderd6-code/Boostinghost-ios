import Foundation

// MARK: - GET /api/help/content

struct HelpFAQItem: Decodable, Identifiable {
    let id: Int
    let question: String
    let answerText: String
    let category: String?
    let displayOrder: Int?
}

struct HelpVideo: Decodable, Identifiable {
    let id: Int
    let title: String
    let youtubeId: String
    let displayOrder: Int?
}

struct HelpGuide: Decodable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let pageUrl: String
    let icon: String?
    let accentColor: String?
    let timeLabel: String?
    let badgeLabel: String?
    let displayOrder: Int?
}

struct HelpContentResponse: Decodable {
    let faq: [HelpFAQItem]
    let videos: [HelpVideo]
    let guides: [HelpGuide]
}
