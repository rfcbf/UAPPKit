# UAPPKit

SDK Swift para adicionar telas nativas do UAPP a aplicativos Apple: Sobre,
Desenvolvedor, Changelog, Reviews, Feedback, Roadmap e Conta/Perfil. A
interface é SwiftUI, acompanha o tema e o idioma do aplicativo e não incorpora
conteúdo em WebView. No iPhone e no iPad as telas abrem em sheets; no Mac, em
janelas próprias, com barra de ferramentas, atalhos de teclado e lista ao lado
do detalhe.

<p align="center">
  <img src="Documentation/Images/feedback-light.png" width="230" alt="Tela de Feedback no modo claro">
  <img src="Documentation/Images/roadmap-light.png" width="230" alt="Tela de Roadmap no modo claro">
  <img src="Documentation/Images/changelog-dark.png" width="230" alt="Tela de Changelog no modo escuro">
</p>

## Sumário

- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Setup](#setup)
- [Telas prontas](#telas-prontas)
  - [Sobre](#sobre)
  - [Desenvolvedor](#desenvolvedor)
  - [Changelog](#changelog)
  - [Reviews](#reviews)
  - [Feedback](#feedback)
  - [Roadmap](#roadmap)
  - [Conta e Perfil](#conta-e-perfil)
- [Mac](#mac)
- [Autenticação](#autenticação)
- [Cliente para interface própria](#cliente-para-interface-própria)
- [Idioma e tradução](#idioma-e-tradução)
- [Tema](#tema)
- [Componentes auxiliares](#componentes-auxiliares)
- [Segurança e privacidade](#segurança-e-privacidade)
- [Documentação](#documentação)
- [Desenvolvimento](#desenvolvimento)

## Requisitos

- Swift 6.0 ou posterior.
- iOS 18 ou posterior, incluindo iPadOS.
- macOS 13 ou posterior. A barra de ferramentas das janelas abertas por
  `UAPPKit.show…` exige macOS 14; no macOS 13 a janela abre sem ela.

O pacote não declara suporte a watchOS, tvOS ou visionOS. No iOS, o recorte da
foto de perfil usa a biblioteca Mantis, resolvida automaticamente pelo Swift
Package Manager; no Mac o recorte é próprio do pacote, sem dependências.

## Instalação

No Xcode, escolha **File → Add Package Dependencies…** e informe:

```text
https://github.com/rfcbf/UAPPKit
```

Selecione a versão `2.4.0` ou posterior e adicione o produto `UAPPKit` ao
target do aplicativo. Em outro `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rfcbf/UAPPKit", from: "2.4.0")
],
targets: [
    .target(name: "MeuApp", dependencies: ["UAPPKit"])
]
```

A tag da versão é publicada automaticamente após o merge e a CI da `main` concluir.

## Setup

Chame `UAPPKit.setup` uma vez, na inicialização do aplicativo:

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

Todos os parâmetros além de `projectId` são opcionais:

```swift
UAPPKit.setup(
    projectId: "meu-app",
    theme: .system,
    signatureProvider: nil,
    locale: Locale(identifier: "pt-BR")
)
```

| Parâmetro | Padrão | Descrição |
| --- | --- | --- |
| `projectId` | obrigatório | Identificador público do projeto (`public_slug`) configurado no UAPP. |
| `theme` | `.system` | Paleta das telas do kit. Veja [Tema](#tema). |
| `signatureProvider` | `nil` | Closure assíncrona que retorna uma assinatura emitida pelo seu servidor. |
| `locale` | idioma do app/sistema | Idioma inicial das telas. Veja [Idioma e tradução](#idioma-e-tradução). |

O kit acessa sempre o servidor de produção do UAPP; o aplicativo não escolhe
servidor. O setup não inicia login nem acessa a autenticação. Antes dele, as APIs do kit
lançam `UAPPKitError.notConfigured`.

## Telas prontas

Os métodos `UAPPKit.show…` apresentam a tela pronta: no iPhone e no iPad, como
sheet a partir do view controller ativo; no Mac, em uma janela própria (veja
[Mac](#mac)). Para usar a navegação do próprio aplicativo, incorpore a view
SwiftUI correspondente.

| Tela | Apresentação pelo kit | View SwiftUI |
| --- | --- | --- |
| Sobre | `UAPPKit.showAbout(configuration:)` | `UAPPAboutScreen` |
| Desenvolvedor | `UAPPKit.showDeveloperAbout()` | `UAPPDeveloperAboutScreen` |
| Changelog | `UAPPKit.showChangelog(configuration:)` | `UAPPFeedbackScreen(mode: .changelog)` |
| Reviews | `UAPPKit.showReviews(pageSize:)` | `UAPPReviewsScreen` |
| Feedback | `UAPPKit.showFeedback()` | `UAPPFeedbackScreen(mode: .feedback)` |
| Roadmap | `UAPPKit.showRoadmap()` | `UAPPRoadmapScreen` |
| Conta | `UAPPKit.showAuthentication(authentication:)` | `UAPPAccountScreen` |
| Perfil | `UAPPKit.showUser(session:authentication:)` | `UAPPUserScreen` |

Sobre, Desenvolvedor, Changelog e Reviews são públicas e não usam sessão.
Feedback e Roadmap pedem login somente quando a pessoa participa.

### Sobre

<p>
  <img src="Documentation/Images/about-light.png" width="260" alt="Tela Sobre no modo claro">
  <img src="Documentation/Images/about-dark.png" width="260" alt="Tela Sobre no modo escuro">
</p>

Apresenta o aplicativo hospedeiro: ícone, nome e versão são descobertos
automaticamente. Logo abaixo da versão do aplicativo, a tela mostra a versão do
UAPPKit em uso (`UAPPKit.version`). Descrição, links institucionais e licença são parâmetros.

```swift
try UAPPKit.showAbout(configuration: UAPPAboutConfiguration(
    shortDescription: "Uma descrição curta do aplicativo",
    descriptionLanguageIdentifier: "pt-BR",
    websiteURL: URL(string: "https://exemplo.com"),
    supportURL: URL(string: "mailto:suporte@exemplo.com"),
    privacyPolicyURL: URL(string: "https://exemplo.com/privacidade"),
    termsOfUseURL: URL(string: "https://exemplo.com/termos"),
    license: "MIT",
    showsChangelog: true,
    showsAppStoreReview: true,
    changelogConfiguration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10),
    showsReviews: true,
    reviewsPageSize: 10
))
```

- `showsChangelog: true` adiciona a ação que abre o Changelog do projeto,
  usando `changelogConfiguration`.
- `shortDescription` é a descrição exibida abaixo do nome e aceita Markdown.
  Quando o projeto tem uma descrição do aplicativo configurada em Sobre no
  UAPP, ela tem precedência e pode ser alterada sem publicar uma nova versão.
  A descrição é traduzida para o idioma de apresentação.
- `showsAppStoreReview: true` adiciona a ação para avaliar o app na App Store.
- `showsReviews: true` adiciona a ação que abre a lista de avaliações do
  aplicativo em uma sheet sobre a tela Sobre, com páginas de `reviewsPageSize`.
- A linha Suporte abre `supportURL`. Quando o projeto tem um e-mail de suporte
  configurado em Sobre no UAPP, ele tem precedência e a linha abre uma mensagem
  para esse endereço, sem precisar publicar uma nova versão do aplicativo.
  A pessoa escolhe o motivo (dúvida, problema ou sugestão) em uma folha
  inferior e a mensagem abre com o assunto `[Nome do app] [Motivo] - ` e, no corpo, a versão e o build do
  aplicativo, o sistema, o modelo do aparelho e o idioma. Se o aparelho não
  tiver um app de e-mail configurado, um aviso mostra o endereço.
- A descrição é traduzida sob demanda para o idioma escolhido na tela quando a
  Translation framework está disponível; caso contrário, o original é mantido.

Para abrir a avaliação na App Store a partir da sua própria interface, por
exemplo em uma linha "Avaliar o app" dos ajustes:

```swift
Task {
    try? await UAPPKit.openAppStoreReview()
}
```

### Desenvolvedor

<p>
  <img src="Documentation/Images/developer-light.png" width="260" alt="Tela Desenvolvedor no modo claro">
  <img src="Documentation/Images/developer-dark.png" width="260" alt="Tela Desenvolvedor no modo escuro">
</p>

Mostra o perfil público do desenvolvedor, outros aplicativos e redes sociais
configurados no UAPP. É uma tela separada do Sobre do aplicativo. A biografia
aceita formatação Markdown: negrito, itálico, títulos e listas.

```swift
try UAPPKit.showDeveloperAbout()

// Ou na navegação do aplicativo:
UAPPDeveloperAboutScreen(client: try UAPPKit.makeClient())
```

Migração: chamadas antigas a `UAPPAboutScreen(client:)` devem usar
`UAPPDeveloperAboutScreen(client:)`. `UAPPAboutScreen` representa
exclusivamente o aplicativo hospedeiro.

### Changelog

<p>
  <img src="Documentation/Images/changelog-light.png" width="260" alt="Tela de Changelog no modo claro">
  <img src="Documentation/Images/changelog-dark.png" width="260" alt="Tela de Changelog no modo escuro">
</p>

Lista as versões publicadas, com imagens por item, carrossel com reprodução
automática opcional, pesquisa nas versões carregadas e detalhes completos.

```swift
try UAPPKit.showChangelog()

try UAPPKit.showChangelog(
    configuration: UAPPChangelogConfiguration(
        automaticallyScrolls: true,
        interval: 5,
        pageSize: 10
    )
)

// Ou na navegação do aplicativo:
NavigationStack {
    UAPPFeedbackScreen(
        client: try UAPPKit.makeClient(),
        mode: .changelog,
        changelogConfiguration: .init(pageSize: 20)
    )
}
```

`pageSize` é ajustado à faixa de 1 a 50 aceita pela API. Sem configuração, a
reprodução é manual. Veja [configuração e compatibilidade](Documentation/Changelog.md).

### Reviews

<p>
  <img src="Documentation/Images/reviews-light.png" width="260" alt="Tela de Reviews no modo claro">
  <img src="Documentation/Images/reviews-dark.png" width="260" alt="Tela de Reviews no modo escuro">
</p>

Apresenta as avaliações da App Store sincronizadas e tornadas públicas no
UAPP, com paginação conforme a rolagem e respostas do desenvolvedor
expansíveis. No topo, um cartão resume a média, as estrelas, o total e a
distribuição por nota.

O resumo vem do servidor (`UAPPReviewsPage.summary`). Quando ele não é
informado, o pacote lê as notas em uma página de até 50 avaliações e mostra o
cartão se ela trouxer todas; acima disso, o cartão fica oculto.

```swift
try UAPPKit.showReviews(pageSize: 20)

// Ou na navegação do aplicativo:
UAPPReviewsScreen(client: try UAPPKit.makeClient(), pageSize: 20)
```

`pageSize` é obrigatório e ajustado à faixa de 1 a 50. No iOS 18+ e macOS 15+,
título, texto e resposta são traduzidos para o idioma escolhido; se a tradução
falhar, o conteúdo original é preservado. Veja o
[contrato de reviews](Documentation/Reviews.md).

### Feedback

<p>
  <img src="Documentation/Images/feedback-light.png" width="260" alt="Tela de Feedback no modo claro">
  <img src="Documentation/Images/feedback-dark.png" width="260" alt="Tela de Feedback no modo escuro">
  <img src="Documentation/Images/feedback-detail-light.png" width="260" alt="Detalhe de um feedback no modo claro">
</p>

Lista os feedbacks públicos e permite enviar sugestões, votar e comentar. O
detalhe mostra autor e data, descrição completa, status, votantes e a conversa
com respostas e reações. Feedbacks e comentários aceitam imagens, e a conversa
é atualizada enquanto a tela está ativa.

Quando a equipe define uma prioridade para o item no UAPP, o card mostra um
selo com o nível: baixa, média, grande, muito grande, importante ou urgente.
Itens sem prioridade não mostram o selo. As etiquetas aplicadas pela equipe
aparecem como selos somente leitura, na cor de cada etiqueta, no card e no
detalhe, onde a prioridade também é exibida. Os dados ficam em
`UAPPFeedbackItem.tags` (`UAPPFeedbackTag` com `id`, `name` e `color`); com
servidores que ainda não enviam etiquetas, a lista fica vazia. Para usar o
mesmo selo de prioridade em uma tela própria:

```swift
if let priority = UAPPFeedbackPriority(value: item.priority) {
    UAPPFeedbackPriorityBadge(priority: priority)
}
```

```swift
try UAPPKit.showFeedback()

// Ou na navegação do aplicativo:
NavigationStack {
    UAPPFeedbackScreen(client: try UAPPKit.makeParticipationClient(), mode: .feedback)
}
```

No Mac, a tela já monta a lista ao lado do detalhe. Ao incorporá-la, coloque-a
direto na janela, sem envolvê-la em `NavigationStack`.

Sem nenhuma configuração adicional, o kit oferece login por código enviado
por e-mail apenas no momento de participar. Para reutilizar a conta do
aplicativo, veja [Autenticação](#autenticação) e
[Feedback e autenticação](Documentation/Feedback.md).

### Roadmap

<p>
  <img src="Documentation/Images/roadmap-light.png" width="260" alt="Tela de Roadmap no modo claro">
  <img src="Documentation/Images/roadmap-dark.png" width="260" alt="Tela de Roadmap no modo escuro">
</p>

Organiza os itens públicos por status, com os mesmos detalhes, votos,
comentários, selo de prioridade e etiquetas do Feedback. No Mac, aparece em
quadro, com uma coluna por status lado a lado, e o item escolhido abre em um
painel à direita.

```swift
try UAPPKit.showRoadmap()

// Ou na navegação do aplicativo (no Mac, sem o NavigationStack):
NavigationStack {
    UAPPRoadmapScreen(client: try UAPPKit.makeParticipationClient())
}
```

`UAPPFeedbackScreen(client:mode: .roadmap)` continua disponível e apresenta a
mesma `UAPPRoadmapScreen`.

### Conta e Perfil

<p>
  <img src="Documentation/Images/account-light.png" width="260" alt="Tela de Conta no modo claro">
  <img src="Documentation/Images/account-dark.png" width="260" alt="Tela de Conta no modo escuro">
</p>

`UAPPAccountScreen` reúne login por e-mail e senha, Google, Apple e GitHub,
criação de conta com confirmação de e-mail e recuperação de senha, com o ícone
e o tema do aplicativo.

```swift
let authentication = try UAPPKit.makeAuthentication(
    callbackURL: URL(string: "meuapp://authentication")!
)

try UAPPKit.showAuthentication(authentication: authentication) { session in
    // `session` é nil quando a pessoa sai da conta.
    accountModel.session = session
}
```

Em SwiftUI:

```swift
.sheet(isPresented: $showsAccount) {
    UAPPAccountScreen(
        authentication: authentication,
        client: try? UAPPKit.makeClient(),
        minimumPasswordLength: 8,
        termsURL: URL(string: "https://exemplo.com/termos"),
        privacyURL: URL(string: "https://exemplo.com/privacidade"),
        onSessionChange: { accountModel.session = $0 }
    )
}
```

<p>
  <img src="Documentation/Images/profile-light.png" width="260" alt="Tela de Perfil no modo claro">
  <img src="Documentation/Images/profile-dark.png" width="260" alt="Tela de Perfil no modo escuro">
</p>

`UAPPUserScreen` mostra foto, nome e e-mail da conta conectada, a ação de
sair e o histórico de participação em todos os aplicativos vinculados ao mesmo
usuário. Com `onEditProfile`, a barra de navegação oferece o botão de editar perfil,
entre sair e o idioma, que abre o editor do próprio aplicativo.
Com o provedor do kit, a tela termina com **Excluir conta**: um alerta destrutivo
explica o que será apagado, o servidor exclui a conta, o kit limpa a sessão e o
`onSessionChange` recebe `nil`. Veja [excluir conta](Documentation/Authentication.md#excluir-conta).

```swift
try UAPPKit.showUser(
    session: session,
    authentication: authentication,
    onSessionChange: { accountModel.session = $0 }
)

// Ou em uma sheet do aplicativo:
UAPPUserScreen(
    session: session,
    authentication: authentication,
    client: try? UAPPKit.makeClient(),
    onSessionChange: { accountModel.session = $0 }
)
```

Veja [conta e participação global](Documentation/UserActivity.md) e
[fotos de perfil](Documentation/ProfilePhotos.md).

## Mac

As mesmas APIs funcionam no Mac, com telas pensadas para a plataforma e não
uma adaptação da tela do iPad:

<p align="center">
  <img src="Documentation/Images/mac-feedback-light.png" width="760" alt="Feedback no Mac, com a lista à esquerda e o detalhe à direita, no modo claro">
</p>

- **Janelas próprias.** Cada `UAPPKit.show…` abre a tela em uma janela do Mac,
  com título, barra de ferramentas e botão de fechar do sistema, centralizada
  no monitor. Chamar de novo traz a mesma janela para a frente. Conta e Perfil abrem em janelas estreitas e fecham sozinhas depois
  do login ou de sair da conta.
- **Lista e detalhe lado a lado.** No Feedback, como no Mail, a lista fica à
  esquerda e o item escolhido, à direita; o divisor é arrastável e a largura da
  lista é lembrada. Cada linha mostra autor (foto ou iniciais) e data, título,
  descrição, status, prioridade, comentários e o voto, que fica cheio na cor
  de destaque quando é da pessoa.
- **Roadmap em quadro.** Uma coluna por status, lado a lado, com a quantidade
  de itens; o item escolhido abre em um painel à direita (macOS 14+) ou em
  uma sheet (macOS 13).
- **Barra de ferramentas e teclado.** Uma barra única sobre a janela, com os
  ícones na cor do sistema: busca sempre visível, Atualizar com ⌘R, Enviar
  feedback com ⌘N, idioma em um menu com a marca no idioma atual e conta pelo
  avatar. Os botões aparecem quando a cor do projeto já foi carregada. A
  janela usa o próprio botão de fechar; sheets têm "Fechar" com Esc, e o envio
  de feedback usa o botão padrão com ⌘↩.
- **Conta.** Abre direto no login; um link no rodapé alterna entre login e
  cadastro, sem tela de boas-vindas nem botão de voltar.
- **Foto de perfil.** O seletor oferece o app Fotos e arquivos do Finder, com
  recorte circular ajustável por arrasto e zoom. A câmera não é oferecida no Mac.

<p align="center">
  <img src="Documentation/Images/mac-roadmap-dark.png" width="540" alt="Roadmap no Mac em quadro, com uma coluna por status, no modo escuro">
  <img src="Documentation/Images/mac-account-light.png" width="196" alt="Conta no Mac, aberta no login, no modo claro">
</p>

### Menu Ajuda

`UAPPKitCommands` coloca as telas do kit no fim do menu Ajuda da barra de
menus. Com `aboutConfiguration`, o item "Sobre" do menu do aplicativo passa a
abrir a tela Sobre do kit no lugar do painel padrão:

```swift
@main
struct ExampleApp: App {
    init() {
        UAPPKit.setup(projectId: "meu-app")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            UAPPKitCommands(
                items: [.feedback, .roadmap, .changelog, .rateOnAppStore],
                aboutConfiguration: UAPPAboutConfiguration(showsChangelog: true)
            )
        }
    }
}
```

Os itens disponíveis são `.feedback`, `.roadmap`, `.changelog`, `.reviews`,
`.rateOnAppStore` e `.developerAbout`. Os mesmos comandos aparecem no menu do
iPad com teclado.

### Sandbox do aplicativo

Em um app Mac com App Sandbox, ative **Outgoing Connections (Client)** para o
kit acessar o UAPP e **User Selected File → Read Only** para escolher a foto de
perfil em um arquivo do Finder. O login com Google, Apple ou GitHub retorna ao
aplicativo pelo esquema de URL configurado no target, como no iOS.

## Autenticação

Somente Feedback, Roadmap, Conta e Perfil usam sessão. Há três formas de
integrar, da mais simples à mais controlada.

### 1. Automática

Nada a configurar. `UAPPKit.showFeedback()`, `UAPPKit.showRoadmap()` e
`UAPPKit.makeParticipationClient()` oferecem login por código enviado por
e-mail somente quando a pessoa vota, comenta ou envia um feedback. A sessão
fica no Keychain do aplicativo.

### 2. Provedor do kit

Use quando o aplicativo quer uma conta visível, com Apple, Google, GitHub e
e-mail. Crie o provedor depois do setup e mantenha a mesma instância na camada
de conta:

```swift
let authentication = try UAPPKit.makeAuthentication(
    methods: [.apple, .google, .email]
)

// Ao abrir o aplicativo, restaure a sessão salva.
let session = try await authentication.currentSession()

// Reutilize a conta em Feedback e Roadmap.
try await UAPPKit.showFeedback(authentication: authentication)
try await UAPPKit.showRoadmap(authentication: authentication)

// Sair pela interface do aplicativo.
try await authentication.signOut()
```

O provedor salva perfil, tokens e expiração no Keychain, separados por
servidor e projeto, e renova tokens expirados. Senhas não são armazenadas.
`currentSession()` é assíncrona: aguarde a restauração antes de decidir entre
mostrar a conta ou a opção de login. Uma falha temporária de rede não apaga a
sessão salva.

O login com Google, Apple e GitHub volta ao aplicativo pelo endereço único
`UAPPAuthentication.defaultCallbackURL` (`uappkit://authentication`), o mesmo
para todos os aplicativos. Não é preciso registrar esquema em **URL Types** nem
pedir a habilitação de um endereço próprio: o retorno é capturado pela própria
sessão de login (`ASWebAuthenticationSession`), então aplicativos diferentes não
entram em conflito, e o código devolvido só pode ser trocado por sessão com o
verificador PKCE guardado pelo aplicativo que iniciou o login.

`callbackURL` continua aceitando um endereço próprio, mas ele só funciona se
também for habilitado no serviço de autenticação. Prefira o padrão.

### 3. `UAPPAuthenticationProvider` próprio

Use quando o aplicativo já tem login e sessão. Implemente o protocolo como um
adaptador da sua camada de conta. Apenas quatro membros são obrigatórios; os
demais têm implementação padrão que lança
`UAPPAuthenticationError.unsupportedMethod`.

```swift
struct AppAuthentication: UAPPAuthenticationProvider {
    let account: AccountService

    var methods: [UAPPLoginMethod] { [.email] }

    func currentSession() async throws -> UAPPAuthenticationSession? {
        guard let user = await account.currentUser() else { return nil }
        return UAPPAuthenticationSession(
            identity: UAPPIdentity(
                userId: user.id,
                email: user.email,
                displayName: user.name
            ),
            accessToken: try await account.accessToken()
        )
    }

    func signIn(method: UAPPLoginMethod) async throws -> UAPPAuthenticationSession {
        try await account.presentLogin()
        guard let session = try await currentSession() else {
            throw UAPPAuthenticationError.cancelled
        }
        return session
    }

    func signOut() async throws {
        try await account.signOut()
    }
}

try await UAPPKit.showFeedback(authentication: AppAuthentication(account: account))
```

Com um provedor próprio, persistência e restauração da sessão são
responsabilidade dele. O backend valida o token em cada operação.

Se o aplicativo só precisa fornecer um token, sem fluxo de login pelo kit:

```swift
try await UAPPKit.showFeedback(
    identity: UAPPIdentity(userId: "user-123", displayName: "Pessoa"),
    accessTokenProvider: { try await account.accessToken() }
)
```

### Identidade opcional

`identify` associa ações a um usuário final informado pelo aplicativo. Não
cria nem autentica uma conta.

```swift
UAPPKit.identify(
    userId: "user-123",
    email: "pessoa@example.com",
    displayName: "Pessoa"
)

// Ao encerrar a sessão do usuário:
UAPPKit.reset()
```

`signatureProvider`, no setup, envia uma assinatura obtida no seu servidor no
header `x-uapp-signature`. O backend atual ainda não valida esse valor;
portanto, ele não deve ser tratado como controle de autorização ativo.

Fluxos completos e limitações em
[Autenticação reutilizável](Documentation/Authentication.md) e
[Feedback e autenticação](Documentation/Feedback.md).

## Cliente para interface própria

`UAPPClient` é um `actor` com métodos assíncronos, para montar a interface do
próprio aplicativo sem as telas do kit.

```swift
let client = try UAPPKit.makeClient()

// Leitura
let feedbackPage = try await client.feedbackPage(limit: 20)
let nextPage = try await client.feedbackPage(limit: 20, cursor: feedbackPage.nextCursor)
let columns = try await client.roadmap()
let entries = try await client.changelog()
let releases = try await client.changelogPage(
    limit: 20,
    filters: UAPPChangelogFilters(
        category: .security,
        platform: .ios,
        from: "2026-01-01",
        to: "2026-12-31"
    )
)
let comments = try await client.comments(itemId: "feedback-id")
```

Para escrever, use um cliente com participação: o automático
(`makeParticipationClient()`) ou um criado com a sua autenticação.

```swift
let client = try await UAPPKit.makeClient(authentication: authentication)

let submittedId = try await client.submitFeedback(
    title: "Melhorar o fluxo de login",
    body: "Seria útil manter a sessão ativa.",
    category: .improvement
)

try await client.setReaction(itemId: "feedback-id", kind: .vote, enabled: true)

try await client.submitComment(
    itemId: "feedback-id",
    body: "Também seria útil para mim."
)

let activity = try await client.userActivity(session: session, limit: 20)
```

Para abrir o envio nativo já preenchido, sem passar pela lista de Feedback,
apresente `UAPPFeedbackComposerScreen` com um `UAPPFeedbackDraft`:

```swift
.sheet(isPresented: $isReporting) {
    UAPPFeedbackComposerScreen(
        client: client,
        draft: UAPPFeedbackDraft(
            title: "Falha ao sincronizar",
            details: "A sincronização parou na segunda etapa.",
            category: .bug
        )
    ) {
        isReporting = false
    }
}
```

Com `isCategoryLocked: true`, o compositor mostra só o tipo do rascunho e a
pessoa não consegue trocá-lo, por exemplo para uma requisição aberta a partir
de um erro chegar sempre como `bug`.

Quando o aplicativo envia a requisição pelo próprio backend, use o mesmo
compositor sem `client`, informando `submit`. Ele recebe um
`UAPPFeedbackSubmission` (título e descrição sem espaços nas pontas, tipo e
anexos compactados). Se `submit` lançar um erro, o compositor continua aberto
e mostra o aviso de falha, com o texto de `LocalizedError.errorDescription`
quando houver; `onComplete` só é chamado depois de um envio sem erro:

```swift
UAPPFeedbackComposerScreen(
    draft: UAPPFeedbackDraft(category: .feature),
    submit: { submission in
        try await backend.sendRequest(
            title: submission.title,
            details: submission.details,
            category: submission.category.rawValue,
            images: submission.imagesData
        )
    }
) {
    isReporting = false
}
```

- Páginas de feedback, comentários e changelog incluem `nextCursor`.
- `submitFeedback` e `submitComment` aceitam `imagesData:` com até duas
  imagens compactadas, de no máximo 512 KiB cada.
- Reações valem para feedbacks e, com `commentId:`, para comentários.
- Comentários enviados entram em moderação.
- Erros chegam como `UAPPKitError` (`notConfigured`, `http`, `invalidResponse`,
  `transport`) ou `UAPPAuthenticationError`.

O transporte é injetável. O padrão, `URLSessionTransport`, cancela a
requisição se a resposta não chegar em 15 segundos; o prazo pode ser ajustado
com `URLSessionTransport(session:timeoutInterval:)`. Para testes ou rede
própria, implemente `UAPPTransport`:

```swift
let client = UAPPClient(
    configuration: UAPPConfiguration(projectId: "meu-app"),
    transport: MeuTransporte()
)
```

## Idioma e tradução

<p>
  <img src="Documentation/Images/language-picker-light.png" width="260" alt="Seletor de idioma de uma tela do kit">
</p>

Os textos do kit ficam em um String Catalog e começam no idioma do aplicativo
hospedeiro. Sem um idioma informado, o SDK usa o idioma do sistema e volta
para Português (Brasil) quando ele não está disponível.

```swift
// Idioma inicial explícito.
UAPPKit.setup(projectId: "meu-app", locale: Locale(identifier: "en"))

// Alterar depois, por exemplo a partir dos ajustes do aplicativo.
UAPPKit.setLocale(Locale(identifier: "de"))

// Idiomas disponíveis, para montar um seletor próprio.
let languages = UAPPLanguage.supported
```

Idiomas disponíveis: Português (Brasil), Inglês, Alemão, Francês, Espanhol,
Japonês, Chinês Simplificado, Chinês Tradicional, Polonês, Hindi, Vietnamita,
Italiano e Coreano.

Todas as telas exibem um seletor próprio de idioma. Cada apresentação começa
no idioma do aplicativo, e uma troca feita dentro da tela vale apenas para
aquela apresentação, sem alterar o aplicativo por trás.
`UAPPKit.localePreferenceKey` é a chave de `UserDefaults` que uma tela própria
pode observar para acompanhar a seleção persistida.

O conteúdo vindo do serviço (descrição do Sobre, changelog, reviews e
feedbacks) é traduzido no dispositivo com a Translation framework da Apple
quando disponível (iOS 18+ e macOS 15+). Se a tradução não estiver disponível
ou falhar, o texto original é mantido.

## Tema

O tema é definido uma vez no setup e vale para todas as telas.

- **Sistema** (`.system`, padrão): cores semânticas da Apple, acompanhando
  automaticamente os modos claro e escuro.
- **Personalizado**: paletas independentes para claro e escuro. Cores omitidas
  continuam usando os valores dinâmicos do sistema.

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
`secondaryText`, `accent`, `buttonText` e `separator`. `buttonText` controla o
texto em botões preenchidos e, por padrão, é branco. Sem `accent`, o kit usa a
cor pública configurada para o aplicativo no UAPP e, antes de recebê-la, a cor
de destaque do sistema.

O kit não tem um parâmetro para fixar claro ou escuro: as telas acompanham a
aparência ativa. Para fixar um modo em uma view incorporada, use o modificador
do SwiftUI:

```swift
UAPPReviewsScreen(client: client, pageSize: 20)
    .preferredColorScheme(.dark)
```

## Componentes auxiliares

### Imagens com cache

As telas do kit compartilham um cache de imagens remotas, que também pode ser
usado pelo aplicativo:

```swift
UAPPCachedImage(url: avatarURL) { phase in
    if let image = phase.image {
        image.resizable().scaledToFill()
    } else if avatarURL == nil || phase.error != nil {
        Image(systemName: "person.crop.circle.fill")
            .resizable().scaledToFit()
    } else {
        UAPPImageLoadingPlaceholder()
    }
}
.frame(width: 64, height: 64)
.clipShape(Circle())
```

O cache em memória tem limite de 32 MB e 100 entradas, com validade de até
cinco minutos, respeitando `Cache-Control` e `Age`. O cache HTTP em disco tem
limite de 64 MB. Requisições simultâneas da mesma URL compartilham o download;
imagens são decodificadas em até 2048 pixels e respostas acima de 10 MB são
rejeitadas. `UAPPImageCache.removeAll()`, na main actor, limpa memória e disco
e cancela downloads pendentes.

### Foto de perfil

No iOS, `UAPPProfilePhotoPicker(photo: $photo)` permite escolher uma imagem da
biblioteca ou da câmera, ajustar o recorte circular e receber um JPEG
comprimido de até 512 pixels. No Mac, a mesma view oferece o app Fotos e um
arquivo do Finder, com o recorte circular nativo do pacote (arrastar para
posicionar e controle de zoom); o resultado é o mesmo JPEG.

A câmera exige `NSCameraUsageDescription` no Info.plist **do aplicativo**; o
pacote não adiciona essa chave. No Xcode, selecione o target do aplicativo,
abra **Info** e adicione **Privacy - Camera Usage Description**, ou edite o
Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>A câmera permite tirar uma foto para o seu perfil.</string>
```

Sem essa descrição, o seletor informa que a câmera está indisponível. A
biblioteca usa `PhotosPicker` e não exige `NSPhotoLibraryUsageDescription`.
No Mac não há câmera no seletor, e a chave não é necessária.
Veja [uso e configuração](Documentation/ProfilePhotos.md).

Para encaixar só o avatar editável em um formulário próprio, sem o texto de
apoio, informe a foto já gravada e, se quiser, a ação de remover:

```swift
UAPPProfilePhotoPicker(
    photo: $photo,
    remoteURL: currentPhotoURL,
    size: 104,
    onRemove: { currentPhotoURL = nil }
)
```

O avatar mostra `remoteURL` enquanto não há foto escolhida. Com `onRemove`, o
menu oferece remover: a foto escolhida é descartada e a ação é chamada para o
aplicativo limpar a foto gravada.

### Redes sociais

`UAPPSocialNetworkIcon("instagram")` mostra a marca de uma das redes aceitas no
perfil do desenvolvedor: `youtube`, `x`, `instagram`, `tiktok`, `linkedin` e
`facebook`. Outros nomes mostram um símbolo de link.

```swift
UAPPSocialNetworkIcon("youtube")
    .frame(width: 24, height: 24)
```

### Listas próprias

Para montar uma lista própria com o mesmo comportamento das telas do pacote:

- `UAPPTranslatedText("texto")` mostra o texto traduzido para o idioma de
  apresentação escolhido; sem tradução disponível, mostra o original.
- `UAPPLanguageMenuButton()` é o botão de globo que troca esse idioma.
- `.uappTranslationScope()` mantém as traduções da tela e aplica o idioma.
- `.uappSearchField(text:isPresented:prompt:accentColor:)` abre a busca por
  botão, na barra de ferramentas a partir do iOS 26.
- `UAPPImageAttachmentPicker(data:isProcessing:)` escolhe até duas imagens,
  preparadas em JPEG de até 512 KB, e `UAPPImageAttachmentGallery(urls:)`
  mostra miniaturas que abrem em tela cheia.
- `UAPPRequestStatusTitle.localized(key:fallback:languageIdentifier:)` devolve
  o nome de uma etapa padrão no idioma informado.

### Efeito de voto

`.uappVoteBurst(isSelected:tint:)` solta joinhas subindo de um botão de voto
quando a pessoa vota e joinhas para baixo, descendo, quando ela retira o voto.
No iOS o efeito é desenhado por cima da janela, então não é cortado pela célula
nem pelo cartão em que o botão está. As telas de Feedback do kit já usam o
efeito; aplique em botões próprios:

```swift
Button { toggleVote() } label: {
    Label(voteCount.formatted(), systemImage: "arrow.up.circle")
}
.uappVoteBurst(isSelected: viewerVoted, tint: .orange)
```

O efeito só aparece depois de um toque no botão: o estado que chega ao carregar
a tela não anima. Sem `tint`, usa a cor de destaque do ambiente. Com Reduzir
Movimento ligado, nada é animado. Exige iOS 17 ou macOS 14; em sistemas
anteriores o botão fica como está.

## Segurança e privacidade

- `projectId` identifica o projeto e não é segredo.
- Não coloque chaves administrativas, segredos de backend, tokens APNs ou
  credenciais Apple no aplicativo.
- As operações usam endpoints públicos do UAPP, que retornam somente conteúdo
  público. O backend aplica publicação, visibilidade, moderação e limites de
  envio.
- O SDK cria e persiste um UUID de instalação por projeto em `UserDefaults`
  para identificar reações e dar suporte a chaves de idempotência.
- Sessões ficam no Keychain do aplicativo; senhas não são armazenadas.
- `identify` envia os dados opcionais informados pelo aplicativo em ações de
  feedback. Use-o conforme a política de privacidade e o consentimento do seu
  aplicativo.

## Documentação

| Documento | Conteúdo |
| --- | --- |
| [Architecture.md](Documentation/Architecture.md) | Arquitetura do pacote e contrato HTTP. |
| [Authentication.md](Documentation/Authentication.md) | Conta, login, cadastro e persistência da sessão. |
| [Feedback.md](Documentation/Feedback.md) | Feedback, Roadmap e participação autenticada. |
| [Changelog.md](Documentation/Changelog.md) | Configuração e compatibilidade do Changelog. |
| [Reviews.md](Documentation/Reviews.md) | Contrato e paginação das avaliações. |
| [UserActivity.md](Documentation/UserActivity.md) | Perfil e participação global da conta. |
| [ProfilePhotos.md](Documentation/ProfilePhotos.md) | Seleção, recorte e envio da foto de perfil. |
| [Decisions.md](Documentation/Decisions.md) | Decisões de projeto. |
| [Roadmap.md](Documentation/Roadmap.md) | Checklist de implementação das telas. |
| [CHANGELOG.md](CHANGELOG.md) | Alterações por versão. |

## Desenvolvimento

```sh
swift package dump-package
swift build
swift build -c release
swift test
swiftformat . --lint
swiftlint lint --strict
```

As ferramentas podem ser instaladas com
`brew install swiftformat swiftlint xcodegen`.

O app de demonstração fica em [`.Examples/UAPPKitDemo`](.Examples/UAPPKitDemo/README.md),
em um diretório oculto para não aparecer na árvore da dependência local no
Xcode. Para gerar o projeto, entre nesse diretório e execute
`xcodegen generate`. O projeto tem dois apps: `UAPPKitDemo` (iPhone e iPad) e
`UAPPKitDemoMac` (Mac, macOS 14+), cada um com o próprio scheme.

As capturas de tela deste README ficam em
[`Documentation/Images`](Documentation/Images/README.md). Consulte
[`AGENTS.md`](AGENTS.md) para as instruções de contribuição.
