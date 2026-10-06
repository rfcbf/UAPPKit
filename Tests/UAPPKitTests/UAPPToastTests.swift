import SwiftUI
import Testing
@testable import UAPPKit

@MainActor
struct UAPPToastTests {
    @Test("Erros e informações ficam disponíveis até o fechamento")
    func persistentNotifications() {
        #expect(UAPPToastKind.error.autoDismissInterval == nil)
        #expect(UAPPToastKind.information.autoDismissInterval == nil)
        #expect(UAPPToastKind.error.symbol == "exclamationmark.triangle.fill")
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
