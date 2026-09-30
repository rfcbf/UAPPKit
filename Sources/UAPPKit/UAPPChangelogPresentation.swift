import Foundation

func uappChangelogReleaseDate(_ value: String, locale: Locale) -> String {
    let utc = TimeZone(secondsFromGMT: 0)
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.calendar = Calendar(identifier: .gregorian)
    parser.timeZone = utc
    parser.dateFormat = "yyyy-MM-dd"
    parser.isLenient = false
    guard let date = parser.date(from: value), parser.string(from: date) == value else { return value }

    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = utc
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

/// Opções do carrossel e da paginação. A reprodução automática fica desativada por padrão.
public struct UAPPChangelogConfiguration: Sendable, Equatable {
    public let automaticallyScrolls: Bool
    public let interval: TimeInterval
    /// Quantidade de registros por página, ajustada à faixa de 1 a 50 da API.
    public let pageSize: Int

    /// Intervalos inválidos usam cinco segundos; o mínimo é um segundo.
    public init(automaticallyScrolls: Bool = false, interval: TimeInterval = 5, pageSize: Int = 10) {
        self.automaticallyScrolls = automaticallyScrolls
        self.interval = interval.isFinite ? max(1, interval) : 5
        self.pageSize = min(max(pageSize, 1), 50)
    }
}

struct UAPPChangelogItem: Identifiable, Equatable {
    let id: Int
    let section: UAPPChangelogSection
}

struct UAPPChangelogPresentation {
    let entry: UAPPChangelogEntry

    static func newestFirst(_ entries: [UAPPChangelogEntry]) -> [UAPPChangelogEntry] {
        entries.enumerated().sorted { first, second in
            let version = (first.element.version ?? "").compare(
                second.element.version ?? "", options: .numeric, locale: Locale(identifier: "en_US_POSIX")
            )
            if version != .orderedSame {
                return version == .orderedDescending
            }
            let date = (first.element.releasedAt ?? "").compare(second.element.releasedAt ?? "")
            if date != .orderedSame {
                return date == .orderedDescending
            }
            let firstPublished = first.element.publishedAt ?? .distantPast
            let secondPublished = second.element.publishedAt ?? .distantPast
            if firstPublished != secondPublished {
                return firstPublished > secondPublished
            }
            let build = (first.element.build ?? "").compare(second.element.build ?? "", options: .numeric)
            if build != .orderedSame {
                return build == .orderedDescending
            }
            return first.offset < second.offset
        }.map(\.element)
    }

    var description: String {
        entry.descriptionMarkdown ?? entry.bodyMarkdown
    }

    var items: [UAPPChangelogItem] {
        entry.sections.enumerated().map { UAPPChangelogItem(id: $0.offset, section: $0.element) }
            .sorted {
                let first = $0.section.sortPosition(fallback: $0.id)
                let second = $1.section.sortPosition(fallback: $1.id)
                if first == second {
                    return $0.id < $1.id
                }
                return first < second
            }
    }

    var imageItems: [UAPPChangelogItem] {
        items.filter { $0.section.imageURL != nil }
    }

    var textItems: [UAPPChangelogItem] {
        // Respostas legadas já incluem todos os itens em body_md.
        guard entry.descriptionMarkdown != nil else { return [] }
        return items.filter { $0.section.imageURL == nil }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return ([entry.title, entry.version ?? "", description, entry.bodyMarkdown]
            + items.map(\.section.bodyMarkdown)).contains { $0.localizedStandardContains(query) }
    }

    func selectedImage(_ selection: Int) -> UAPPChangelogItem? {
        imageItems.first { $0.id == selection } ?? imageItems.first
    }

    func nextImage(after selection: Int) -> Int? {
        let images = imageItems
        guard !images.isEmpty else { return nil }
        guard let index = images.firstIndex(where: { $0.id == selection }) else { return images.first?.id }
        return images[(index + 1) % images.count].id
    }
}
