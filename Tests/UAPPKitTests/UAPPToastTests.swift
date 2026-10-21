import SwiftUI
import Testing
@_spi(UAPPInternal) @testable import UAPPKit

@MainActor
struct UAPPToastTests {
    @Test("Erros e informações ficam disponíveis até o fechamento")
    func persistentNotifications() {
        #expect(UAPPToastKind.error.autoDismissInterval == nil)
        #expect(UAPPToastKind.information.autoDismissInterval == nil)
        #expect(UAPPToastKind.error.symbol == "exclamationmark.triangle.fill")
    }

    @Test("A contagem regressiva esvazia o anel e mostra os segundos que faltam")
    func countdown() {
        #expect(ToastCountdown.seconds(.seconds(6)) == 6)
        #expect(ToastCountdown.seconds(.milliseconds(1500)) == 1.5)
        #expect(ToastCountdown.fraction(total: 6, elapsed: 0) == 1)
        #expect(ToastCountdown.fraction(total: 6, elapsed: 3) == 0.5)
        #expect(ToastCountdown.fraction(total: 6, elapsed: 9) == 0)
        #expect(ToastCountdown.fraction(total: 0, elapsed: 1) == 0)
        #expect(ToastCountdown.secondsLeft(total: 6, elapsed: 0) == 6)
        #expect(ToastCountdown.secondsLeft(total: 6, elapsed: 0.2) == 6)
        #expect(ToastCountdown.secondsLeft(total: 6, elapsed: 5.5) == 1)
        #expect(ToastCountdown.secondsLeft(total: 6, elapsed: 7) == 0)
    }

    @Test("Aviso com duração própria substitui o tempo padrão do tipo")
    func customDuration() {
        let toast = Toast(message: "Publicando", kind: .information, duration: .seconds(15))
        #expect(toast.duration == .seconds(15))
        #expect(Toast(message: "Erro", kind: .error).duration == nil)
    }

    @Test("Avisos do app de demonstração existem em todos os idiomas, com os segundos")
    func demoCommentTexts() {
        for language in UAPPLanguage.supported {
            for key in [
                "detail.comment_demo_title", "detail.comment_demo_auto_publish",
                "feedback.demo_title", "feedback.demo_auto_publish"
            ] {
                let text = uappLocalized(key, languageIdentifier: language.identifier)
                #expect(!text.isEmpty && text != key)
            }
            for key in ["detail.comment_demo_auto_publish", "feedback.demo_auto_publish"] {
                #expect(uappLocalized(key, languageIdentifier: language.identifier).contains("%lld"))
            }
        }
        let request = String(format: uappLocalized("feedback.demo_auto_publish", languageIdentifier: "pt-BR"), 15)
        #expect(request == "Este app é uma demonstração: sua requisição será publicada em 15 segundos.")
        let text = String(format: uappLocalized("detail.comment_demo_auto_publish", languageIdentifier: "pt-BR"), 15)
        #expect(text == "Este app é uma demonstração: seu comentário será publicado em 15 segundos.")
    }

    @Test("Cada tipo de aviso tem título em todos os idiomas")
    func kindTitles() {
        for kind in UAPPToastKind.allCases {
            for language in UAPPLanguage.supported {
                let title = uappLocalized(kind.titleKey, languageIdentifier: language.identifier)
                #expect(!title.isEmpty && title != kind.titleKey)
            }
        }
        #expect(uappLocalized(UAPPToastKind.success.titleKey, languageIdentifier: "pt-BR") == "Concluído")
    }

    @Test("Sucesso tem duração e identidade independente")
    func successNotifications() {
        #expect(UAPPToastKind.success.autoDismissInterval == .seconds(6))
        let first = Toast(message: "Concluído", kind: .success)
        let second = Toast(message: "Concluído", kind: .success)
        #expect(first.id != second.id)
        #expect(first != second)
    }

    @Test("Fechar um aviso da conta preserva a etapa e os dados do formulário")
    func dismissAccountNotice() async {
        let model = UAPPAccountModel(provider: AccountProviderStub(), minimumPasswordLength: 8) { _ in }
        model.navigate(to: .recover)
        model.email = "person@example.test"
        await model.submit()
        await model.resendCode()
        #expect(model.noticeKey != nil)
        let step = model.step
        let email = model.email
        model.dismissStatusMessages()
        #expect(model.noticeKey == nil)
        #expect(model.errorKey == nil)
        #expect(model.step == step)
        #expect(model.email == email)
    }
}
