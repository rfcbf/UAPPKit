# UAPPKit

SDK Swift para adicionar experiências nativas de Feedback, Roadmap e Changelog
do UAPP a aplicativos Apple. A interface usa SwiftUI e não incorpora conteúdo
em uma WebView.

O pacote oferece um cliente HTTP assíncrono para leitura de conteúdo público,
envio de feedback, reações e comentários. Não tem dependências externas.

## Requisitos

- Swift 5.9 ou posterior.
- iOS 16 ou posterior, incluindo iPadOS.
- macOS 13 ou posterior para usar o cliente e as views SwiftUI.

O pacote não declara suporte a watchOS, tvOS ou visionOS.

## Instalação pelo Swift Package Manager

No Xcode, escolha **File → Add Package Dependencies…** e informe:

```text
https://github.com/rfcbf/UAPPKit
```

Selecione a versão desejada e adicione o produto `UAPPKit` ao target do
aplicativo. Em outro `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rfcbf/UAPPKit", from: "0.1.0")
]
```

Em seguida, declare `UAPPKit` nas dependências do target consumidor.

## Configuração e telas nativas

```swift
import SwiftUI
import UAPPKit

@main
struct ExampleApp: App {
    init() {
        UAPPKit.setup(projectId: "meu-app")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

O `projectId` é o identificador público do projeto (`public_slug`) configurado
no UAPP. Em iOS, os métodos abaixo apresentam telas SwiftUI nativas a partir do
view controller ativo:

```swift
try UAPPKit.showFeedback()
try UAPPKit.showRoadmap()
try UAPPKit.showChangelog()
```

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

As páginas de feedback e comentários incluem `nextCursor` para paginação. As
reações disponíveis são voto e curtida. Comentários enviados entram em
moderação.

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
swift test
```

Consulte [`AGENTS.md`](AGENTS.md) para as instruções de contribuição e
[`CHANGELOG.md`](CHANGELOG.md) para alterações por versão.
