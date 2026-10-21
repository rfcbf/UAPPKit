# Arquitetura e contrato com o serviço UAPP

Os detalhes de feedback consomem o item específico e todas as páginas de
comentários, com respostas, perfis públicos e anexos. A tela atualiza a conversa
no primeiro plano e após escritas. Imagens JPEG/PNG opcionais são enviadas como
`image: { mimeType, base64 }` nos endpoints existentes de envio/interação;
respostas de feedback usam `image_url` e comentários usam `imageUrl` com URLs
temporárias. O arquivo permanece privado até uma leitura autorizada.

A ponte opcional de sessão recebe `accessTokenProvider` ao abrir Feedback/Roadmap
ou criar um cliente de participação, e envia Authorization apenas nessas áreas.
O setup e as leituras de Sobre, Changelog e Reviews ficam independentes da
sessão. A ponte usa a persistência do hospedeiro e não assume que um perfil informado está
autenticado. `signatureProvider` mantém seu header anterior. O desenho
do vínculo aos usuários do aplicativo e os limites desta etapa estão em
[Feedback e autenticação](Feedback.md).

`UAPPAuthenticationProvider` integra a sessão do hospedeiro com a interface
nativa de login. O adaptador opcional `UAPPAuthentication` implementa
nativamente o fluxo personalizado. Nas chamadas simples de Feedback/Roadmap,
um provider interno descobre a configuração pública ao solicitar código e
compartilha a conta, persistida no Keychain por servidor e projeto. O cliente público permanece sem autenticação.
O adaptador personalizado implementa
OAuth/PKCE, código por e-mail, persistência no Keychain e renovação de sessão. O backend
vincula usuários por aplicativo e sujeito validado, separando contas e convidados.

## Objetivo e escopo atual

`UAPPAccountScreen` é a interface reutilizável da conta do aplicativo. Seu
modelo controla login, cadastro, confirmação e recuperação com o provedor
injetado. `UAPPAuthentication.automatic` e `UAPPKit.makeAuthentication`
compartilham a implementação de descoberta pública; o Demo não implementa
endpoints nem conserva senhas. A identidade visual reutiliza o componente do
Sobre e o tema do kit. As apresentações comunicam alterações de sessão ao
hospedeiro, que mantém o provedor para Feedback/Roadmap. A integração está em
[Autenticação](Authentication.md).

UAPPKit é um Swift Package para integrar aplicativos Apple às experiências
públicas de Feedback, Roadmap, Changelog, avaliações da App Store e Sobre do UAPP. A interface é
SwiftUI nativa, sem `WKWebView` nem `SFSafariViewController`.

O pacote oferece leitura de conteúdo publicado, paginação de feedback e
comentários, envio de feedback, votos e comentários sujeitos à
moderação. Não implementa cache offline, notificações push, upload de imagens
ou sincronização automática do changelog.

## Componentes

| Arquivo | Responsabilidade |
| --- | --- |
| `UAPPKit.swift` | Ponto de entrada global `@MainActor`: configuração, identidade, criação do cliente e apresentação de telas SwiftUI no iOS. |
| `UAPPConfiguration.swift` | Configuração imutável (`projectId`, host, locale e `signatureProvider`) e identidade opcional do usuário final. |
| `UAPPClient.swift` | `actor` que acessa os endpoints públicos, conserva identidade, locale e identificador de instalação. |
| `UAPPLocalization.swift` | Catálogo de idiomas suportados, preferência do hospedeiro e seleção temporária isolada nas telas nativas. |
| `UAPPTranslation.swift` | Exibe a biografia no idioma de origem e oferece tradução sob demanda pelo framework Apple Translation. |
| `UAPPTransport.swift` | Protocolo substituível `UAPPTransport` e implementação `URLSessionTransport`. |
| `UAPPModels.swift` | Modelos públicos e estruturas internas para decodificar as respostas. |
| `UAPPFeedbackScreen.swift` | Views SwiftUI para Feedback, Changelog e envio de feedback; `mode: .roadmap` delega a `UAPPRoadmapScreen`. |
| `UAPPRoadmapScreen.swift` | Roadmap público: itens agrupados pelos status visíveis, com busca, filtros, ordenação, voto, detalhes e atualização ao vivo. |
| `UAPPFeedbackListSupport.swift` | Infraestrutura compartilhada por Feedback e Roadmap: filtros/ordenação, estado sem resultados, navegação para detalhes/autor, voto otimista e classificação de falhas de carga. |
| `UAPPReviewsScreen.swift` / `UAPPAboutScreen.swift` | Telas nativas para avaliações públicas da App Store e Sobre do aplicativo. |
| `UAPPDeveloperAboutScreen.swift` | Tela separada para o perfil público do desenvolvedor, seus apps e redes sociais. |
| `UAPPAboutConfiguration.swift` / `UAPPAboutComponents.swift` | Metadados automáticos do bundle, conteúdo institucional parametrizável e componentes visuais das telas Sobre. |
| `UAPPKitError.swift` | Erros tipados de configuração, transporte, resposta HTTP e decodificação. |

