# Feedback, Roadmap e autenticação

Feedback, Roadmap, detalhes e participação no perfil acompanham mudanças públicas
por um canal Realtime do aplicativo. Novos feedbacks, exclusões, status, comentários
e votação geram avisos sem dados de contas. As telas e os contadores são relidos
pela API pública, respeitando a moderação. Os filtros e as páginas do perfil já
carregadas são preservados. A conexão fecha ao sair da tela ou
colocar o app em segundo plano, reconecta ao retornar e mantém a consulta
periódica de 15 segundos como reserva. A integração usa WebSocket nativo, sem
adicionar uma dependência Supabase ao pacote ou liberar acesso direto às tabelas.

O setup configura o projeto na inicialização. A autenticação entra posteriormente,
ao abrir Feedback ou Roadmap. Sobre, Changelog e Reviews continuam públicos e
não consultam a sessão.

## Começar pelo fluxo simples

```swift
UAPPKit.setup(projectId: "meu-app")
try UAPPKit.showFeedback()
try UAPPKit.showRoadmap()
```

As chamadas simples incluem login automático por e-mail com código. O usuário
consulta o conteúdo livremente; ao enviar, votar ou comentar, informa seu e-mail
e o código recebido, sem sair do app. Feedback e Roadmap compartilham a conta.
O kit oferece esse fluxo sem pedir chave, provider ou callback de autenticação.
O Demo também demonstra a integração com uma conta do aplicativo: na tela
principal é possível conectar e-mail e senha, Google, Apple ou GitHub, ou preencher um
perfil local sem autenticação. Ele passa o mesmo provedor às duas telas para
reutilizar a sessão. A foto escolhida no Demo fica no aparelho; nome e e-mail
do perfil local não substituem autenticação validada.

A configuração pública é descoberta somente ao solicitar código. Setup e
navegação pública não iniciam autenticação. Para SwiftUI próprio, use
`UAPPKit.makeParticipationClient()`. `makeClient()` continua sendo o cliente
público de baixo nível, preservando integrações existentes.

As opções abaixo são para aplicativos com login próprio ou que desejam
personalizar os provedores. Não são necessárias no fluxo padrão.

## Interface e sessão do aplicativo

Feedback e Roadmap compartilham tema, idioma, fechar e pesquisa com as outras
telas. A busca local ignora caixa/acentos e pesquisa título/descrição; no
Roadmap também pesquisa o status. Formulários e detalhes recebem tema e idioma.

As descrições na lista de feedback ocupam no máximo três linhas; os detalhes
mantêm o texto completo. Títulos, descrições e comentários publicados reutilizam
o framework Translation da Apple, com cache por texto e idioma, disponível no
iOS 18+ e macOS 15+. No macOS 13 e 14, o conteúdo dinâmico permanece no
idioma original; os textos da interface continuam localizados em todas as versões
suportadas. Os status padrão usam o catálogo de traduções do pacote.

As assinaturas ao vivo e a consulta periódica de reserva acompanham a atividade
do aplicativo no iOS, sem depender da propagação de `scenePhase` para a sheet.
Retornar ao primeiro plano inicia uma reconciliação dos dados públicos.

Os cards de Feedback mostram foto e nome público do autor, votos,
título, descrição resumida, badge do status e total de comentários. Sem foto,
usam um ícone de perfil; sem nome, mostram Comunidade. No Roadmap, o status já
é a seção, então o card mostra na primeira linha o tipo (bug, feature, melhoria
ou dúvida) em um badge colorido com ícone, com o voto alinhado à direita; depois título, descrição de até três
linhas e, abaixo, foto e nome do autor, em espaçamento compacto. Não há badge
de status nem comentários. Itens publicados sem tipo mostram "Tipo não definido". A seta para cima representa
votar, usando `voteCount`, `viewerVoted` e a reação `.vote`, sem ícone de coração.
Nos detalhes, o botão de seta usa votos (`voteCount`, `viewerVoted`, `.vote`),
como no UAPP, e mostra os últimos cinco votantes com fotos circulares sobrepostas
ou iniciais. Os cards da listagem compartilham o mesmo voto dos detalhes e da web.
Os comentários permitem responder ao autor e alternar `.vote`, apresentada
como seta e quantidade, seguindo o contrato de comentários do UAPP.

Os detalhes mostram autor/data, título, descrição integral, status e contagens,
campo de comentário e conversa nessa ordem. Respostas aparecem abaixo do pai.
A conversa recarrega após envio/reação, ao voltar ao primeiro plano e a cada
15 segundos enquanto a tela está ativa; todas as páginas são buscadas. O texto
em edição é preservado durante essas atualizações. Comentários pendentes são
listados apenas para o próprio autor, com nome/data e indicação de moderação.
O corpo e o anexo ficam ocultos atrás de um skeleton até a aprovação. Quando
a consulta retorna o comentário publicado, a tela substitui o skeleton pelo
conteúdo e habilita responder/votar.

