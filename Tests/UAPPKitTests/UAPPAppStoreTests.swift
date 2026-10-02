import Foundation
import Testing
@testable import UAPPKit

@Test("Identificador da App Store aceita todas as chaves alternativas", arguments: [
    "appleAppId", "apple_app_id", "appStoreAppId", "app_store_app_id", "appStoreId", "app_store_id",
    "appId", "app_id", "appleId", "apple_id"
])
func aboutAppDecodesAlternateAppleIds(key: String) throws {
    let app = try JSONDecoder().decode(UAPPAboutApp.self, from: json(#"{"name":"App","\#(key)":123456789}"#))
    #expect(app.appleAppId == "123456789")
    #expect(app.appStoreDestination?.absoluteString == "itms-apps://itunes.apple.com/app/id123456789")
    #expect(app.id == "123456789")
}

@Test("Links e ícones aceitam chaves alternativas e o nome identifica app sem link")
func aboutAppDecodesAlternateLinks() throws {
    let camel = try JSONDecoder().decode(UAPPAboutApp.self, from: json(
        #"{"name":"App","appStoreUrl":"https://apps.apple.com/app/id123456","icon_url":"https://example.test/icon.png","project_id":"projeto"}"#
    ))
    #expect(camel.appStoreURL == "https://apps.apple.com/app/id123456")
    #expect(camel.iconURL?.host == "example.test")
    #expect(camel.projectId == "projeto")
    #expect(camel.id == camel.appStoreURL)
    let snake = try JSONDecoder().decode(UAPPAboutApp.self, from: json(#"{"name":"Sem link","app_store_url":"http://apps.apple.com/x"}"#))
    #expect(snake.appStoreDestination == nil)
    #expect(snake.appStoreReviewDestination == nil)
    let bare = try JSONDecoder().decode(UAPPAboutApp.self, from: json(#"{"name":"Somente nome"}"#))
    #expect(bare.id == "Somente nome")
}

@Test("Identificador inválido é descartado e avaliação substitui ação existente")
func appStoreHelpersNormalizeValues() throws {
    #expect(uappNormalizedAppleAppId(nil) == nil)
    #expect(uappNormalizedAppleAppId(" id123456 ") == "123456")
    #expect(uappNormalizedAppleAppId("12") == nil)
    #expect(uappAppStoreReviewURL(destination: nil) == nil)
    let url = try #require(URL(string: "https://apps.apple.com/app/id123456?action=open&l=pt"))
    let review = try #require(uappAppStoreReviewURL(destination: url))
    let items = URLComponents(url: review, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.filter { $0.name == "action" }.map(\.value) == ["write-review"])
    #expect(items.contains(URLQueryItem(name: "l", value: "pt")))
}