## Configuração e identidade

`projectId` é o `public_slug` do projeto no UAPP. O host padrão aponta para a
URL pública do projeto Supabase de produção; `setup` permite substituí-lo,
como ao usar DEV. A leitura pública não exige chave de API. O adaptador de
login opcional recebe apenas a chave pública do Supabase; credenciais
administrativas nunca entram no SDK.

O tema é configurado globalmente em `UAPPKit.setup` por `UAPPTheme`, com
paletas opcionais para light e dark. O tema padrão usa cores semânticas do
sistema Apple e as telas escolhem a paleta conforme o `ColorScheme` ativo.
`buttonText` permite controlar o contraste do rótulo em botões preenchidos;
quando omitido, usa branco.

A tela Sobre do aplicativo usa o ícone, o nome e a versão do bundle do
aplicativo hospedeiro. Descrição curta, seu idioma original, site, suporte,
política de privacidade, termos de uso e licença são recebidos por
`UAPPAboutConfiguration`; em sistemas compatíveis, a descrição é traduzida pela
Translation framework da Apple para o idioma escolhido na sheet. Já
`showDeveloperAbout()` apresenta o perfil público remoto em uma tela separada.
Ambas são apresentadas como `pageSheet` no iOS usando somente o detent grande,
mantendo as cores do tema configurado no `UAPPKit.setup`.

`identify` recebe dados opcionais de usuário final. Eles são distintos das
contas do painel UAPP e podem ser enviados em submissões de feedback. `reset`
limpa a identidade do cliente corrente.

Uma instalação UUID é persistida em `UserDefaults` sob uma chave derivada do
identificador público do projeto. O valor acompanha as interações para
reconhecer reações da instalação e compor chaves de idempotência.

`signatureProvider` é um closure assíncrono que fornece token ao cliente. O SDK
envia o valor em `x-uapp-signature` com prefixo Bearer. A verificação desse
token pelo backend ainda não está ativa; a assinatura não oferece hoje uma
garantia de autenticação ou autorização.

### Localização

Os textos da interface são mantidos em `Resources/Localizable.xcstrings`, com
Português (Brasil) como idioma de origem. `setup(locale:)` aceita o locale
inicial do aplicativo hospedeiro; sem esse valor, o SDK deriva a preferência do
locale atual do sistema. A preferência selecionada dentro do UAPPKit é salva em
`UserDefaults` e aplicada ao ambiente SwiftUI de cada apresentação. As
requisições HTTP também enviam o idioma atual em `Accept-Language`.

## Contrato HTTP

Os endpoints ficam sob `<host>/functions/v1`.

### Leitura

`GET /public-feedback` aceita os parâmetros:

| Parâmetro | Uso |
| --- | --- |
| `slug` | Identificador público do projeto. |
| `resource` | `feedback`, `roadmap`, `changelog` ou `comments`. |
| `limit` | Limite de itens solicitado. |
| `cursor` | Cursor opcional para continuar uma página de feedback ou comentários. |
| `itemId` | Identificador do feedback ao consultar comentários. |

Os headers incluem `x-uapp-project` e `x-uapp-installation-id`; o header de
assinatura é incluído quando há provider configurado.

