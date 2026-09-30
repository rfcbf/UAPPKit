import Testing
@testable import UAPPKit

@Test("erros expõem descrições localizadas")
func errorsHaveLocalizedDescriptions() {
    #expect(UAPPKitError.notConfigured.errorDescription?.contains("não configurado") == true)
    #expect(UAPPKitError.http(status: 403, message: "Bloqueado").errorDescription == "UAPP respondeu 403: Bloqueado.")
    #expect(UAPPKitError.http(status: 500, message: nil).errorDescription == "UAPP respondeu 500.")
    #expect(UAPPKitError.invalidResponse.errorDescription?.contains("formato inesperado") == true)
    #expect(UAPPKitError.transport("timeout").errorDescription?.contains("timeout") == true)
    #expect(UAPPKitError.appStoreURLCouldNotOpen.errorDescription?.contains("abrir a App Store") == true)
}
