# UAPPKit

SDK Swift para integrar aplicativos Apple ao UAPP: Feedback, Roadmap e
Changelog. **Nativo de ponta a ponta — sem WebView.** As telas são SwiftUI e
evoluem pelo próprio pacote; a API pública já está preparada para autenticação
assinada no backend, sem prender a implementação a uma versão web.

> Escopo desta versão: leitura paginada de conteúdo público, envio de feedback,
> votos, curtidas e comentários moderados através das Edge Functions públicas.

## Instalação (Swift Package Manager)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/renatoferraz/uapp", from: "0.1.0")
    // ou, durante o desenvolvimento:
    // .package(path: "../uapp/packages/UAPPKit")
]
```

Adicione `UAPPKit` como dependência do seu target.

Plataformas: iOS 16+, macOS 13+. Sem dependências externas.

## Uso

```swift
import UAPPKit

// No arranque do app:
UAPPKit.setup(projectId: "meu-app") // = public_slug configurado no UAPP

// Quando você souber quem é o usuário final (opcional):
UAPPKit.identify(userId: "user-123", email: "pessoa@exemplo.com")

// Abrir as telas nativas (iOS):
try UAPPKit.showFeedback()
try UAPPKit.showRoadmap()
try UAPPKit.showChangelog()

// Logout do usuário final:
UAPPKit.reset()
```

### Sem apresentação automática (ex.: macOS ou UI própria)

```swift
let client = try UAPPKit.makeClient()
let items = try await client.feedback()
let columns = try await client.roadmap()
let entries = try await client.changelog()
let id = try await client.submitFeedback(title: "Bug no login", body: "…")
try await client.setReaction(itemId: items[0].id, kind: .vote, enabled: true)
let comments = try await client.comments(itemId: items[0].id)
try await client.submitComment(itemId: items[0].id, body: "Também preciso")
```

Ou embuta as `View`s diretamente:

```swift
UAPPFeedbackScreen(client: try UAPPKit.makeClient(), mode: .roadmap)
```

## Identificação de usuários finais

`identify(userId:)` fornece os dados opcionais do autor. O backend associa as
ações a um `app_end_user` pela instalação UUID do SDK — entidade **separada**
de qualquer conta no painel. Nenhuma conta é criada.

Para identificação verificável (evitar spoofing de `userId`), gere um token no
seu backend e passe um `signatureProvider` no `setup`:

```swift
UAPPKit.setup(projectId: "meu-app") {
    try await minhaAPI.uappSignature() // string opaca gerada no servidor
}
```

O token vai no header `x-uapp-signature`. A verificação server-side é um passo
futuro; o contrato já está pronto.

## Segurança

- O pacote **não** contém segredos. Só o `projectId` público e o host.
- Todo tráfego vai para as Edge Functions públicas do UAPP (`/functions/v1/...`),
  que só devolvem conteúdo marcado como público e nunca dados internos.
- `submitFeedback` e `submitComment` criam itens pendentes; a moderação acontece no painel.
- Uma instalação UUID estável é criada por app e enviada com chaves de idempotência; nenhum segredo fica no pacote.

## Arquitetura

Veja [`docs/uappkit.md`](../../docs/uappkit.md) no repositório para o contrato
com o backend e as decisões de design.

## Testes

```bash
cd packages/UAPPKit
swift test
```