- **feedback:** itens públicos e publicados, contagens de votos e
  comentários, categoria, prioridade, etiquetas aplicadas (`tags`, opcional
  em servidores antigos) e estado das reações da instalação.
- **roadmap:** status visíveis no roadmap e itens publicados agrupados por
  status. O SDK ordena colunas pela posição e não apresenta status ocultos.
- **changelog:** entradas publicadas com `title`, `slug`, `bodyMarkdown`,
  `version`, `build`, `platform`, `sections`, `releasedAt` e `publishedAt`.
  `UAPPClient.changelog` e `changelogPage` aceitam filtros opcionais por
  categoria (`new`, `improved`, `fixed`, `security`), plataforma (`all`,
  `ios`, `ipados`, `macos`, `watchos`, `tvos`, `visionos`), versão, build e
  datas inclusivas `from`/`to` no formato `YYYY-MM-DD`. A página retorna um
  cursor para continuar a leitura e a contagem total quando fornecida.
  `descriptionMarkdown` (`description_md`) separa a descrição geral dos itens;
  cada `UAPPChangelogSection` aceita `imageURL` (`image_url`) HTTPS opcional.
  A apresentação ordena por posição, preservando a ordem original nos empates.
  Respostas antigas usam `bodyMarkdown` como conteúdo e não repetem as seções.
  A lista mostra resumos de três linhas, imagens em 40:21 sem recortar e itens
  sem imagem agrupados por categoria. O detalhe mostra cada imagem seguida do
  texto completo, na ordem dos itens. A pesquisa filtra as páginas carregadas.
  `UAPPChangelogConfiguration` controla a reprodução automática, desativada por
  padrão e pausada fora da tela, em segundo plano, com VoiceOver ou Reduzir Movimento.
- **comments:** conteúdo público de comunidade para um item, incluindo cursor
  de paginação e estado de voto da instalação.
- **reviews:** avaliações da App Store/TestFlight sincronizadas no UAPP para o
  aplicativo e expostas quando o módulo está público. O UAPP continua sendo a
  origem e o local de gestão dessas avaliações; o SDK só as consulta. A tela
  carrega páginas de 20 com `reviewsPage(limit:cursor:)`, preserva o conteúdo
  quando uma página falha e oferece nova tentativa. O contrato inclui
  `response_body` opcional e `nextCursor`; `reviews(limit:)` permanece compatível.
- **about:** nome, imagem e biografia do desenvolvedor, outros apps e links
  sociais opcionais publicados nas configurações do app no UAPP.

Os metadados públicos do projeto também podem conter `appStoreURL` (ou
`appStoreUrl`) e `appleAppId`. Quando presentes, `showAbout` exibe a ação
“Avaliar o app” e `openAppStoreReview()` abre o fluxo de avaliação do app
configurado, sem depender de uma URL informada manualmente pelo aplicativo
hospedeiro.

`UAPPAboutConfiguration.showsChangelog` controla a ação opcional “Changelog”
dentro do Sobre do app. Quando habilitada, ela abre a mesma tela nativa de
Changelog em uma sheet grande, usando o cliente do projeto configurado.
`UAPPAboutConfiguration.changelogConfiguration` é repassada a essa tela,
preservando as opções de reprodução automática e intervalo do carrossel.
Ela também define `pageSize`, usado em todas as requisições do changelog,
incluindo retries: padrão 10, ajustado à faixa de 1 a 50.
O parâmetro é aditivo e seu padrão mantém a reprodução manual.
`UAPPAboutConfiguration.showsAppStoreReview` controla, da mesma forma, a
visibilidade da ação “Avaliar o app” na App Store.

Uma resposta HTTP não 2xx resulta em `UAPPKitError.http`, com status e uma
mensagem quando o servidor a fornece. Respostas inválidas produzem
`UAPPKitError.invalidResponse`.

Quando o recurso solicitado não está disponível, o serviço responde com um
403 genérico (`Conteúdo não público.`), sem distinguir conteúdo privado de
módulo oculto. A resposta pode incluir apenas os metadados públicos `slug` e
`primaryColor`; o cliente os conserva em `currentProject()` para personalizar
a apresentação nativa mesmo nesse estado.

