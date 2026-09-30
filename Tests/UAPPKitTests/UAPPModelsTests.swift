import Foundation
import Testing
@testable import UAPPKit

@Test("enums públicos codificam os valores do contrato")
func publicEnumsUseContractValues() throws {
    #expect(UAPPFeedbackCategory.allCases.map(\.rawValue) == ["bug", "feature", "improvement", "question"])
    #expect(UAPPChangelogCategory.allCases.map(\.rawValue) == ["new", "improved", "fixed", "security"])
    #expect(UAPPChangelogPlatform.allCases.map(\.rawValue) == ["all", "ios", "ipados", "macos", "watchos", "tvos", "visionos"])
    #expect(try JSONDecoder().decode(UAPPReactionKind.self, from: json(#""like""#)) == .like)
}

@Test("item de feedback decodifica chaves snake_case e datas ISO")
func feedbackItemDecodesContractKeys() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let item = try decoder.decode(UAPPFeedbackItem.self, from: json("""
    {"id":"1","title":"Modo escuro","body":null,"vote_count":12,"like_count":4,
     "public_comment_count":3,"category":"feature","priority":80,"viewer_voted":true,
     "viewer_liked":false,"created_at":"2026-09-07T12:00:00Z"}
    """))

    #expect(item.id == "1")
    #expect(item.title == "Modo escuro")
    #expect(item.body == nil)
    #expect(item.voteCount == 12)
    #expect(item.likeCount == 4)
    #expect(item.commentCount == 3)
    #expect(item.category == .feature)
    #expect(item.priority == 80)
    #expect(item.viewerVoted)
    #expect(!item.viewerLiked)
    #expect(item.createdAt != nil)
}

@Test("modelos públicos mantêm defaults e identificadores")
func publicModelsKeepDefaultsAndIdentifiers() {
    let item = UAPPFeedbackItem(id: "id", title: "Título", body: nil, voteCount: 0, likeCount: 0, commentCount: 0)
    #expect(item.category == nil)
    #expect(item.priority == 0)
    #expect(item.viewerVoted == false)
    #expect(item.viewerLiked == false)
    #expect(item.id == "id")

    let entry = UAPPChangelogEntry(title: "Novidade", slug: "novidade", bodyMarkdown: "Texto")
    #expect(entry.id == "novidade")
    #expect(entry.sections.isEmpty)

    let page = UAPPFeedbackPage(items: [item], nextCursor: "next")
    #expect(page.items == [item])
    #expect(page.nextCursor == "next")
    #expect(UAPPCommentsPage(comments: [], nextCursor: nil).comments.isEmpty)
    #expect(UAPPChangelogPage(entries: [entry], nextCursor: nil, totalCount: 1).totalCount == 1)
}

@Test("comentários e avaliações decodificam datas e campos opcionais")
func commentsAndReviewsDecode() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let comment = try decoder.decode(UAPPComment.self, from: json("""
    {"id":"c1","body":"Oi","parentCommentId":null,"likeCount":2,
     "createdAt":"2026-09-07T12:00:00Z","authorKind":"team","viewerLiked":true}
    """))
    let review = try decoder.decode(UAPPReview.self, from: json("""
    {"id":"r1","rating":5,"title":null,"body":"Muito bom",
     "reviewer_nickname":"Ana","reviewed_at":"2026-09-24T12:00:00Z"}
    """))

    #expect(comment.authorKind == .team)
    #expect(comment.parentCommentId == nil)
    #expect(comment.likeCount == 2)
    #expect(comment.viewerLiked)
    #expect(review.responseBody == nil)
    #expect(review.rating == 5)
    #expect(review.title == nil)
    #expect(review.reviewerName == "Ana")
    #expect(review.reviewedAt != nil)
}

