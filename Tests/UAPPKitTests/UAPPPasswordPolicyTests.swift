import Testing
@_spi(UAPPInternal) @testable import UAPPKit

struct UAPPPasswordPolicyTests {
    @Test("Senha nova exige oito caracteres, maiúscula e símbolo", arguments: [
        "", "Abcdef!", "abcdefgh!", "Abcdefgh", "Abcdefg ", "1234567!", "abcdefg😀"
    ])
    func rejectsWeakPasswords(_ password: String) {
        #expect(!UAPPPasswordPolicy.isValid(password))
    }

    @Test("Aceita limite exato, pontuação, símbolos e letras acentuadas", arguments: [
        "Abcdefg!", "Abcdefg$", "Ábcdefg!", "Abcdefg😀",
    ])
    func acceptsStrongPasswords(_ password: String) {
        #expect(UAPPPasswordPolicy.isValid(password))
    }

    @Test("Mínimo personalizado não reduz a regra e pode ser mais restritivo")
    func customMinimum() {
        #expect(!UAPPPasswordPolicy.isValid("Abcdef!", minimumLength: 6))
        #expect(!UAPPPasswordPolicy.isValid("Abcdefg!", minimumLength: 12))
        #expect(UAPPPasswordPolicy.isValid("Abcdefghijk!", minimumLength: 12))
    }
}
