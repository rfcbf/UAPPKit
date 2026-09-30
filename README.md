# UAPPKit

A tela de changelog oferece imagens por item, carrossel com reprodução automática
opcional, pesquisa nas versões carregadas e detalhes completos.
Veja [configuração e compatibilidade](Documentation/Changelog.md).

SDK Swift para adicionar experiências nativas de Feedback, Roadmap e Changelog
do UAPP a aplicativos Apple. A interface usa SwiftUI e não incorpora conteúdo
em uma WebView.

O pacote oferece um cliente HTTP assíncrono para leitura de conteúdo público,
envio de feedback, reações e comentários. Não tem dependências externas.

## Requisitos

- Swift 6.0 ou posterior.
- iOS 16 ou posterior, incluindo iPadOS.
- macOS 13 ou posterior para usar o cliente e as views SwiftUI.

O pacote não declara suporte a watchOS, tvOS ou visionOS.

## Instalação pelo Swift Package Manager

No Xcode, escolha **File → Add Package Dependencies…** e informe:

```text
https://github.com/rfcbf/UAPPKit
```

Até a primeira release versionada, selecione a branch `main` no Xcode e adicione
o produto `UAPPKit` ao target do aplicativo. Em outro `Package.swift`, use:

```swift
dependencies: [
    .package(url: "https://github.com/rfcbf/UAPPKit", branch: "main")
]
```

Quando uma release `0.1.0` for publicada, consumidores que preferem versões
estáveis poderão trocar por `.package(url: "https://github.com/rfcbf/UAPPKit", from: "0.1.0")`.
Em seguida, declare `UAPPKit` nas dependências do target consumidor.

## Configuração e telas nativas