Comentários próprios usam a foto da sessão exibida na barra superior somente
quando o backend confirma `viewerOwned`. Nome igual não identifica autoria.
Sem sessão ou confirmação de autoria, a foto continua vindo do comentário.
O backend usa o avatar da conta autenticada para autores e votantes da comunidade,
preservando o cadastro legado como fallback quando a conta não está disponível.
`UAPPComment.viewerOwned` é opcional, com default `nil`, sem alterar payloads antigos.

Feedback e comentário aceitam até duas imagens por envio. O seletor nativo
prepara cada imagem em JPEG de até 512 KiB e 1600 pixels, reduzindo qualidade e
resolução quando necessário, sem copiar metadados de localização. Cada prévia
tem o botão de remover sobre seu canto superior direito; o clipe fica desabilitado
ao atingir duas imagens. As imagens publicadas podem ser abertas na tela.
Nos detalhes, os anexos aparecem lado a lado em miniaturas de até 140 × 100
pontos. A identidade usa o arquivo, preservando a imagem carregada quando a
URL assinada é renovada durante uma atualização. O visualizador compartilha a
imagem já carregada e usa fundo preto com botão `xmark` no canto superior esquerdo.
`submitFeedback(..., imagesData:)` e `submitComment(..., imagesData:)` enviam
até dois JPEG/PNG de 512 KiB cada; excesso ou conteúdo inválido é recusado antes
da rede. Esses métodos recebem imagens já preparadas. As variantes anteriores
com `imageData:` continuam aceitando um anexo de até 2 MiB por compatibilidade.
O backend guarda o arquivo em bucket privado e emite URLs temporárias após
verificar acesso ao feedback/comentário. Não há publicação automática de
conteúdo pendente. A equipe vê os anexos no painel para moderar.

API aditiva para uma próxima versão minor: `UAPPFeedbackVoter`,
`UAPPFeedbackItem.voters/imageURL/imageURLs/attachmentURLs`,
`UAPPComment.authorName/authorAvatarURL/imageURL/imageURLs/attachmentURLs/moderationState`
e filtro `feedbackPage(itemId:)`. Campos novos são opcionais ou têm defaults;
as chaves explícitas mantêm compatibilidade com respostas anteriores.
Nesta etapa, nenhum build, teste ou validação visual foi executado.

O badge de seta e quantidade permite votar/remover o voto diretamente, com atualização
imediata e restauração do valor anterior em caso de erro. Foto e nome abrem
`UAPPUserScreen(publicIdentity:theme:client:feedbackId:)`, reaproveitando a apresentação
do perfil com nome completo, foto, estatísticas e lista de feedbacks públicos
neste aplicativo. A lista mostra título, status e data, do mais recente para o
mais antigo, com carregamento de páginas adicionais.
Esse inicializador descarta e-mail e traits e não consulta atividade privada
nem oferece logout. `UAPPClient.authorProfile(for:cursor:statusId:)` consulta o autor a partir
de um request publicado, sem aceitar um ID arbitrário de conta. Votos feitos,
comentários publicados e solicitações publicadas são contados somente no aplicativo
público atual; conteúdo interno/pendente e atividade em outros aplicativos não
entram. O nome completo usa os dados públicos de perfil e cadastro disponíveis,
com quebra de linha para não abreviar. Sem identificação de autor, os totais
ficam indisponíveis em vez de fabricar zeros. As adições são compatíveis com os
inicializadores anteriores e devem entrar em uma versão minor.

O balão, a quantidade de comentários e o restante do card abrem os detalhes,
sem chevron lateral. Filtros sem correspondências mostram o mascote dentro do
card com mensagem específica, mantendo as opções de filtro acessíveis.

Filtros por categoria e status podem ser combinados com a busca. A ordenação
oferece mais recentes, mais votados e mais comentados e atua sobre os itens
carregados, respeitando o limite da consulta. No Roadmap, ordena os itens dentro
de cada coluna e mantém a ordem dos status. Os badges usam uma paleta estável
por status, compartilhada entre as duas telas; quando uma cor `color` vier na
resposta, ela será usada. O contrato atual não fornece cores personalizadas.

As adições públicas `authorName`, `authorAvatarURL` e `statusId` de
`UAPPFeedbackItem`, `UAPPFeedbackPage.statuses` e `UAPPRoadmapColumn.Status.color`
são opcionais ou têm defaults, preservando os inicializadores e payloads
anteriores. A evolução é aditiva e deve entrar em uma versão minor do pacote.

Implemente `UAPPAuthenticationProvider` na camada de sessão existente do app:
métodos disponíveis, sessão atual, login e logout. Para código por e-mail,
implemente também envio e verificação; os defaults retornam método não suportado.
`currentSession()` deve renovar quando necessário e retornar `nil` após logout.
A sessão contém perfil `UAPPIdentity` e access token validável pelo backend UAPP.

```swift
UAPPKit.setup(projectId: "meu-app")

// appAuthentication implementa UAPPAuthenticationProvider.
try await UAPPKit.showFeedback(authentication: appAuthentication)
try await UAPPKit.showRoadmap(authentication: appAuthentication)
```

