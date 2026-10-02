# Roadmap e limites conhecidos

## Checklist de implementação — 1 de outubro de 2026

Itens marcados representam código existente no pacote. Validação visual,
integração com o backend e publicação têm tarefas próprias abaixo.

### Sobre o desenvolvedor

- [x] Tela SwiftUI separada com perfil, biografia, aplicativos e redes sociais.
- [x] Tema claro/escuro, localização e controles compartilhados de idioma e fechar.
- [x] Biografia com traduções cadastradas e alternativa via Apple Translation.
- [x] Estados de carregamento, indisponibilidade e testes com transporte falso.

### Sobre o aplicativo

- [x] Metadados do bundle, ícone, versão/build e conteúdo institucional configurável.
- [x] Links de suporte, privacidade e avaliação conforme a configuração disponível.
- [x] Acesso às telas do kit, tema e seleção de idioma compartilhados.
- [x] Testes dos modelos, configuração e renderização inicial.

### Changelog

- [x] Lista nativa, detalhes por versão e Markdown com formatação preservada.
- [x] Imagens por item, carrossel, indicadores, parallax e autoplay configurável.
- [x] Busca local, ordenação decrescente e datas localizadas.
- [x] Paginação, remoção de duplicatas, loading, falha e retry.
- [x] Tradução com cache compartilhado entre lista e detalhes.
- [ ] Conferência final da rolagem, tradução real e download de idiomas em dispositivo.

### Reviews

- [x] Avaliações públicas da App Store com estrelas, texto e resposta do desenvolvedor.
- [x] Paginação automática com loading, retry e proteção contra cursores repetidos.
- [x] Tradução de título, corpo e resposta com cache por texto/idioma.
- [x] Tema, idioma, fechar e estados vazio/erro alinhados ao restante do kit.
- [ ] Conferência da tradução real e instalação de idiomas em dispositivo compatível.

### Feedback e Roadmap — etapa atual

- [x] Leitura pública, envio de feedback, reações e comentários moderados.
- [x] Fechar, idioma e ações com a mesma cor de destaque, incluindo formulário e detalhes.
- [x] Lupa e busca local em título/descrição; Roadmap também pesquisa o nome do status.
- [x] Busca ignora espaços nas extremidades, caixa e acentos, com estado sem resultados.
- [x] Perfil opcional do app cliente: identificador, nome, e-mail e URL da foto.
- [x] Ponte opcional de access token na abertura de Feedback/Roadmap, com clientes isolados e sem sessão no setup ou nas leituras de Sobre/Changelog/Reviews.
- [x] Estratégia global de identidade e autenticação em [Feedback e autenticação](Feedback.md).
- [x] Vincular identidade validada aos usuários do aplicativo no backend UAPP, publicado em PRD/DEV.
- [ ] Validar as Edge Functions com tokens reais e autorização por projeto/usuário.
- [x] Implementar login próprio quando não houver sessão reutilizável (Apple, Google, e-mail e GitHub).
- [x] Simplificar o fluxo padrão com e-mail/código, configuração automática e Demo integrado.
- [x] Implementar autenticação reutilizável no kit com login, cadastro e recuperação, independente do Demo.
- [ ] Validar com o proprietário o novo fluxo de autenticação, sua compilação e os modelos de confirmação/recuperação de e-mail.
- [x] Mostrar conta confirmada e logout; renovar sessão sob demanda e separar autoria na troca de conta.
- [ ] Exercitar OAuth/callback, e-mail e troca de contas reais no app consumidor.
- [ ] Persistir sessão própria em Keychain, caso necessário.
- [ ] Validar visualmente esta etapa em iPhone/iPad, claro/escuro e Dynamic Type.
- [ ] Evoluir paginação e pesquisa remota de Feedback/Roadmap.

### Release

- [ ] CI aprovada antes de selecionar versão minor e criar tag SemVer.
- [ ] Publicar somente após as validações de integração previstas para a versão.

## Estado atual e limites

UAPPKit cobre leitura de conteúdo público, submissão de feedback, reações,
comentários moderados e views SwiftUI para Feedback, Roadmap, Changelog,
Reviews, Sobre o aplicativo e Sobre o desenvolvedor. Não há cache persistente
ou modo offline nem notificações push. Feedback e comentários aceitam até duas
imagens de 512 KiB por envio, preparadas em JPEG pelo seletor nativo, com
publicação sujeita à moderação. O contrato legado de uma imagem é preservado. A tela Sobre
obtém versão/build do bundle; os envios de feedback ainda não incluem esses
metadados automaticamente.

A interface nativa já usa um String Catalog com seleção manual de idioma,
preferência inicial derivada do app hospedeiro e persistência da escolha do
usuário. Feedback e Roadmap preservam o idioma do conteúdo publicado.
Reviews e Changelog já oferecem tradução com cache em memória por apresentação
nos sistemas compatíveis. Na tela Sobre, a biografia usa primeiro a tradução
cadastrada no UAPP; se ela não existir para o idioma selecionado, pode ser
traduzida sob demanda pelo framework Apple Translation.

## Direção futura do kit Apple

O planejamento mais amplo do ecossistema Apple considera uma camada SwiftUI
compartilhada para tokens semânticos, tipografia adaptada a Dynamic Type,
espaçamento, raio, elevação e temas configuráveis por aplicativo. Também
considera componentes de feedback, changelog e notificações, com serviços
injetáveis, previews e mocks.

Requisitos de design previstos incluem:

- manter semântica de estado independente da cor de marca do aplicativo;
- alvos de toque de pelo menos 44 pt no iOS;
- navegação nativa adaptada a iPadOS e macOS;
- conteúdo compacto e legível no watchOS, se vier a ser suportado;
- temas claro/escuro, acessibilidade e localização;
- testes de Dynamic Type, acessibilidade, localização e funcionamento offline;
- não exigir Core Data, StoreKit ou dados específicos de um aplicativo.

Essas ideias não alteram os destinos nem o contrato suportado pelo pacote
atual. watchOS, tvOS e visionOS exigem implementação e validação próprias
antes de serem declarados compatíveis.

## Evolução técnica considerada

- ativar e documentar verificação server-side das assinaturas;
- adicionar cache local e fallback offline para leitura;
- permitir filtros adicionais e refinamentos de paginação para o changelog;
- enriquecer as telas nativas e ampliar a cobertura de localização;
- refinar anexos de feedback/comentários após conferência visual pelo proprietário;
- planejar notificações push somente com desenho de backend e armazenamento
  seguro de tokens APNs.

Itens deste roadmap não são promessas de prazo nem capacidades da versão atual.
