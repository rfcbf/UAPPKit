import Foundation
import Testing
@testable import UAPPKit

@Test("estatísticas usam votos separados dos campos legados")
func userActivityUsesVoteTotals() throws {
    let data = Data(#"{"totals":{"likes":9,"votes":4,"comments":2,"feedbacks":1},"items":[{"id":"item","title":"Feedback","state":"published","vote_count":3,"like_count":8,"created_at":"2026-10-01T12:00:00Z"}]}"#.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let page = try decoder.decode(UAPPUserActivityPage.self, from: data)
    #expect(page.totals.votes == 4)
    #expect(page.items.first?.voteCount == 3)
}

@Test("respostas antigas não apresentam reações legadas como votos")
func userActivityMissingVotes() throws {
    let data = Data(#"{"totals":{"likes":9,"comments":0,"feedbacks":0},"items":[]}"#.utf8)
    let page = try JSONDecoder().decode(UAPPUserActivityPage.self, from: data)
    #expect(page.totals.votes == 0)
}