### Escrita

- `POST /public-feedback-submit` envia título, corpo opcional, categoria,
  identidade opcional e installation ID. O SDK envia `Idempotency-Key`.
  Submissões são moderadas pelo serviço.
- `POST /public-feedback-interact` envia voto, retirada de voto ou comentário.
  Também inclui installation ID,
  identificador do item e chave de idempotência. Comentários podem incluir
  comentário pai e nome de exibição e entram em moderação.

Reviews são somente leitura no SDK. Sua sincronização e disponibilidade pública
são controladas no UAPP. A tela Sobre também é somente leitura; campos que não
forem preenchidos no UAPP não são exibidos.

A biografia do desenvolvedor usa a tradução cadastrada no UAPP quando ela
existe para o idioma selecionado. Sem uma versão cadastrada, aparece no idioma
padrão da biografia e a pessoa pode pedir uma tradução pelo Apple Translation.
Nenhuma tradução é iniciada automaticamente. Esse recurso está disponível a
partir do iOS 18 e macOS 15.

O serviço deve validar escopo, publicação, visibilidade e conteúdo. O SDK não
contém nem substitui as regras de autorização do backend.

## Decodificação e compatibilidade

Modelos usam `CodingKeys` explícitas porque o contrato mistura snake_case nos
campos de dados e camelCase nos envelopes. O decoder usa datas ISO 8601 e não
aplica conversão global de nomes de chave.

O transporte é injetável por `UAPPTransport`, permitindo testes sem rede. A API
pública inclui o facade `UAPPKit`, `UAPPClient`, configuração, identidade,
modelos, modos de tela, protocolo de transporte e erros.

## Plataformas

- iOS 18 ou posterior, incluindo iPadOS: cliente, views e apresentação nativa
  pelo view controller ativo.
- macOS 13 ou posterior: cliente, views SwiftUI e apresentação em janelas
  próprias (`UAPPMacWindowPresenter`, uma janela por tela, com
  `NSHostingController`). A barra de ferramentas do SwiftUI é levada para a
  janela a partir do macOS 14 (`sceneBridgingOptions`). No Mac, Feedback usa
  `UAPPFeedbackSplitView` (lista e detalhe em colunas comuns, sem barra
  lateral, para a barra de ferramentas ter uma cor só) e Roadmap usa
  `UAPPRoadmapBoard` (quadro por status) com o detalhe em um inspetor.
  `UAPPScreenCloser` lê a janela real da tela e fecha a janela do pacote.
  `UAPPKitCommands` expõe as telas na barra de menus.
- watchOS, tvOS e visionOS não são declarados como destinos suportados.

## Adaptação ao iPhone Duo

As telas do UAPPKit são SwiftUI nativas e devem permanecer adaptáveis ao iPhone
Duo sem conhecer o modelo do dispositivo. O pacote usa listas, navegação e
toolbars do sistema, respeita safe areas e não deve usar `UIScreen.main`,
orientação fixa ou métricas globais para decidir o layout. A tela interna pode
oferecer mais espaço, mas mantém a mesma hierarquia e funcionalidade da tela
externa.

O pacote usa deployment target iOS 18. APIs específicas do Duo, como
regiões reservadas, arrangements, observação da dobradiça, múltiplas cenas ou
câmeras frontal interna/externa, só devem ser adicionadas em um app hospedeiro
quando o caso de uso exigir e com a disponibilidade de plataforma apropriada.
O app hospedeiro é responsável por validar as telas no simulador iPhone Duo do
Device Hub, incluindo abertura, fechamento, dobra, rotação e Split View. O
portfólio mantém uma referência compartilhada de requisitos e checklist; este
pacote não depende desse checkout privado para compilar ou funcionar.

O app de demonstração usa uma decisão única para escolher entre dois painéis
(`ArrangementView` em iOS 27.1+) e uma lista completa de configuração seguida
pelos atalhos. Assim, o conteúdo secundário continua acessível em uma coluna
sem aparecer duas vezes quando os painéis estão lado a lado.
