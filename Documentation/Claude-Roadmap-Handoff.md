# Prompt de continuidade — UAPPKit / Roadmap

Você vai continuar o desenvolvimento do UAPPKit comigo. Considere a etapa de Feedback concluída para avançarmos agora à experiência de Roadmap. Leia este contexto e os arquivos do projeto antes de alterar código.

## Objetivo desta passagem

Quero começar a trabalhar na tela e na experiência de Roadmap do UAPPKit. Aqui, “roadmap” significa a funcionalidade pública que mostra aos usuários a evolução das sugestões do aplicativo por status. Não significa apenas escrever um plano de desenvolvimento em `Documentation/Roadmap.md`.

Esta mensagem fornece contexto. Ainda vou passar as orientações específicas de layout e comportamento: não invente uma reformulação ampla nem comece mudanças sem essas orientações. Primeiro entenda a base existente e esteja pronto para continuar.

## O que é o UAPP e para que serve o UAPPKit

O UAPP é o serviço que concentra conteúdo e participação relacionados aos aplicativos: feedbacks, sugestões, roadmap, changelog, avaliações públicas da App Store e informações públicas do desenvolvedor. O backend administra publicação, moderação e dados; o kit apresenta essas experiências dentro dos aplicativos Apple.

O UAPPKit é uma biblioteca pública distribuída como Swift Package. Seu propósito é permitir que aplicativos consumidores configurem seu projeto UAPP e abram telas nativas reutilizáveis, sem reimplementar rede, autenticação, localização e interface em cada aplicativo.

As telas são SwiftUI nativas. Não substitua essas telas por WebView. O aplicativo hospedeiro configura o kit e pode usar as apresentações prontas ou criar sua própria interface usando o cliente público.

O checkout está em `/Users/renato/Desenv/Pessoal/UAPPKit`. Ele contém várias alterações locais, inclusive arquivos novos, que ainda não estão commitadas. O estado atual dos arquivos é a referência de continuidade; o último commit sozinho não representa tudo que já foi feito. Preserve esse trabalho e não reverta mudanças existentes.

## Como o pacote funciona

- Swift tools 6.0, linguagem Swift 6; plataformas declaradas: iOS 18+ (inclui iPadOS) e macOS 13+.
- `Sources/UAPPKit/` contém a biblioteca; `Tests/UAPPKitTests/`, os testes; `Documentation/`, arquitetura e decisões; `.Examples/UAPPKitDemo/`, o aplicativo de exemplo.
- `UAPPKit.swift` é a entrada global `@MainActor`: setup, identidade, criação de clientes e apresentação das telas. No iOS, a apresentação usa `UIHostingController`.
- `UAPPKit.setup(projectId:)` recebe o identificador público do projeto (`public_slug`). Configuração também permite idioma e tema; o servidor é sempre o de produção. Não confunda esse identificador com uma credencial privada.
- `UAPPClient` é um `actor` que concentra acesso à API e estado de identidade, idioma e instalação.
- `UAPPTransport` é injetável; `URLSessionTransport` é o transporte padrão. Não adicione SDK externo sem necessidade documentada.
- `UAPPModels.swift` define os modelos públicos e respostas internas. Preserve `CodingKeys` explícitas: o contrato mistura snake_case e camelCase.
- `UAPPTheme` oferece cores e paletas para claro/escuro. `UAPPLocalization` e `Resources/Localizable.xcstrings` concentram localização. Conteúdo dinâmico usa Apple Translation onde disponível, com cache por texto/idioma; no macOS 13/14 permanece no idioma original.
- APIs `public` são consumidas por outros aplicativos. Preserve compatibilidade; mudanças aditivas são preferíveis e mudanças de contrato precisam ser documentadas.

## O que já foi feito

Já existem experiências nativas de Sobre do aplicativo, Sobre do desenvolvedor, Changelog, Reviews, conta/autenticação e Feedback. Elas compartilham tema, idioma e componentes. Changelog já tem detalhes, paginação, busca e tradução; Reviews tem paginação e tradução. Consulte a documentação específica caso precise reutilizar algo.

A etapa recente de Feedback implementou e refinou:

- Lista pública com cards: autor/foto, título, descrição resumida, status, votos e quantidade de comentários.
- Busca local em título/descrição, ignorando caixa, acentos e espaços nas extremidades, com estado sem resultados.
- Tela de detalhes com descrição completa, autor/data, status, últimos cinco votantes e total de votos.
- Votar/remover voto com atualização imediata e restauração do estado anterior em caso de erro.
- Conversa com comentários, respostas agrupadas por `parentCommentId`, avatares, abertura de perfis públicos e votos nos comentários.
- Compositor de texto e anexos; até duas imagens por envio, preparadas em JPEG de até 512 KiB e 1600 pixels cada, sem copiar metadados de localização. As variantes antigas com uma imagem permanecem por compatibilidade.
- Conteúdo sujeito à moderação. Comentários próprios pendentes mostram identificação e skeleton; corpo/anexo só aparecem após aprovação. Não exponha conteúdo privado ou pendente a outros usuários.
- Perfis públicos e participação da conta: estatísticas, feedbacks, filtros e navegação para detalhes.
- Cores de status consistentes entre Feedback, Roadmap, detalhes e perfil; filtros usam indicadores coloridos pela posição da etapa.
- Atualização ao vivo por aplicativo, via WebSocket nativo e avisos públicos de Realtime. As telas reconsultam a API pública para reconciliar dados. A conexão acompanha primeiro/segundo plano e há consulta periódica de 15 segundos como reserva. Preserve filtros, páginas já carregadas e rascunhos.
- Tradução de títulos, descrições e comentários publicados, além da localização da interface.

