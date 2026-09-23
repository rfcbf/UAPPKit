# Arquitetura e contrato com o serviço UAPP

## Objetivo e escopo atual

UAPPKit é um Swift Package para integrar aplicativos Apple às experiências
públicas de Feedback, Roadmap e Changelog do serviço UAPP. A interface é
SwiftUI nativa, sem `WKWebView` nem `SFSafariViewController`.

O pacote oferece leitura de conteúdo publicado, paginação de feedback e
comentários, envio de feedback, votos, curtidas e comentários sujeitos à
moderação. Não implementa cache offline, notificações push, upload de imagens
ou sincronização automática do changelog.

## Componentes

| Arquivo | Responsabilidade |
| --- | --- |
| `UAPPKit.swift` | Ponto de entrada global `@MainActor`: configuração, identidade, criação do cliente e apresentação de telas SwiftUI no iOS. |
| `UAPPConfiguration.swift` | Configuração imutável (`projectId`, host, `signatureProvider`) e identidade opcional do usuário final. |
| `UAPPClient.swift` | `actor` que acessa os endpoints públicos, conserva identidade e identificador de instalação. |
| `UAPPTransport.swift` | Protocolo substituível `UAPPTransport` e implementação `URLSessionTransport`. |
| `UAPPModels.swift` | Modelos públicos e estruturas internas para decodificar as respostas. |
| `UAPPFeedbackScreen.swift` | Views SwiftUI para Feedback, Roadmap, Changelog, envio de feedback e comentários. |
| `UAPPKitError.swift` | Erros tipados de configuração, transporte, resposta HTTP e decodificação. |

## Configuração e identidade

`projectId` é o `public_slug` do projeto no UAPP. O host padrão está definido
no código como `https://app.uapp.com`; `setup` permite substituí-lo. Não há
chave de API ou credencial administrativa no SDK.

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

- **feedback:** itens públicos e publicados, contagens de votos, curtidas e
  comentários, categoria, prioridade e estado das reações da instalação.
- **roadmap:** status visíveis no roadmap e itens publicados agrupados por
  status. O SDK ordena colunas pela posição e não apresenta status ocultos.
- **changelog:** entradas publicadas. O modelo público atual expõe `title`,
  `slug`, `bodyMarkdown` e `publishedAt`. Campos adicionais da resposta do
  servidor são ignorados e não há filtros Swift para plataforma, versão,
  build, categoria ou datas.
- **comments:** conteúdo público de comunidade para um item, incluindo cursor
  de paginação e estado de curtida da instalação.

Uma resposta HTTP não 2xx resulta em `UAPPKitError.http`, com status e uma
mensagem quando o servidor a fornece. Respostas inválidas produzem
`UAPPKitError.invalidResponse`.

### Escrita

- `POST /public-feedback-submit` envia título, corpo opcional, categoria,
  identidade opcional e installation ID. O SDK envia `Idempotency-Key`.
  Submissões são moderadas pelo serviço.
- `POST /public-feedback-interact` envia voto, retirada de voto, curtida,
  retirada de curtida ou comentário. Também inclui installation ID,
  identificador do item e chave de idempotência. Comentários podem incluir
  comentário pai e nome de exibição e entram em moderação.

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

- iOS 16 ou posterior, incluindo iPadOS: cliente, views e apresentação nativa
  pelo view controller ativo.
- macOS 13 ou posterior: cliente e views SwiftUI; a apresentação automática
  de view controller é condicionada a UIKit e não existe no macOS.
- watchOS, tvOS e visionOS não são declarados como destinos suportados.
