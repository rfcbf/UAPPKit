import Foundation

enum UAPPFeedbackSort: String, CaseIterable {
    case newest, votes, comments

    var titleKey: String {
        "feedback.sort.\(rawValue)"
    }
}

enum UAPPFeedbackSearch {
    static func presentedItems(
        _ items: [UAPPFeedbackItem], matching query: String,
        category: UAPPFeedbackCategory?, statusId: String?, sort: UAPPFeedbackSort
    ) -> [UAPPFeedbackItem] {
        self.items(items, matching: query)
            .filter { (category == nil || $0.category == category) && (statusId == nil || $0.statusId == statusId) }
            .sorted {
                switch sort {
                case .votes where $0.voteCount != $1.voteCount: return $0.voteCount > $1.voteCount
                case .comments where $0.commentCount != $1.commentCount: return $0.commentCount > $1.commentCount
                default:
                    if $0.createdAt != $1.createdAt {
                        return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                    }
                    return $0.id < $1.id
                }
            }
    }

    static func items(_ items: [UAPPFeedbackItem], matching query: String) -> [UAPPFeedbackItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { matches($0.title, query) || matches($0.body ?? "", query) }
    }

    static func columns(_ columns: [UAPPRoadmapColumn], matching query: String) -> [UAPPRoadmapColumn] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return columns }
        return columns.compactMap { column in
            if matches(column.status.name, query) {
                return column
            }
            let filtered = items(column.items, matching: query)
            guard !filtered.isEmpty else { return nil }
            return UAPPRoadmapColumn(status: column.status, items: filtered)
        }
    }

    private static func matches(_ text: String, _ query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
