import Foundation
import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

private struct DescribedError: LocalizedError {
    let errorDescription: String?
}

@MainActor
private final class SubmissionRecorder {
    var submissions: [UAPPFeedbackSubmission] = []
}

@Test("envio do aplicativo recebe a requisição montada pelo compositor")
@MainActor
func feedbackComposerCustomSenderForwardsSubmission() async throws {
    let recorder = SubmissionRecorder()
    let sender = UAPPFeedbackSender.custom { recorder.submissions.append($0) }
    let submission = UAPPFeedbackSubmission(
        title: "Exportar planilha",
        details: "Relatório mensal",
        category: .improvement,
        imagesData: [Data([0x01])]
    )

    try await sender.send(submission)

    #expect(recorder.submissions == [submission])
    #expect(UAPPFeedbackSubmission(title: "Só título") == UAPPFeedbackSubmission(
        title: "Só título", details: "", category: .feature, imagesData: []
    ))
}

@Test("envio pelo cliente continua chamando a API de feedback do projeto")
@MainActor
func feedbackComposerClientSenderUsesProjectAPI() async throws {
    let requests = RequestRecorder()
    let client = makeClient(recorder: requests) { _ in response(#"{"ok":true,"id":"feedback"}"#) }
    let sender = UAPPFeedbackSender.client(client)

    try await sender.send(UAPPFeedbackSubmission(title: "Novo feedback", details: "Detalhes", category: .bug))

    let body = try #require(requests.requests.first?.httpBody)
    let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(payload["title"] as? String == "Novo feedback")
    #expect(payload["category"] as? String == "bug")
}

@Test("falha do envio do aplicativo mostra a descrição do erro quando houver")
func feedbackComposerCustomFailureUsesLocalizedDescription() {
    let sender = UAPPFeedbackSender.custom { _ in }

    #expect(sender.failure(for: DescribedError(errorDescription: " Limite diário atingido. "))
        == .described("Limite diário atingido."))
    #expect(sender.failure(for: DescribedError(errorDescription: nil)) == .generic)
    #expect(sender.failure(for: DescribedError(errorDescription: "  ")) == .generic)
    #expect(sender.failure(for: TestError.expected) == .generic)
    #expect(UAPPFeedbackSubmitFailure.described("Limite diário atingido.").message == "Limite diário atingido.")
}

@Test("falha do envio pelo cliente mantém a mensagem genérica")
func feedbackComposerClientFailureStaysGeneric() {
    let client = makeClient { _ in response(#"{"ok":true}"#) }
    let sender = UAPPFeedbackSender.client(client)

    #expect(sender.failure(for: DescribedError(errorDescription: "Detalhe interno")) == .generic)
    #expect(sender.failure(for: UAPPKitError.invalidResponse) == .generic)
    #expect(UAPPFeedbackSubmitFailure.generic.message == uappLocalized("feedback.submit_error"))
}

@Test("UAPPFeedbackComposerScreen abre o compositor com envio próprio")
@MainActor
func feedbackComposerScreenRendersCustomSender() async {
    let draft = UAPPFeedbackDraft(title: "Exportar planilha", category: .feature)
    await render(UAPPFeedbackComposerScreen(draft: draft, submit: { _ in }, onComplete: {}))
    await render(UAPPSubmitFeedbackScreen(sender: .custom { _ in }, draft: draft, onComplete: {}))
}