```swift
import SwiftUI
import UAPPKit

@main
struct ExampleApp: App {
    init() {
        UAPPKit.setup(projectId: "meu-app", theme: .system)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

O tema é configurado uma vez no `setup` e vale para todas as telas do pacote.
Por padrão, o UAPPKit usa cores semânticas do sistema; para personalizar, passe
paletas independentes para os modos claro e escuro. Cores omitidas continuam
usando os valores dinâmicos do sistema, e o modo ativo é acompanhado
automaticamente:

```swift
UAPPKit.setup(
    projectId: "meu-app",
    theme: UAPPTheme(
        light: .init(
            background: Color(red: 0.96, green: 0.95, blue: 1),
            cardBackground: .white,
            primaryText: Color(red: 0.12, green: 0.10, blue: 0.20),
            secondaryText: .secondary,
            accent: Color(red: 0.36, green: 0.30, blue: 0.96),
            buttonText: .white
        ),
        dark: .init(
            background: Color(red: 0.08, green: 0.07, blue: 0.12),
            cardBackground: Color(red: 0.14, green: 0.13, blue: 0.19),
            primaryText: .white,
            secondaryText: Color.white.opacity(0.68),
            accent: Color(red: 0.56, green: 0.51, blue: 1),
            buttonText: Color(red: 0.08, green: 0.07, blue: 0.12)
        )
    )
)
```

As cores personalizáveis são `background`, `cardBackground`, `primaryText`,
`secondaryText`, `accent`, `buttonText` e `separator`. `buttonText` controla a
legibilidade do texto em botões preenchidos e, por padrão, é branco. Se a cor de destaque não for definida,
o UAPPKit usa a cor pública configurada para o aplicativo no UAPP e, antes de
recebê-la, usa a cor de destaque do sistema.

O `projectId` é o identificador público do projeto (`public_slug`) configurado
no UAPP. Em iOS, os métodos abaixo apresentam telas SwiftUI nativas a partir do
view controller ativo:

```swift
try UAPPKit.showFeedback()
try UAPPKit.showRoadmap()
try UAPPKit.showChangelog(configuration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10))
try UAPPKit.showReviews(pageSize: 20)
try UAPPKit.showAbout(configuration: UAPPAboutConfiguration(
    shortDescription: "Uma descrição curta do aplicativo",
    descriptionLanguageIdentifier: "pt-BR",
    websiteURL: URL(string: "https://meuapp.com"),
    supportURL: URL(string: "mailto:suporte@meuapp.com"),
    privacyPolicyURL: URL(string: "https://meuapp.com/privacidade"),
    termsOfUseURL: URL(string: "https://meuapp.com/termos"),
    license: "MIT",
    showsChangelog: true,
    showsAppStoreReview: true,
    changelogConfiguration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10)
))
Task {
    try? await UAPPKit.openAppStoreReview()
}
```

`showReviews(pageSize:)` apresenta as avaliações da App Store sincronizadas e tornadas
públicas no UAPP, carregando a quantidade de itens indicada conforme a rolagem.
O parâmetro é obrigatório: use `try UAPPKit.showReviews(pageSize: 20)`; o valor é
ajustado à faixa de 1 a 50 aceita pela API. O rodapé mostra um indicador e
“Carregando mais avaliações…” enquanto a próxima página está em andamento. Autor e
data aparecem à direita das estrelas; respostas do desenvolvedor podem ser
expandidas e recolhidas. No iOS 18+/macOS 15+, título, texto e resposta são
traduzidos para o idioma escolhido, com identificação do idioma original pelo
Natural Language e Apple Translation. Em versões anteriores ou se a tradução
falhar, o conteúdo original é preservado. A paginação depende de o endpoint
retornar `nextCursor`; endpoints antigos continuam exibindo sua primeira lista.
Veja o [contrato de reviews](Documentation/Reviews.md).

`showAbout(configuration:)` apresenta a tela Sobre como uma
sheet nativa, descobre automaticamente o ícone, o nome e a versão do app e
aceita como parâmetros a descrição curta, o idioma original da descrição,
links institucionais e a licença. Em dispositivos compatíveis com a Translation
framework da Apple, a descrição é traduzida sob demanda para o idioma escolhido
na sheet; em versões sem suporte ou quando a tradução não estiver disponível,
o texto original é mantido. Com `showsChangelog: true`, a tela Sobre também
oferece o Changelog em uma sheet grande, usando o projeto configurado.
`changelogConfiguration` define a reprodução automática e o intervalo do
carrossel aberto por essa ação, além de `pageSize` para a quantidade de registros
por página. O tamanho padrão é 10, ajustado à faixa de 1 a 50 da API; quando
a configuração é omitida, a reprodução é manual. Com
`showsAppStoreReview: true`, ela também exibe a ação para avaliar o app na
App Store.
`openAppStoreReview()` usa o projeto informado em `setup(projectId:)`, carrega
o destino da App Store publicado para esse projeto e abre diretamente o fluxo
de avaliação com `action=write-review`.
O perfil público do desenvolvedor fica em uma tela separada:

```swift
try UAPPKit.showDeveloperAbout()
```

Essa tela consulta o perfil, outros apps e redes sociais configurados no UAPP;
ela não é misturada com o Sobre do aplicativo.

Migração: chamadas antigas a `UAPPAboutScreen(client:)` devem usar
`UAPPDeveloperAboutScreen(client:)`. A tela `UAPPAboutScreen` agora representa
exclusivamente o aplicativo hospedeiro.

## Idioma e localização

Os textos nativos do UAPPKit ficam em um catálogo String Catalog
(`Localizable.xcstrings`) e começam no idioma configurado pelo aplicativo
hospedeiro. Se o app não informar um idioma, o SDK tenta usar o idioma atual do
sistema e volta para Português (Brasil) quando ele não estiver disponível.

Para definir o idioma inicial explicitamente:

```swift
UAPPKit.setup(
    projectId: "meu-app",
    locale: Locale(identifier: "en")
)
```

Todas as telas do pacote exibem um seletor próprio de idioma. Cada apresentação
começa no idioma atual do aplicativo hospedeiro, mas uma alteração feita dentro
da sheet fica restrita àquela apresentação e não altera o idioma do aplicativo
por trás. Ao abrir outra tela, o idioma inicial volta a acompanhar o hospedeiro.
Os idiomas disponíveis são
Português (Brasil), Inglês, Alemão, Francês, Espanhol, Japonês, Chinês
Simplificado, Chinês Tradicional, Polonês, Hindi, Vietnamita, Italiano e
Coreano.

O app pode alterar o idioma programaticamente com
`UAPPKit.setLocale(Locale(identifier: "de"))`. A chave pública
`UAPPKit.localePreferenceKey` também pode ser usada por uma tela própria para
acompanhar a seleção persistida do aplicativo hospedeiro.

Também é possível incorporar a view na navegação do próprio aplicativo:

```swift
NavigationStack {
    UAPPFeedbackScreen(
        client: try UAPPKit.makeClient(),
        mode: .roadmap
    )
}
```

## Cliente para interface própria

`UAPPClient` pode ser usado sem apresentação automática. Seus métodos são
assíncronos:

```swift
let client = try UAPPKit.makeClient()
let feedbackPage = try await client.feedbackPage(limit: 20)
let columns = try await client.roadmap()
let entries = try await client.changelog()
let filteredReleases = try await client.changelog(
    limit: 20,
    filters: UAPPChangelogFilters(
        category: .security,
        platform: .ios,
        from: "2026-01-01",
        to: "2026-12-31"
    )
)
let commentPage = try await client.comments(itemId: "feedback-id")

