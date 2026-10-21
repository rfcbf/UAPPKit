import Foundation
import ImageIO
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit
import UniformTypeIdentifiers

@Test("Feedback e resposta enviam a imagem sem alterar o texto ou o pai")
func feedbackImagesSendPayload() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true,"id":"new"}"#) }
    let image = Data([0xFF, 0xD8, 0xFF, 0xD9])
    _ = try await client.submitFeedback(title: "Sugestão", body: "Descrição", imageData: image)
    _ = try await client.submitComment(itemId: "item", body: "Resposta", parentCommentId: "parent", imageData: image)
    #expect(recorder.requests.count == 2)
    for request in recorder.requests {
        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let attachment = try #require(payload["image"] as? [String: String])
        #expect(attachment["mimeType"] == "image/jpeg")
        #expect(attachment["base64"] == image.base64EncodedString())
    }
    let body = try #require(recorder.requests.last?.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(payload["parentCommentId"] as? String == "parent")
    #expect(payload["body"] as? String == "Resposta")
}

@Test("Anexos inválidos não fazem requisições", arguments: [
    Data(), Data([0x01, 0x02]), Data(repeating: 0xFF, count: 2 * 1024 * 1024 + 1)
])
func feedbackImagesRejectInvalidData(image: Data) async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true}"#) }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitFeedback(title: "Sugestão", imageData: image)
    }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitComment(itemId: "item", body: "Resposta", imageData: image)
    }
    #expect(recorder.requests.isEmpty)
}

