import Foundation

/// Regras compartilhadas para cadastro e troca de senha. Não restringe senhas de login existentes.
public enum UAPPPasswordPolicy {
    public static let minimumLength = 8

    public static func isValid(_ password: String, minimumLength: Int = UAPPPasswordPolicy.minimumLength) -> Bool {
        let scalars = password.unicodeScalars
        return password.count >= max(Self.minimumLength, minimumLength)
            && scalars.contains(where: CharacterSet.uppercaseLetters.contains)
            && scalars.contains(where: {
                CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0)
            })
    }
}