Cada abertura cria um cliente isolado. No Mac, `show…` abre uma janela própria
com a lista ao lado do detalhe. Para navegação própria, use
`try await UAPPKit.makeClient(authentication: appAuthentication)` e injete-o
em `UAPPFeedbackScreen`/`UAPPRoadmapScreen`; no Mac, sem `NavigationStack` em
volta, porque a tela já traz a própria divisão lista/detalhe (Feedback) ou o
quadro com painel de detalhe (Roadmap).

A tela mostra conta confirmada (nome, e-mail e foto), permite sair e pede
login ao enviar, votar ou comentar. Após login, retoma a ação solicitada.
Cancelar preserva a navegação pública. O cliente também exige sessão válida
nas escritas quando configurado com esse provider, mesmo sem usar as views.

## Login próprio para aplicativos sem autenticação

`UAPPAuthentication` implementa Apple, Google e GitHub via OAuth/PKCE
no navegador de autenticação do sistema, e e-mail via código de uso único.
Não adiciona dependências externas.

```swift
let feedbackAuthentication = UAPPAuthentication(
    configuration: UAPPAuthenticationConfiguration(
        publishableKey: authenticationPublicKey,
        callbackURL: URL(string: "meuapp://uapp-auth")!,
        methods: [.apple, .google, .github, .email]
    )
)

// Guarde a instância na camada de serviços do aplicativo.
try await UAPPKit.showFeedback(authentication: feedbackAuthentication)
```

As variáveis são configuração pública do Supabase que emite tokens aceitos pelo
backend UAPP. Nunca use chave secreta ou service_role. Registre o URL scheme no
app e inclua o callback na allowlist do Supabase. Ative os provedores desejados
e configure o template de e-mail para mostrar `{{ .Token }}`: a tela usa código,
não magic link. Limite `methods` aos provedores efetivamente habilitados.

A sessão própria é persistida no Keychain, com renovação automática
e proteção contra login/refresh restaurando uma sessão após logout.
Reabrir o app restaura a conta; sair remove também o registro salvo.
Para aproveitar uma persistência externa existente, use o provider do app. O logout deste
adaptador encerra sua sessão local; o provider do hospedeiro define a abrangência
do logout na camada do aplicativo.

## Perfil local e ponte de token

Nome, e-mail e URL da foto de um perfil local ou iCloud podem ser passados em
`UAPPIdentity`. Perfil local não comprova autenticação. Tokens de outro projeto
Supabase e ID tokens Apple/Google não equivalem diretamente a um access token
aceito pelo UAPP; precisam ser trocados/validados na camada adequada.

A ponte simples continua disponível e não inclui interface de login:

```swift
try await UAPPKit.showFeedback(
    identity: UAPPIdentity(
        userId: profile.id, email: profile.email,
        displayName: profile.name, avatarURL: profile.avatarURL
    ),
    accessTokenProvider: { try await appSession.currentAccessToken() }
)
```

Com retorno `nil`, a ponte conserva participação anônima legada. Para conta/login
completo do hospedeiro, use `authentication:`. As chamadas simples mantêm sua
assinatura e passam a usar login por e-mail; a ponte explícita mantém o contrato
anterior.
`signatureProvider` mantém o header anterior, sem substituir login validado.

## Backend

As Edge Functions validam Bearer com Supabase Auth nas áreas de participação.
Token inválido recebe 401. Ausência de token conserva participação anônima.
O vínculo funciona nos aplicativos clientes e no produto interno UAPP.

Usuários finais pertencem ao aplicativo e ao sujeito autenticado validado.
Novas contas usam `auth:<subject>`; instalações anônimas usam
`guest:<installation>`. Registros legados da mesma identidade são reutilizados.
Trocar conta não transfere autoria. E-mail é contato, não chave de autenticação.
Histórico anônimo não é transferido automaticamente para uma conta.

O cache de idempotência autenticado inclui conta e instalação. Migration
`20261001153000_feedback_authenticated_identity` e as três funções públicas
foram publicados em PRD e DEV.

## Validação e próximos ajustes

API aditiva para uma próxima versão minor após CI; nenhuma tag criada.
Manifesto, build macOS, build iOS Simulator (mínimo iOS 16), 146 testes
Swift Testing, SwiftFormat lint e SwiftLint estrito aprovados.
Cobertura de linhas: 84,21%. Backend: Deno check e seis testes determinísticos.
Testes unitários não usam rede externa nem credenciais.

Demo compilado e instalado no iPhone 18 Pro Simulator: leitura pública sem
login, tela de conta, entrada de e-mail e habilitação do botão conferidas.
Configuração automática publicada em PRD/DEV; testes HTTP verificam sucesso,
header ausente e projeto inexistente. Código no e-mail de confirmação incluído
em português/inglês nos dois ambientes; o e-mail de login já continha código.

Pendente no app consumidor: OAuth/callback real, entrega de código por e-mail,
troca de contas com tokens reais e conferência visual em iPhone/iPad,
Dark Mode e Dynamic Type.

Referências:
[Supabase OAuth/PKCE](https://supabase.com/docs/guides/auth/sessions/pkce-flow),
[código por e-mail](https://supabase.com/docs/guides/auth/auth-email-passwordless)
e [emissores externos](https://supabase.com/docs/guides/auth/third-party/overview).