let submittedId = try await client.submitFeedback(
    title: "Melhorar o fluxo de login",
    body: "Seria útil manter a sessão ativa.",
    category: .improvement
)

try await client.setReaction(
    itemId: "feedback-id",
    kind: .vote,
    enabled: true
)

try await client.submitComment(
    itemId: "feedback-id",
    body: "Também seria útil para mim."
)
```

As páginas de feedback e comentários incluem `nextCursor` para paginação. Use
`changelogPage(limit:cursor:filters:)` para paginar o Changelog. As reações
disponíveis são voto e curtida. Comentários enviados entram em moderação.

## Identidade opcional

É possível associar ações a uma identidade fornecida pelo aplicativo:

```swift
UAPPKit.identify(
    userId: "user-123",
    email: "pessoa@example.com",
    displayName: "Pessoa"
)

// Ao encerrar a sessão do usuário:
UAPPKit.reset()
```

Essa identidade representa um usuário final do aplicativo e não cria nem
autentica uma conta no painel UAPP.

Para fornecer uma assinatura obtida no servidor do integrador:

```swift
UAPPKit.setup(projectId: "meu-app") {
    try await minhaAPI.obterAssinaturaUAPP()
}
```

O token é enviado no header `x-uapp-signature` como Bearer. O backend atual
ainda não valida esse token; portanto, ele não deve ser tratado como controle
de autorização ativo.

## Segurança e privacidade

- `projectId` e host identificam o projeto e não são segredos.
- Não coloque chaves administrativas, segredos Supabase, tokens APNs ou
  credenciais Apple no aplicativo.
- As operações usam endpoints públicos do UAPP, que devem retornar somente
  conteúdo público. O backend aplica publicação, visibilidade, moderação e
  limites de envio.
- O SDK cria e persiste um UUID de instalação por projeto em `UserDefaults`
  para identificar reações e dar suporte a chaves de idempotência.
- `identify` envia os dados opcionais informados pelo aplicativo em ações de
  feedback. Use-o somente conforme a política de privacidade e consentimento
  do seu aplicativo.

Mais detalhes estão em [`Documentation/Architecture.md`](Documentation/Architecture.md),
[`Documentation/Decisions.md`](Documentation/Decisions.md) e
[`Documentation/Roadmap.md`](Documentation/Roadmap.md).

## Desenvolvimento

```sh
swift package dump-package
swift build
swift build -c release
swift test
swiftformat . --lint
swiftlint lint --strict
```

As ferramentas de desenvolvimento podem ser instaladas com
`brew install swiftformat swiftlint xcodegen`.

O app de demonstração fica em [`.Examples/UAPPKitDemo`](.Examples/UAPPKitDemo/README.md),
em um diretório oculto para não aparecer na árvore da dependência local no
Xcode. Para gerar o projeto, entre nesse diretório e execute `xcodegen generate`.

Consulte [`AGENTS.md`](AGENTS.md) para as instruções de contribuição e
[`CHANGELOG.md`](CHANGELOG.md) para alterações por versão.
