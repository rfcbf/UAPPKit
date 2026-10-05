import Testing
@testable import UAPPKit

struct UAPPDisplayNameTests {
    @Test("Preserva primeiro, segundo e último nome, sem abreviar partículas", arguments: [
        ("Ana Beatriz Costa Almeida Souza", "Ana Beatriz C. A. Souza"),
        ("Ana Beatriz da Silva", "Ana Beatriz da Silva"),
        ("Ana Beatriz de Costa dos Santos Souza", "Ana Beatriz de C. dos S. Souza"),
        ("Álvaro Luís Carvalho Martins Santos", "Álvaro Luís C. M. Santos"),
        ("Ana", "Ana"),
        ("  Ana   Beatriz  ", "Ana Beatriz"),
        ("", "")
    ])
    func abbreviation(_ example: (String, String)) {
        #expect(UAPPDisplayName.abbreviated(example.0) == example.1)
    }
}
