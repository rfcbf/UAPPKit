import Foundation
import Testing
@testable import UAPPKit

@Test("Markdown do changelog preserva linhas, parágrafos e listas numeradas")
func changelogMarkdownPreservesBlocks() {
    let source = "1. Progresso do dia\n2. Saldo de Banco de horas\n\n- **Sincronização** agora pelo iCloud.\n\nCom essa alteração\nNão usamos mais o Firebase."
    let result = uappChangelogMarkdown(source)
    #expect(String(result.characters) == "1. Progresso do dia\n2. Saldo de Banco de horas\n\n• Sincronização agora pelo iCloud.\n\nCom essa alteração\nNão usamos mais o Firebase.")
    #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
}

@Test("Markdown aplica negrito, itálico e links sem remover estrutura")
func changelogMarkdownInlineStyles() {
    let result = uappChangelogMarkdown("**Negrito** e *itálico*\n[Site](https://example.com) e `código`")
    #expect(String(result.characters) == "Negrito e itálico\nSite e código")
    #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    #expect(result.runs.contains { $0.link == URL(string: "https://example.com") })
}

@Test("Markdown mantém títulos, marcadores, indentação e quebras do Windows")
func changelogMarkdownListVariants() {
    let result = uappChangelogMarkdown("## Novidades\r\n+ Primeiro\r\n  * Segundo\r\n3) Terceiro\r\n\r\nÚltimo\rtexto")
    #expect(String(result.characters) == "Novidades\n• Primeiro\n  • Segundo\n3. Terceiro\n\nÚltimo\ntexto")
    #expect(result.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
    #expect(String(uappChangelogMarkdown("").characters).isEmpty)
    #expect(String(uappChangelogMarkdown("Texto **incompleto").characters) == "Texto **incompleto")
}
