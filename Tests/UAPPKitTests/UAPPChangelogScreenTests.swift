import Foundation
import SwiftUI
import Testing
@testable import UAPPKit

@Test("data de lançamento segue idioma selecionado e mantém o dia civil")
func changelogReleaseDateLocalization() {
    let brazilian = uappChangelogReleaseDate("2026-09-30", locale: Locale(identifier: "pt-BR"))
    let english = uappChangelogReleaseDate("2026-09-30", locale: Locale(identifier: "en"))
    #expect(brazilian.contains("30"))
    #expect(brazilian.contains("set"))
    #expect(english.contains("Sep"))
    #expect(english.contains("30"))
    #expect(brazilian != english)
    for language in UAPPLanguage.supported {
        let result = uappChangelogReleaseDate("2026-09-30", locale: Locale(identifier: language.identifier))
        #expect(!result.isEmpty)
        #expect(result != "2026-09-30")
    }
    #expect(uappChangelogReleaseDate("2024-02-29", locale: Locale(identifier: "en")).contains("29"))
    #expect(uappChangelogReleaseDate("2026-01-01", locale: Locale(identifier: "en")).contains("Jan 1"))
}

@Test("datas inválidas não interrompem a leitura do changelog")
func changelogInvalidReleaseDate() {
    for value in ["", "sem data", "2026-02-30", "2026-13-01", "2026-9-1", "2026-09-30T23:00:00Z"] {
        #expect(uappChangelogReleaseDate(value, locale: Locale(identifier: "pt-BR")) == value)
    }
}

private func changelogFixture() -> UAPPChangelogEntry {
    .init(
        title: "Release", slug: "release", bodyMarkdown: "Texto completo", version: "2.0", build: "20",
        platform: .ios,
        sections: [
            .init(category: .new, bodyMarkdown: "Primeiro", position: 0, imageURL: URL(string: "https://example.invalid/1.jpg")),
            .init(category: .new, bodyMarkdown: "Segundo", position: 0, imageURL: URL(string: "https://example.invalid/2.jpg")),
            .init(category: .fixed, bodyMarkdown: "Terceiro", position: 2, imageURL: URL(string: "https://example.invalid/3.jpg")),
            .init(category: .security, bodyMarkdown: "Proteção", position: 3)
        ],
        releasedAt: "2026-09-30", descriptionMarkdown: "Descrição **geral**"
    )
}

@Test("changelog antigo mantém body_md sem repetir seções")
func changelogLegacyFallback() throws {
    let entry = try JSONDecoder().decode(UAPPChangelogEntry.self, from: json(
        #"{"title":"Antigo","slug":"old","body_md":"Texto antigo"}"#
    ))
    let presentation = UAPPChangelogPresentation(entry: entry)
    #expect(presentation.description == "Texto antigo")
    #expect(entry.sections.isEmpty)
    #expect(presentation.textItems.isEmpty)
    #expect(presentation.selectedImage(0) == nil)
    #expect(presentation.nextImage(after: 0) == nil)
}