@Test("about app valida o destino da App Store")
func aboutAppValidatesAppStoreDestination() throws {
    let withId = try JSONDecoder().decode(UAPPAboutApp.self, from: json("""
    {"name":"App X","subtitle":"Resumo","appStoreURL":"https://invalid.example/app",
     "appleAppId":"123456789","iconURL":"https://cdn.example/icon.png"}
    """))
    let withValidURL = UAPPAboutApp(
        name: "App Y",
        subtitle: nil,
        appStoreURL: "https://itunes.apple.com/app/id1",
        appleAppId: "abc",
        iconURL: nil
    )
    let invalid = UAPPAboutApp(
        name: "App Z",
        subtitle: nil,
        appStoreURL: "http://evil.example/app",
        appleAppId: "12",
        iconURL: nil
    )

    #expect(withId.id == "https://invalid.example/app")
    #expect(withId.appStoreDestination?.absoluteString == "itms-apps://itunes.apple.com/app/id123456789")
    #expect(withValidURL.appStoreDestination?.host == "itunes.apple.com")
    #expect(invalid.appStoreDestination == nil)

    let numericId = try JSONDecoder().decode(UAPPAboutApp.self, from: json("""
    {"name":"App Numérico","subtitle":null,"appStoreURL":"https://apps.apple.com/app/id123456789","appleAppId":123456789,"iconURL":null}
    """))
    #expect(numericId.appStoreReviewDestination?.query == "action=write-review")

    let onlyId = try JSONDecoder().decode(UAPPAboutApp.self, from: json("""
    {"name":"App somente ID","subtitle":null,"apple_app_id":"987654321","iconURL":null}
    """))
    #expect(onlyId.appStoreReviewDestination?.absoluteString == "itms-apps://itunes.apple.com/app/id987654321?action=write-review")
}

@Test("projeto decodifica o app configurado e monta o link de avaliação")
func projectBuildsAppStoreReviewDestination() throws {
    let project = try JSONDecoder().decode(UAPPProject.self, from: json("""
    {"slug":"calcjuros-dev","displayName":"CalcJuros","icon_url":"https://cdn.example/calcjuros.png","appStoreUrl":"https://apps.apple.com/br/app/calcjuros/id123456789"}
    """))

    #expect(project.slug == "calcjuros-dev")
    #expect(project.iconURL?.absoluteString == "https://cdn.example/calcjuros.png")
    #expect(project.appStoreReviewDestination?.absoluteString == "https://apps.apple.com/br/app/calcjuros/id123456789?action=write-review")

    let projectWithOnlyId = try JSONDecoder().decode(UAPPProject.self, from: json("""
    {"slug":"calcjuros-dev","displayName":"CalcJuros","apple_app_id":987654321}
    """))
    #expect(projectWithOnlyId.appStoreReviewDestination?.absoluteString == "itms-apps://itunes.apple.com/app/id987654321?action=write-review")
}

@Test("changelog decodifica seções e campos opcionais")
func changelogDecodesSections() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let entry = try decoder.decode(UAPPChangelogEntry.self, from: json("""
    {"title":"Versão 1","slug":"v1","body_md":"**Olá**","version":"1.0",
     "build":"10","platform":"ios","released_at":"2026-09-24",
     "published_at":"2026-09-24T12:00:00Z","sections":[
       {"category":"new","body_md":"Item novo","position":1}]}
    """))

    #expect(entry.version == "1.0")
    #expect(entry.build == "10")
    #expect(entry.platform == .ios)
    #expect(entry.releasedAt == "2026-09-24")
    #expect(entry.sections.first?.category == .new)
    #expect(entry.sections.first?.bodyMarkdown == "Item novo")
    #expect(entry.publishedAt != nil)
}

@Test("filtros de changelog geram somente os parâmetros preenchidos")
func changelogFiltersGenerateQueryItems() {
    let filters = UAPPChangelogFilters(
        category: .fixed,
        platform: .macos,
        version: "2.0",
        build: "20",
        from: "2026-01-01",
        to: "2026-09-24"
    )
    #expect(filters.queryItems == [
        URLQueryItem(name: "category", value: "fixed"),
        URLQueryItem(name: "platform", value: "macos"),
        URLQueryItem(name: "version", value: "2.0"),
        URLQueryItem(name: "build", value: "20"),
        URLQueryItem(name: "from", value: "2026-01-01"),
        URLQueryItem(name: "to", value: "2026-09-24")
    ])
    #expect(UAPPChangelogFilters().queryItems.isEmpty)
}