Considere Feedback concluído como etapa de trabalho por minha orientação. Isso não significa afirmar que todos os cenários foram testados: mudanças recentes foram feitas sem build, testes ou inspeção visual automatizada, conforme minha preferência. A documentação pode conter checklists antigos ou descrições anteriores à implementação atual; confirme detalhes no código.

## Autenticação e identidade

Setup não exige login. Sobre, Changelog e Reviews permanecem públicos. Feedback e Roadmap permitem navegação pública; login é solicitado para ações como enviar, votar e comentar, retomando a ação após autenticação.

O hospedeiro pode fornecer `UAPPAuthenticationProvider`, reaproveitando sua sessão, ou usar a autenticação automática do kit. Cada abertura com autenticação cria um cliente isolado. Perfil/identidade e sessão autenticada são conceitos distintos: um nome ou e-mail informado localmente não prova identidade.

Já há componentes reutilizáveis para conta, login, cadastro, recuperação, sessão e perfil. Reutilize-os no Roadmap. O `signatureProvider` legado envia `x-uapp-signature`; não o apresente como garantia de autorização, pois sua verificação server-side não está ativa segundo a documentação. Confira o fluxo de autenticação atual antes de alterar qualquer regra de acesso.

## O Roadmap já tem uma base

Não comece do zero. Já existem apresentação por `UAPPKit.showRoadmap`, view `UAPPRoadmapScreen`, carregamento por `UAPPClient.roadmap(limit:)` e modelo `UAPPRoadmapColumn` com status e itens.

A API pública usa `GET /public-feedback` com `slug` e `resource=roadmap`. Retorna status visíveis e itens publicados agrupados por status. O cliente ordena as colunas pela posição e exclui status ocultos. Os headers incluem `x-uapp-project` e `x-uapp-installation-id`. Não invente endpoints ou libere acesso direto às tabelas.

A implementação da tela está em `UAPPFeedbackScreen.swift`, que compartilha infraestrutura entre os módulos. O Roadmap já usa busca local (incluindo o nome do status), cards, detalhes, tema, idioma, autenticação e atualização ao vivo relacionados ao Feedback. Preserve esses comportamentos ao evoluir o layout.

Não presuma que paginação ou pesquisa remota de Roadmap estejam prontas; a documentação aponta isso como evolução futura. Também não presuma que um layout Kanban horizontal seja a decisão desejada: vou orientar a experiência que quero.

## Arquivos para consultar primeiro

1. `AGENTS.md` e `/Users/renato/.codex/RTK.md`.
2. `README.md`, `Documentation/Architecture.md`, `Documentation/Decisions.md` e `CHANGELOG.md`.
3. `Documentation/Feedback.md`, `Documentation/Authentication.md`, `Documentation/UserActivity.md` e `Documentation/Roadmap.md`.
4. `Sources/UAPPKit/UAPPKit.swift`, `UAPPClient.swift`, `UAPPModels.swift` e `UAPPFeedbackScreen.swift`.
5. Componentes compartilhados: `UAPPFeedbackCard.swift`, `UAPPFeedbackDetailScreen.swift`, `UAPPFeedbackSearch.swift`, `UAPPFeedbackTranslation.swift`, `UAPPFeedbackLive.swift`, `UAPPFeedbackLiveModifier.swift`, `UAPPStatusBadge.swift`, `UAPPTheme.swift` e `UAPPLocalization.swift`.
6. Testes correspondentes e integração já existente no Demo, apenas como leitura de referência.

Os caminhos de código acima são relativos à raiz do checkout; confirme a organização atual ao ler os arquivos.

## Regras de trabalho do proprietário

- Faça somente as alterações pedidas e informe quando terminar.
- Não execute builds, testes automatizados, cobertura ou inspeções de telas em simulador/dispositivo. Não abra, instale ou rode o Demo para validar. Eu faço a validação e envio fotos e orientações. Só execute uma validação quando eu pedir explicitamente e apenas no escopo solicitado; não solicite autorização a cada alteração.
- Alterações de comportamento público devem incluir/atualizar testes da unidade, mas sem executá-los por iniciativa própria. Use exclusivamente Swift Testing e transporte falso, sem rede externa.
- Interface nativa, acessível, compatível com Dynamic Type e claro/escuro.
- Antes de planejar ou alterar layout para iPhone Duo/telas dobráveis, leia `/Users/renato/.codex/iPhone-Duo-Playbook.md`.
- Não inclua credenciais, tokens ou dados privados. Não cite projetos pessoais do proprietário em interfaces, documentação pública ou exemplos.
- Não crie release/tag sem versão pronta e validada pela CI. Não faça commit, publicação ou alterações no backend apenas por causa desta passagem de contexto.

Comece lendo a base existente. Responda brevemente confirmando seu entendimento do pacote, do que já existe em Feedback/Roadmap e dos pontos de reutilização. Depois continue conforme as orientações específicas que eu enviar para o Roadmap.