@Test("Erro do servidor no envio de imagem é propagado")
func feedbackImageServerError() async {
    let client = makeClient { _ in (500, Data(#"{"error":"Falha ao salvar a imagem."}"#.utf8)) }
    await #expect(throws: UAPPKitError.http(status: 500, message: "Falha ao salvar a imagem.")) {
        try await client.submitComment(itemId: "item", body: "Imagem", imageData: Data([0xFF, 0xD8, 0xFF]))
    }
}

@Test("Feedback preserva votantes e anexo ao alternar curtida")
func feedbackImageModelsPreserveFields() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let item = try decoder.decode(UAPPFeedbackItem.self, from: Data(#"{"id":"item","title":"Sugestão","body":null,"vote_count":4,"like_count":0,"public_comment_count":1,"priority":0,"viewer_voted":false,"viewer_liked":false,"image_url":"https://example.test/image.jpg","voters":[{"displayName":"Pessoa","avatarUrl":"https://example.test/avatar.jpg"}]}"#.utf8))
    let updated = item.settingLike(enabled: true)
    #expect(updated.imageURL == item.imageURL)
    #expect(updated.voters?.first?.displayName == "Pessoa")
    #expect(updated.voters?.first?.avatarURL?.path == "/avatar.jpg")
    let comment = try decoder.decode(UAPPComment.self, from: Data(#"{"id":"reply","body":"Resposta","parentCommentId":"parent","likeCount":2,"createdAt":"2026-10-02T12:00:00Z","authorKind":"community","viewerLiked":true,"authorName":"Pessoa","authorAvatarUrl":"https://example.test/avatar.jpg","imageUrl":"https://example.test/image.jpg","moderationState":"pending"}"#.utf8))
    #expect(comment.authorName == "Pessoa")
    #expect(comment.imageURL?.path == "/image.jpg")
    #expect(comment.moderationState == "pending")
    let legacy = try decoder.decode(UAPPComment.self, from: Data(#"{"id":"old","body":"Comentário","parentCommentId":null,"likeCount":0,"createdAt":"2026-10-02T12:00:00Z","authorKind":"team","viewerLiked":false}"#.utf8))
    #expect(legacy.authorName == nil)
    #expect(legacy.authorAvatarURL == nil)
    #expect(legacy.imageURL == nil)
}

@Test("Preparação rejeita arquivos que não são imagens")
func feedbackImagePreparationRejectsInvalidImage() {
    #expect(throws: UAPPKitError.invalidResponse) {
        try UAPPFeedbackImagePreparation.jpeg(from: Data("texto".utf8))
    }
}

@Test("Foto da sessão é usada somente em comentários identificados pelo backend como próprios")
func feedbackCommentAvatarUsesConfirmedOwnership() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let viewerURL = try #require(URL(string: "https://example.test/current.jpg"))
    let serverURL = try #require(URL(string: "https://example.test/old.jpg"))
    let viewer = UAPPIdentity(userId: "viewer", displayName: "Pessoa", avatarURL: viewerURL)
    for owned in [true, false] {
        let json = "{\"id\":\"comment\",\"body\":\"Teste\",\"likeCount\":0,\"createdAt\":\"2026-10-02T12:00:00Z\",\"authorKind\":\"community\",\"viewerLiked\":false,\"authorName\":\"Pessoa\",\"authorAvatarUrl\":\"https://example.test/old.jpg\",\"viewerOwned\":\(owned)}"
        let comment = try decoder.decode(UAPPComment.self, from: Data(json.utf8))
        #expect(comment.avatarURL(viewer: viewer) == (owned ? viewerURL : serverURL))
        #expect(comment.avatarURL(viewer: nil) == serverURL)
    }
    let legacy = UAPPComment(
        id: "legacy",
        body: "Teste",
        likeCount: 0,
        createdAt: Date(),
        authorKind: .community,
        viewerLiked: false,
        authorName: "Pessoa",
        authorAvatarURL: serverURL
    )
    #expect(legacy.avatarURL(viewer: viewer) == serverURL)
    let own = UAPPComment(
        id: "own",
        body: "Teste",
        likeCount: 0,
        createdAt: Date(),
        authorKind: .community,
        viewerLiked: false,
        authorAvatarURL: serverURL,
        viewerOwned: true
    )
    #expect(own.avatarURL(viewer: UAPPIdentity(userId: "viewer")) == nil)
}

@Test("Renovação da assinatura preserva a identidade do anexo sem confundir arquivos distintos")
func feedbackAttachmentIdentityPreservesSignedImage() throws {
    let first = try #require(URL(string: "https://example.test/storage/v1/object/sign/feedback-images/app/one.jpg?token=first"))
    let renewed = try #require(URL(string: "https://example.test/storage/v1/object/sign/feedback-images/app/one.jpg?token=renewed"))
    let other = try #require(URL(string: "https://example.test/storage/v1/object/sign/feedback-images/app/two.jpg?token=first"))
    #expect(UAPPFeedbackAttachment(url: first).id == UAPPFeedbackAttachment(url: renewed).id)
    #expect(UAPPFeedbackAttachment(url: first).id != UAPPFeedbackAttachment(url: other).id)
    let publicURL = try #require(URL(string: "https://example.test/image?version=2"))
    #expect(UAPPFeedbackAttachment(url: publicURL).id == publicURL.absoluteString)
}

@Test("Feedback e comentário enviam duas imagens compactadas na ordem escolhida")
func feedbackTwoImagesSendPayload() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true,"id":"new"}"#) }
    let images = [Data([0xFF, 0xD8, 0xFF]), Data([0xFF, 0xD8, 0xFF, 0xD9])]
    let description = "1 alguma coisa\n2 outra coisa\n3 mais uma coisa\n\nObservação final"
    _ = try await client.submitFeedback(title: "Sugestão", body: description, imagesData: images)
    _ = try await client.submitComment(itemId: "item", body: "Resposta", parentCommentId: "parent", imagesData: images)
    for request in recorder.requests {
        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let attachments = try #require(payload["images"] as? [[String: String]])
        #expect(attachments.map { $0["base64"] } == images.map { Optional($0.base64EncodedString()) })
        #expect(payload["image"] == nil)
    }
    #expect(recorder.requests.count == 2)
    let feedbackBody = try #require(recorder.requests.first?.httpBody)
    let feedbackPayload = try #require(JSONSerialization.jsonObject(with: feedbackBody) as? [String: Any])
    #expect(feedbackPayload["body"] as? String == description)
}

@Test("Mais de duas imagens, imagens grandes e anexos inválidos são recusados antes da rede", arguments: [
    Array(repeating: Data([0xFF, 0xD8, 0xFF]), count: 3),
    [Data([0xFF, 0xD8, 0xFF]), Data(repeating: 0xFF, count: 512 * 1024 + 1)],
    [Data([0xFF, 0xD8, 0xFF]), Data()]
])
func feedbackTwoImagesRejectInvalidPayload(images: [Data]) async {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true}"#) }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitFeedback(title: "Sugestão", imagesData: images)
    }
    await #expect(throws: UAPPKitError.invalidResponse) {
        try await client.submitComment(itemId: "item", body: "Resposta", imagesData: images)
    }
    #expect(recorder.requests.isEmpty)
}