@Test("novo contrato decodifica imagens, campos ausentes e URLs inválidas")
func changelogImagesDecode() throws {
    let entry = try JSONDecoder().decode(UAPPChangelogEntry.self, from: json(#"""
    {"title":"2.0","slug":"2-0","body_md":"Completo","description_md":"Geral","sections":[
      {"category":"new","body_md":"Primeiro","image_url":"https://example.invalid/a.jpg","position":1},
      {"category":"new","body_md":"Segundo","image_url":null,"position":1},
      {"category":"improved","body_md":"Inválida","image_url":"not a URL","position":0},
      {"category":"security","body_md":"Insegura","image_url":"http://example.invalid/a.jpg"},
      {"category":"fixed","body_md":"Sem host","image_url":"https:///"}
    ]}
    """#))
    let presentation = UAPPChangelogPresentation(entry: entry)
    #expect(presentation.description == "Geral")
    #expect(presentation.imageItems.count == 1)
    #expect(presentation.textItems.count == 4)
    #expect(presentation.items.map(\.id) == [2, 0, 1, 3, 4])
    #expect(entry.sections[3].position == 0)
    #expect(presentation.nextImage(after: 0) == 0)
    let decoded = try JSONDecoder().decode(UAPPChangelogEntry.self, from: JSONEncoder().encode(entry))
    #expect(decoded == entry)
}

@Test("seleção mantém imagem e descrição associadas e retorna ao início")
func changelogPageSelection() {
    let presentation = UAPPChangelogPresentation(entry: changelogFixture())
    #expect(presentation.imageItems.count == 3)
    #expect(presentation.textItems.map(\.section.bodyMarkdown) == ["Proteção"])
    #expect(presentation.selectedImage(-1)?.section.bodyMarkdown == "Primeiro")
    #expect(presentation.nextImage(after: -1) == 0)
    #expect(presentation.nextImage(after: 0) == 1)
    #expect(presentation.selectedImage(1)?.section.bodyMarkdown == "Segundo")
    #expect(presentation.nextImage(after: 2) == 0)
    let reduced = UAPPChangelogPresentation(entry: .init(
        title: "Changed", slug: "release", bodyMarkdown: "", sections: [presentation.imageItems[0].section]
    ))
    #expect(reduced.selectedImage(2)?.id == 0)
    #expect(reduced.nextImage(after: 2) == 0)
}

@Test("pesquisa encontra versão e descrições, ignorando caixa e acentos")
func changelogSearch() {
    let presentation = UAPPChangelogPresentation(entry: changelogFixture())
    for query in ["", "  ", "2.0", "GERAL", "protecao", "Segundo", "Release", "completo"] {
        #expect(presentation.matches(query))
    }
    #expect(!presentation.matches("9.9"))
}

@Test("configuração valida intervalo e preserva reprodução manual por padrão")
func changelogConfiguration() {
    #expect(!UAPPChangelogConfiguration().automaticallyScrolls)
    #expect(UAPPChangelogConfiguration().pageSize == 10)
    #expect(UAPPChangelogConfiguration(pageSize: 10).pageSize == 10)
    #expect(UAPPChangelogConfiguration(pageSize: .min).pageSize == 1)
    #expect(UAPPChangelogConfiguration(pageSize: .max).pageSize == 50)
    #expect(UAPPChangelogConfiguration(automaticallyScrolls: true, interval: 3).interval == 3)
    #expect(UAPPChangelogConfiguration(interval: -1).interval == 1)
    #expect(UAPPChangelogConfiguration(interval: .infinity).interval == 5)
    #expect(UAPPChangelogConfiguration(interval: .nan).interval == 5)
    #expect(UAPPChangelogSection(
        category: .new,
        bodyMarkdown: "",
        position: 0,
        imageURL: URL(string: "http://example.invalid/a")
    ).imageURL == nil)
}

@Test("cards e detalhes renderizam zero, uma e três imagens sem rede")
@MainActor
func changelogViewsRender() async {
    let entry = changelogFixture()
    let entries = [
        entry,
        UAPPChangelogEntry(title: "Texto", slug: "text", bodyMarkdown: "**Legado**"),
        UAPPChangelogEntry(
            title: "Uma",
            slug: "one",
            bodyMarkdown: "",
            sections: [entry.sections[0]],
            descriptionMarkdown: "Geral"
        )
    ]
    for entry in entries {
        await render(NavigationStack {
            UAPPChangelogCard(entry: entry, configuration: .init())
        }.environment(\.uappChangelogImageFixture, .success))
        await render(UAPPChangelogDetailScreen(entry: entry)
            .environment(\.uappChangelogImageFixture, .success))
    }
    for fixture in [UAPPChangelogImageFixture.loading, .success, .failure] {
        await render(UAPPChangelogImage(item: .init(id: 0, section: entry.sections[0]))
            .environment(\.uappChangelogImageFixture, fixture))
    }
    await render(UAPPChangelogTextItems(items: UAPPChangelogPresentation(entry: entry).textItems))
    #expect(String(uappChangelogMarkdown("**Olá**").characters) == "Olá")
}

@Test("changelog localiza categorias e controles em todos os idiomas")
func changelogLocalization() {
    let keys = UAPPChangelogCategory.allCases.map { "category.\($0.rawValue)" } + [
        "changelog.back", "changelog.search", "changelog.search_scope", "changelog.no_results",
        "changelog.image_failed", "changelog.image_loading", "changelog.image_page", "changelog.version",
        "changelog.loading_more", "changelog.detail_title"
    ]
    for language in UAPPLanguage.supported {
        for key in keys {
            #expect(uappLocalized(key, languageIdentifier: language.identifier) != key)
        }
        #expect(uappLocalized("changelog.version", languageIdentifier: language.identifier).contains(": %@"))
    }
}

@Test("versões aparecem da mais recente para a mais antiga com comparação numérica")
func changelogNewestVersionsFirst() {
    let entries: [UAPPChangelogEntry] = [
        .init(title: "Antiga", slug: "old", bodyMarkdown: "", version: "2.9"),
        .init(title: "Nova", slug: "new", bodyMarkdown: "", version: "2.10"),
        .init(title: "Build", slug: "build", bodyMarkdown: "", version: "2.10", build: "20"),
        .init(title: "Data", slug: "date", bodyMarkdown: "", version: "2.10", releasedAt: "2026-09-30"),
        .init(title: "Publicada", slug: "published", bodyMarkdown: "", publishedAt: Date(timeIntervalSince1970: 100)),
        .init(title: "Sem versão", slug: "unknown", bodyMarkdown: ""),
        .init(title: "Empate", slug: "tie", bodyMarkdown: "", version: "2.9")
    ]
    #expect(UAPPChangelogPresentation.newestFirst(entries).map(\.slug) == [
        "date", "build", "new", "old", "tie", "published", "unknown"
    ])
}