@Test("Duas imagens são decodificadas e preservadas; respostas antigas continuam exibindo o anexo")
func feedbackTwoImagesDecode() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let item = try decoder.decode(UAPPFeedbackItem.self, from: Data(#"{"id":"item","title":"Sugestão","vote_count":0,"like_count":0,"public_comment_count":0,"priority":0,"viewer_voted":false,"viewer_liked":false,"image_url":"https://example.test/one.jpg","image_urls":["https://example.test/one.jpg","https://example.test/two.jpg"]}"#.utf8))
    #expect(item.attachmentURLs.map(\.lastPathComponent) == ["one.jpg", "two.jpg"])
    #expect(item.settingLike(enabled: true).imageURLs == item.imageURLs)
    let comment = try decoder.decode(UAPPComment.self, from: Data(#"{"id":"reply","body":"Resposta","likeCount":0,"createdAt":"2026-10-02T12:00:00Z","authorKind":"community","viewerLiked":false,"imageUrls":["https://example.test/one.jpg","https://example.test/two.jpg"]}"#.utf8))
    #expect(comment.attachmentURLs.count == 2)
    let legacy = try decoder.decode(UAPPComment.self, from: Data(#"{"id":"reply","body":"Resposta","likeCount":0,"createdAt":"2026-10-02T12:00:00Z","authorKind":"community","viewerLiked":false,"imageUrl":"https://example.test/one.jpg"}"#.utf8))
    #expect(legacy.attachmentURLs.map(\.lastPathComponent) == ["one.jpg"])
}

@Test("Lista vazia não envia anexos e erros do novo contrato são propagados")
func feedbackTwoImagesOptionalAndServerFailure() async throws {
    let recorder = RequestRecorder()
    let client = makeClient(recorder: recorder) { _ in response(#"{"ok":true}"#) }
    _ = try await client.submitFeedback(title: "Sugestão", imagesData: [])
    _ = try await client.submitComment(itemId: "item", body: "Resposta", imagesData: [])
    for request in recorder.requests {
        let body = try #require(request.httpBody)
        let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(payload["images"] == nil && payload["image"] == nil)
    }
    let failed = makeClient { _ in (500, Data(#"{"error":"Falha ao salvar a imagem."}"#.utf8)) }
    await #expect(throws: UAPPKitError.http(status: 500, message: "Falha ao salvar a imagem.")) {
        try await failed.submitComment(itemId: "item", body: "Resposta", imagesData: [Data([0xFF, 0xD8, 0xFF])])
    }
}

@Test("Preparação limita tamanho e resolução e remove localização")
func feedbackImagePreparationCompresses() throws {
    let context = try #require(CGContext(
        data: nil,
        width: 2400,
        height: 1200,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
    let image = try #require(context.makeImage())
    let original = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(original, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1, kCGImagePropertyGPSLatitudeRef: "N"]
    ] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    let prepared = try UAPPFeedbackImagePreparation.jpeg(from: original as Data)
    #expect(prepared.count <= 512 * 1024)
    let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
    let result = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(result.width <= 1600 && result.height <= 1600)
    let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    #expect(properties[kCGImagePropertyGPSDictionary as String] == nil)
}
