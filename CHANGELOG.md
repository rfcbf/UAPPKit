# Changelog

As alterações públicas do UAPPKit serão registradas aqui. O formato segue
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) e as versões seguem
[Semantic Versioning](https://semver.org/).

## Não lançado

## 2.1.0 - 2026-10-21

- `UAPPProject.autoPublishSeconds`: no app de demonstração do UAPP, o
  servidor informa em quantos segundos a requisição e o comentário de quem
  testa são publicados sozinhos. Depois de enviar, o Feedback (requisição) e o
  detalhe (comentário) mostram um aviso com a contagem e recarregam quando o
  tempo acaba, já com o envio publicado. Nos apps comuns o valor é nulo e nada
  muda: o envio segue para a moderação.
- Conta: depois do login, o kit usa o nome e a foto do perfil do UAPP, os
  mesmos do painel web, quando a conta não tem esses dados. A foto escolhida
  no kit continua valendo primeiro e, ao ser trocada, passa a ser gravada
  também no perfil do UAPP. Antes, quem tinha foto só no painel aparecia sem
  foto e com o e-mail no lugar do nome.
- Mac: login e cadastro abertos pelo Feedback ou pelo Roadmap usam a mesma
  janela da conta de `UAPPKit.showAuthentication`, com a altura toda e sem
  rolagem. Antes abriam numa sheet presa à altura da janela de baixo. Ao fechar
  a janela, a tela de origem atualiza a sessão e conclui a ação que pediu o
  login, como um voto.
- Mac: "Fechar" e Esc voltam a fechar as sheets abertas pelo kit com navegação
  própria (Changelog e Avaliações dentro do Sobre, compositor de feedback,
  conta e perfil do autor). O `dismiss` do SwiftUI não fechava essas sheets a
  partir da barra no Mac; agora quem abre a sheet informa como fechá-la.
- Mac: o detalhe de uma versão do Changelog e o detalhe de um feedback aberto
  pelo histórico do perfil usam o voltar nativo da navegação, à esquerda do
  título, no lugar da seta própria do kit.
- Mac: as janelas de Novidades, Avaliações, Sobre e Desenvolvedor têm só o
  botão de fechar, sem minimizar nem maximizar, e continuam redimensionáveis
  pelas bordas. Feedback e Roadmap mantêm os três botões.
- Mac: a lista do Feedback cresce junto com a janela (uma fração da largura,
  entre 300 e 560 pontos), e o divisor arrastado guarda a fração escolhida.
  No Roadmap, as colunas dividem a largura da janela e só rolam na horizontal
  quando não cabem com 280 pontos cada.

## 2.0.0 - 2026-10-21

- **Quebra de compatibilidade:** o kit acessa sempre o servidor de produção do
  UAPP. Os aplicativos não escolhem mais servidor:
  - `UAPPKit.setup(projectId:theme:signatureProvider:locale:)` perde o
    parâmetro `host`.
  - `UAPPConfiguration(projectId:signatureProvider:locale:)` e
    `UAPPAuthenticationConfiguration(publishableKey:…)` perdem `host`.
  - `UAPPClient(accountActivityHost:)` dá lugar a
    `UAPPClient(accountActivityTransport:)`, também em produção.
  - Para migrar, remova o argumento `host:`. Ferramentas da equipe que precisam
    de outro servidor usam as variantes com `host`, disponíveis só com
    `@_spi(UAPPInternal) import UAPPKit`.
- Demos: sem campo de servidor; o projeto padrão passa a ser o `app-demo` de
  produção, e os dados fictícios (`--mock-data`) respondem no lugar do
  servidor de produção, sem acessar a rede.

## 1.12.0 - 2026-10-20

- Mac: as telas do kit passam a ter versão nativa para o Mac. `UAPPKit.show…`
  abre cada tela em uma janela própria, reaproveitada a cada abertura, com
  título, barra de ferramentas (macOS 14+), centralizada no monitor. Conta
  e Perfil fecham a janela depois do login ou de sair da conta.
  `openAppStoreReview()` também fica disponível no Mac.
- Mac: Feedback mostra a lista ao lado do detalhe, com divisor arrastável e
  largura lembrada; Roadmap vira um quadro com uma coluna por status e abre o
  item em um painel à direita. Os ícones da barra usam a cor do sistema. A
  busca fica sempre visível na barra de ferramentas,
  com Atualizar (⌘R) e Enviar feedback (⌘N); o idioma vira um menu nativo, as
  sheets ganham "Fechar" com Esc, o envio de feedback usa ⌘↩ e as sheets têm
  tamanho próprio no Mac.
- Mac: `UAPPProfilePhotoPicker` passa a existir no Mac, com o app Fotos, arquivo
  do Finder e recorte circular próprio do pacote (arrasto e zoom). Cadastro,
  conclusão do cadastro e Perfil passam a oferecer a foto no Mac.
- Mac: a sessão da conta passa a ser guardada no Keychain moderno (o mesmo do
  iPhone), que não pede a senha das chaves "login". Apps sem o direito de usá-lo
  continuam no Keychain clássico. Ao atualizar, a sessão salva no Keychain
  clássico não é migrada: a pessoa entra de novo uma vez.
- Novo `UAPPKitCommands`: coloca Feedback, Roadmap, Novidades, Avaliações,
  avaliação na App Store e Sobre o desenvolvedor no menu Ajuda e, com
  `aboutConfiguration`, substitui o item "Sobre" do menu do aplicativo pela
  tela Sobre do kit.
- Mac: Feedback, Roadmap e o detalhe se atualizam sozinhos nas janelas do kit
  (mudanças de status, itens publicados e comentários aparecem sem reabrir a
  tela) e pausam enquanto o aplicativo está oculto (⌘H). Fora de uma cena
  SwiftUI o `scenePhase` fica sempre em `.background`, por isso o Mac não
  depende dele.
- Mac: o botão "Fechar" só aparece dentro de sheets; em janelas, do kit ou do
  próprio aplicativo (tela incorporada), vale o botão de fechar da janela. A
  barra de Feedback e Roadmap fica sobre a divisão inteira, do lado do
  detalhe, com a mesma cor nas duas colunas. Conta e Perfil abrem em janelas
  só com o botão de fechar.
- Mac: a lista de Feedback ganha uma linha própria, no estilo do Mail: autor e
  data, título, descrição, status, prioridade, comentários e o voto, com
  destaque no item escolhido. No Mac, o voto da pessoa aparece preenchido com
  a cor de destaque; sem voto, a cápsula é neutra, com contorno. Vale também
  para o voto no detalhe e nos comentários, e "Responder" vira texto simples
  na cor do sistema. O botão de anexar imagem usa a
  cor do sistema.
- Mac: estados vazios e de erro (sem novidades, sem avaliações, sem
  resultados, falha de carga) aparecem direto sobre o fundo da janela, sem a
  caixa com contorno.
- Mac: o compositor de feedback vira um formulário agrupado do sistema: tipo
  em cartões com ícone (duas colunas, selecionado realçado na cor do sistema),
  título e descrição em seções, imagens em miniaturas
  menores e uma única barra no rodapé com Cancelar (Esc) e Enviar (⌘↩), sem
  o botão Fechar nem o menu de idioma da sheet.
- Mac: a conta abre direto no login, sem a tela de boas-vindas nem botão de
  voltar. O rodapé leva do login ao cadastro ("Não tem uma conta? Criar conta")
  e do cadastro ao login ("Já tem uma conta? Conectar"). Recuperar senha e as
  etapas de código também não têm a seta de voltar: o link "Voltar para o
  login" no fim da tela leva de volta. "Esqueci minha senha" vira link.
- Mac: em Feedback e Roadmap, autor sem foto mostra as iniciais, como no
  detalhe, em vez do ícone genérico. Filtro e ordenação usam a cor do sistema.
- Mac: em Feedback, Roadmap e Changelog, idioma, conta, busca e ações da barra só
  aparecem depois que a primeira carga traz a cor do projeto, sem piscar na
  cor padrão. Fechar continua sempre visível.
- Demo: novo app `UAPPKitDemoMac` (macOS 14+) para testar as janelas, o menu
  Ajuda e a foto de perfil no Mac.

## 1.11.0 - 2026-10-18

- Login com Apple, Google e GitHub: o endereço de retorno passa a ser único para
  todos os aplicativos, `UAPPAuthentication.defaultCallbackURL`
  (`uappkit://authentication`), e é o padrão de `callbackURL` em
  `UAPPKit.makeAuthentication`, `UAPPAuthentication.automatic` e
  `UAPPAuthenticationConfiguration`. O aplicativo não registra mais esquema em
  URL Types nem pede a habilitação de um endereço próprio. Quem já informa um
  `callbackURL` continua funcionando.

## 1.10.0 - 2026-10-16

- Login com a Apple: depois da troca do código, o `provider_refresh_token`
  devolvido pelo UAPP segue para a função `apple-signin-token`, que o confere
  com a Apple e guarda cifrado no servidor para revogar o acesso quando a
  conta for excluída, como a Apple exige. O token não entra na sessão guardada
  no Keychain, e uma falha nesse envio não impede o login. Os demais
  provedores não mudam.

## 1.9.1 - 2026-10-16

- Sobre: a descrição do aplicativo passa a ficar alinhada à esquerda, o que
  facilita a leitura de textos longos e com listas. Ícone, nome e versão
  continuam centrados.

## 1.9.0 - 2026-10-15

- Feedback e Roadmap: quem usa o aplicativo passa a ver a prioridade e as
  etiquetas da requisição, como a equipe vê na gestão. O detalhe mostra o selo
  de prioridade, que antes aparecia só no card, e as etiquetas aplicadas; o
  card mostra as etiquetas abaixo do texto. As etiquetas são selos somente
  leitura que quebram em linhas, com um ponto na cor da etiqueta e o nome no
  texto principal do tema, legível em claro e escuro. Sem cor válida, a
  etiqueta usa a cor neutra do tema. Itens sem prioridade nem etiquetas ficam
  como antes.
- Novo tipo público `UAPPFeedbackTag` (`id`, `name` e `color` opcional em
  hexadecimal, como `#RRGGBB`) e nova propriedade `UAPPFeedbackItem.tags`.
  O inicializador público de `UAPPFeedbackItem` ganha o parâmetro `tags`, por
  último e com padrão `[]`, então o código existente continua compilando.
  Respostas de servidores que ainda não enviam `tags` decodificam lista vazia.
- Leitores de tela anunciam "Prioridade: …" e "Etiqueta: …" nos 13 idiomas.

## 1.8.0 - 2026-10-15

- `UAPPFeedbackComposerScreen(draft:theme:submit:onComplete:)`: novo
  inicializador que mostra o mesmo compositor nativo (tipo, título, descrição,
  anexos e botão Enviar) sem `UAPPClient`; o aplicativo envia a requisição
  pela própria função `submit`, por exemplo para o seu backend. Se `submit`
  lançar um erro, o compositor continua aberto e mostra o aviso de falha, com
  o texto de `LocalizedError.errorDescription` quando houver, ou a mensagem
  genérica de sempre. `onComplete` só é chamado depois de um envio sem erro.
- Novo tipo público `UAPPFeedbackSubmission` (`title`, `details`, `category`,
  `imagesData`), entregue a `submit` com título e descrição sem espaços nas
  pontas e os anexos já compactados.
- O inicializador com `client:` e o envio pela lista de Feedback continuam
  iguais.

## 1.7.1 - 2026-10-15

- `UAPPUserScreen`: o botão de editar perfil sai do cabeçalho e vai para a
  barra de navegação, entre sair e o idioma, como ícone de lápis na cor de
  destaque. O cabeçalho fica só com foto, nome e e-mail.

## 1.7.0 - 2026-10-14

- `UAPPUserScreen(session:authentication:client:theme:onSessionChange:onEditProfile:)`:
  novo parâmetro opcional `onEditProfile`. Quando informado, o cabeçalho da
  conta conectada mostra um botão com lápis, na cor de destaque, com o rótulo
  "Editar perfil" nos 13 idiomas; o aplicativo apresenta o próprio editor. Sem
  a ação, a tela fica como antes. Quando o aplicativo passa uma sessão
  atualizada da mesma conta, a tela passa a exibi-la, com o novo nome.
- Perfil: a estatística "Feedbacks" passa a se chamar "Requisições", o
  histórico vira "Histórico de requisições" e a lista vazia fala em
  requisições, o termo usado pelo UAPP. As chaves não mudaram; os 13 idiomas
  foram atualizados (por exemplo, "Requests" e "Request history" em inglês).

## 1.6.0 - 2026-10-14

- `EnvironmentValues.uappSystemTranslationEnabled` passa a ser público: o app
  pode desligar a tradução automática do sistema em avaliações, requisições e
  na biografia da tela Sobre, como nos testes, em que o framework Translation
  tenta mostrar um erro sem cena e derruba o processo.

## 1.5.2 - 2026-10-12

- Acessibilidade: o tamanho máximo de texto das telas do pacote baixa de
  `xxxLarge` para `xLarge`, o mesmo teto do UAPP Pulse.

## 1.5.1 - 2026-10-12

- Acessibilidade: as telas do pacote acompanham o tamanho de texto do sistema
  até o maior tamanho comum e param aí, para os cartões não quebrarem.
  Transições com deslize ou escala viram esmaecer com Reduzir Movimento.
  Textos de uma linha encolhem antes de cortar. O botão de fechar do aviso ao
  deslizar tem rótulo para o VoiceOver e a seta decorativa da lista de
  novidades deixou de ser lida.
- O cache de imagens gravado pelos testes saiu do repositório.

## 1.5.0 - 2026-10-12

- Avisos (`uappToast`): novo visual em cápsula de vidro, com ícone, título e
  mensagem, gradiente suave na cor do tipo. A transparência é a do vidro do sistema e
  segue o que a pessoa escolheu em Ajustes. O aviso flutua
  sobre a tela em vez de empurrar o conteúdo, entra por baixo e sai para o
  lado. Fecha ao tocar ou ao deslizar (ação de deslizar do sistema no iOS 27;
  arrasto nas versões anteriores); o botão de fechar saiu. Sem `title`, o aviso
  usa o título do tipo: "Erro", "Concluído" ou "Aviso", nos 13 idiomas.
  O aviso que fecha sozinho mostra à direita um anel que se esvazia, com os
  segundos que faltam.

## 1.4.2 - 2026-10-12

- Tradução automática: textos curtos de idioma incerto, como "Bug" ou "Dark
  mode", e textos só com termos de produto (Bug, Roadmap, Changelog, Feedback,
  Login) ficam como foram escritos. Antes a tradução falhava e aparecia o aviso
  "Tradução indisponível. Exibindo o original."

## 1.4.1 - 2026-10-09

- Tela de conta: Termos de uso e Política de privacidade ficam lado a lado, com
  espaço entre eles; quando não cabem (texto ampliado ou tela estreita),
  continuam um abaixo do outro.

## 1.4.0 - 2026-10-09

- Votar em um pedido ou em um comentário solta joinhas subindo do botão;
  retirar o voto solta joinhas para baixo, descendo. No iOS o efeito passa por
  cima da célula e do cartão, sem ser cortado. Respeita Reduzir Movimento e
  também está disponível para botões próprios com
  `.uappVoteBurst(isSelected:tint:)`.
- Tela de conta: no iPad em retrato, abrir o teclado não divide mais a tela em
  duas nem fecha o teclado; o formulário de entrar e de criar conta fica
  centralizado nas telas largas.

## 1.3.1 - 2026-10-09

- Tela de Reviews: o cartão de resumo ficou mais legível, com as estrelas na cor
  de destaque, o total escrito por extenso ("20 avaliações") e a quantidade ao
  lado de cada nota. A lista de avaliações virou um bloco de cantos
  arredondados, com a mesma largura do resumo.

## 1.3.0 - 2026-10-09

- A tela Sobre mostra a descrição do aplicativo configurada no UAPP
  (`UAPPAbout.appDescription`), com formatação Markdown e tradução para o
  idioma de apresentação. Ela tem precedência sobre `shortDescription`, que
  continua valendo quando o projeto não tem descrição configurada e passa a
  aceitar Markdown também.

- Na tela Sobre, a linha Suporte abre uma folha inferior com os motivos do
  contato no lugar do menu.

## 1.2.0 - 2026-10-09

- Controles das telas do pacote disponíveis para o aplicativo montar as
  próprias listas: `UAPPTranslatedText` (texto traduzido para o idioma de
  apresentação), `UAPPLanguageMenuButton` (menu de idiomas),
  `uappTranslationScope()` (mantém as traduções da tela e aplica o idioma) e
  `uappSearchField(text:isPresented:prompt:accentColor:)` (busca aberta por
  botão, na barra de ferramentas a partir do iOS 26).
- `UAPPImageAttachmentPicker` (até duas imagens, preparadas em JPEG de até
  512 KB) e `UAPPImageAttachmentGallery` (miniaturas que abrem em tela cheia)
  para anexos em telas do aplicativo.
- `UAPPRequestStatusTitle.localized(key:fallback:)` devolve o nome de uma
  etapa padrão no idioma de apresentação.

- A tela de Reviews mostra no topo um cartão com a média, as estrelas, o total
  e a distribuição por nota. `UAPPReviewsPage.summary` traz o resumo quando o
  servidor o informa; sem ele, o pacote lê as notas em uma página de até 50
  avaliações e mostra o cartão quando ela traz todas.
- `UAPPSocialNetworkIcon` expõe as marcas das redes sociais do perfil do
  desenvolvedor para uso em telas do aplicativo.
- A biografia do desenvolvedor passa a exibir formatação Markdown: negrito,
  itálico, títulos e listas.

- `UAPPProfilePhotoPicker(photo:remoteURL:size:theme:languageIdentifier:onRemove:)`
  apresenta só o avatar editável, com a foto remota enquanto não há uma
  escolhida e a opção de remover no menu.

- Os cards de Feedback e de Roadmap mostram a prioridade definida pela equipe
  (baixa, média, grande, muito grande, importante ou urgente). `UAPPFeedbackPriority`
  e `UAPPFeedbackPriorityBadge` ficam disponíveis para telas do aplicativo.

- `UAPPAboutConfiguration` ganhou `showsReviews` e `reviewsPageSize`: a tela
  Sobre mostra a ação que abre a lista de avaliações do aplicativo em uma
  sheet, como o Changelog.
- A linha Suporte da tela Sobre usa o e-mail de suporte configurado no UAPP
  para o projeto (`UAPPAbout.supportEmail`) e abre uma mensagem para ele; sem
  e-mail configurado, continua valendo `supportURL`.
- Com e-mail de suporte, a linha Suporte oferece o motivo do contato (dúvida,
  problema ou sugestão) e abre a mensagem com o assunto `[App] [Motivo] - ` e,
  no corpo, a versão e o build do aplicativo, o sistema, o modelo do aparelho e
  o idioma. Sem app de e-mail no aparelho, um aviso mostra o endereço.

## 1.1.0 - 2026-10-07

- `UAPPAccountScreen` ganhou o parâmetro opcional `onReady`, chamado uma vez
  quando o formulário de login aparece. Permite ao aplicativo manter a própria
  tela de abertura até o login estar pronto. Não é chamado quando já existe
  sessão, caso em que a tela se encerra sozinha.
- Nova tela pública `UAPPFeedbackComposerScreen(client:draft:theme:onComplete:)`
  e o tipo `UAPPFeedbackDraft`, para o aplicativo abrir o envio de feedback já
  preenchido com título, descrição e tipo, sem passar pela lista de Feedback.
  A pessoa pode revisar e alterar o conteúdo antes de enviar.
- Novo modificador público `uappToast(message:kind:title:actionTitle:action:)`
  para avisos de erro, informação e sucesso, com ações de recuperação,
  fechamento acessível, Dynamic Type e respeito à redução de movimento.
  Autenticação, perfil, foto, votos, comentários, envio de feedback e avaliação
  do app usam o componente. Falhas de carregamento preservam o estado com retry.
  A adaptação do helper StackedToasts mantém iOS 18+ e macOS 13+, com material
  nativo e efeito glass somente em sistemas/SDKs compatíveis.
- O layout de autenticação usa fallback de dois painéis quando o compilador
  não oferece as APIs do Duo, preservando o alinhamento vertical dos campos.

## 1.0.0 - 2026-10-06

- Cadastro e troca de senha exigem pelo menos oito caracteres, uma letra
  maiúscula e um caractere especial. A orientação está traduzida nos 13 idiomas
  e a regra é compartilhada entre telas e provedor; login preserva senhas antigas.

- Os símbolos do acessório de navegação do teclado usam a cor de destaque do
  tema fornecido, respeitando a cor padrão quando nenhuma personalização existe.

- Novo modificador reutilizável `uappKeyboardFieldNavigation`, com controles
  localizados para ir ao campo anterior/próximo e fechar o teclado. Aplicado aos
  fluxos de conta, criação de feedback e comentários.

- A etapa “Esqueceu a senha?” preserva o ícone do aplicativo no cabeçalho, em vez
  de substituí-lo pelo símbolo de chave usado nas demais etapas da conta.

- Em largura regular e orientação horizontal, login e cadastro mostram a marca
  do aplicativo no painel primário e os campos/serviços de autenticação no
  painel secundário. `ArrangementView` adapta a divisão a regiões reservadas no
  iOS 27.1 ou posterior; os demais tamanhos e etapas mantêm uma coluna.

- Campos de senha e confirmação da tela de conta permitem alternar entre texto
  oculto e visível, com ações acessíveis e localizadas.

- Novo inicializador `UAPPClient(accountActivityHost:)` para consultar o histórico
  global de uma conta autenticada sem configurar ou enviar um slug de aplicativo.

- O transporte padrão limita cada requisição a 15 segundos, cancela a espera
  e retorna erro de comunicação com mensagem de tempo limite. Novo parâmetro
  opcional `URLSessionTransport(session:timeoutInterval:)`, compatível com as
  chamadas existentes. O Demo encerra o indicador de teste de conexão ao
  receber sucesso ou erro e impede testes simultâneos.

- No iOS, `UAPPUserScreen(session:authentication:...)` permite trocar a foto da
  conta tocando no avatar, quando o provedor declara `supportsProfilePhoto`.
  O kit reutiliza o seletor/recorte e `uploadProfilePhoto(_:)`, mostra a última
  foto definida durante e após o envio, entrega a sessão atualizada em
  `onSessionChange` e preserva a foto anterior se o envio falhar. Sem mudança
  de API pública nem de backend. A foto escolhida também é gravada em
  `uapp_avatar_url`, que tem prioridade sobre `avatar_url`/`picture`; assim,
  um novo login com Apple, Google ou GitHub não substitui a última foto definida.

- Nova view pública `UAPPRoadmapScreen(client:)`. `UAPPKit.showRoadmap` passa a
  apresentá-la, e `UAPPFeedbackScreen(client:mode: .roadmap)` continua
  disponível, delegando à mesma view. No Roadmap, o card mostra o tipo e o voto
  na primeira linha, título, descrição de até três linhas e o autor abaixo,
  sem badge de status nem comentários. Mudança aditiva.

- Perfil local aberto pela toolbar consulta votos, comentários e histórico
  públicos da instalação, sem login. Novo inicializador
  `UAPPUserScreen(profile:client:theme:)` e consulta `participationProfile()`.

- Perfis locais podem entregar a foto diretamente em `UAPPIdentity.avatarData`,
  com default `nil` e fallback compatível para `avatarURL` local. O Demo passa
  os bytes salvos ao enviar feedback; o cadastro de usuários inclui perfis com
  nome/e-mail mesmo sem autenticação e exibe o avatar.

- Feedback e roadmap do Demo usam o perfil local salvo sem solicitar login,
  mostram sua foto na toolbar e enviam nome, e-mail e foto no novo feedback.
  Avatares locais são carregados sem rede; o backend persiste a foto no cadastro
  do autor. A autenticação dentro do feedback usa a tela geral de conta.

- Perfil público do autor usa a mesma foto atual da conta exibida no feedback.
  Fotos removidas não são recuperadas de perfis ou identidades antigas.

- Participação apresentada somente como votos no perfil, histórico, comentários,
  notificações e traduções. Estatísticas de conta recebem `totals.votes`; o
  histórico público recebe `vote_count`. Campos legados de transporte são
  preservados, e `UAPPReactionKind.like` foi descontinuado em favor de `.vote`.

- Foto de comentários próprios acompanha a sessão da barra superior, com autoria
  confirmada pelo campo opcional `viewerOwned`, sem comparar nomes de usuários.
- Corrigida a reação dos cards de Feedback e Roadmap: a seta passa a salvar
  votos, usando a mesma contagem e seleção dos detalhes e da web. Ordenação
  por votos acompanha essa correção; campos legados continuam compatíveis.

- Anexos nos detalhes aparecem menores e lado a lado, preservando a imagem
  carregada quando a assinatura da URL é renovada. Visualizador com fundo preto
  e botão `xmark` no canto superior esquerdo.
- Versão mínima de iOS/iPadOS elevada para 18 no pacote e no Demo, incluindo
  seu target de testes. Aplicativos consumidores precisam usar iOS 18+;
  a versão mínima de macOS permanece 13.

- Atualização ao vivo nas sheets de feedback acompanha a atividade do aplicativo
  no iOS, inclusive quando o hospedeiro não propaga o estado da cena.
- Descrição dos cards limitada a três linhas; título, descrição e comentários
  públicos usam a tradução dinâmica existente. Status, formulário e mensagens
  acompanham a troca de idioma.

- Feedback, Roadmap, detalhes e participação no perfil acompanham alterações
  públicas ao vivo por aplicativo, incluindo votação, comentários, novos itens,
  exclusões e mudanças de status. Reconciliação preserva filtros e páginas do perfil.
- Detalhes de feedback recebem invalidações ao vivo para comentários publicados,
  aprovados, editados ou removidos, com reconexão e consulta periódica de reserva.
- Compositor com clipe/envio mais próximos da borda inferior, avatares de
  comentários menores e ação Responder mais próxima do texto. Comentários
  pendentes ocultam corpo/anexo com skeleton até a publicação ser aprovada.

- Badges de status compartilham as mesmas cores em Feedback, Roadmap, detalhes
  e perfil. Filtros mostram anéis coloridos pela posição da etapa no roadmap.
  Perfil público usa lista contínua, filtro de status no servidor e navegação
  para os detalhes do feedback após expandir a sheet.
- Correção do carregamento de comentários com datas ISO 8601 contendo frações
  de segundo e da consulta inicial ao abrir os detalhes; falhas mostram opção
  de tentar novamente na conversa.
- Badges de votos e botão de envio com altura visual de 32 pontos, mantendo
  área de toque de 44 pontos; envio usa avião de papel e anexo mostra só o clipe.

- Detalhes do feedback com autor/data, descrição completa, status, últimos cinco
  votantes e total de votos; comentários com perfis, respostas e reação por seta.
- Até duas imagens por feedback/comentário, compactadas em JPEG de até 512 KiB
  e 1600 pixels cada. Botão de remover sobre o canto superior direito da prévia;
  novas APIs com `imagesData:` e `imageURLs`, preservando as variantes de uma imagem.
- Atualização da conversa após envio/reação, ao voltar ao primeiro plano e a
  cada 15 segundos na tela ativa, incluindo todas as páginas e a moderação.

- Perfil público inclui feedbacks do autor com título, status, data e paginação.
  `authorProfile(for:cursor:)` mantém chamadas existentes pelo cursor opcional;
  `items` e `nextCursor` são aditivos e aceitam respostas anteriores sem a lista.
  Badge de votos com largura reduzida.
- Perfil público do autor mostra nome completo e estatísticas de participação
  pública no aplicativo por `UAPPClient.authorProfile(for:)`, sem e-mail, sessão
  ou conteúdo pendente/interno. Badge de votos mais baixo e alongado.
- Badge de votos com resposta imediata, navegação independente para perfil
  público e comentários, cards sem chevron e mascote para filtros sem resultados.
  `UAPPUserScreen(publicIdentity:theme:)` mostra nome/foto sem e-mail ou sessão.
- Cards de Feedback e Roadmap com autor, foto, votos com seta para cima,
  badge de status e comentários; filtros por categoria/status e ordenação local
  por data, votos ou comentários. Corações removidos, com API preservada.
- Metadados públicos opcionais de autor/status e status na página de feedback,
  compatíveis com payloads anteriores. Cores de status compartilhadas nas telas.
- Perfil conectado com nome abreviado e e-mail ao lado da foto, sem badge e
  seção duplicada. `UAPPDisplayName.abbreviated` compartilhado com o Demo.
- Cards de participação e histórico paginado da conta em todos os aplicativos
  vinculados no mesmo serviço, com sistema, data e status de cada feedback.
  API autenticada `UAPPClient.userActivity(session:limit:cursor:)`.
- Imagens remotas no kit e no Demo usam cache compartilhado, downloads
  deduplicados e indicador em círculo cinza claro durante o carregamento.
  Inclui perfis, ícones, Sobre, Changelog e pré-carregamento da autenticação.
- Seletor de foto aceita idioma explícito e acompanha a escolha do Demo no
  perfil manual e a escolha da apresentação no cadastro, incluindo textos e menus.
- Sheets de conta, perfil e resultado da configuração do Demo recebem
  explicitamente o idioma selecionado, evitando abrir o login no idioma do sistema.
- Foto opcional no cadastro por e-mail, com recorte circular, envio após
  confirmação e atualização do avatar na sessão persistida. Falhas de envio
  permitem tentar novamente sem repetir o cadastro. Câmera com permissão sob
  demanda e atalho para os Ajustes quando o acesso estiver negado.
- Autenticação e perfil acompanham a seleção de idioma da apresentação.
  Textos de conta e foto traduzidos nos 13 idiomas; locales regionais normalizados.
- `UAPPProfilePhotoPicker` no iOS: biblioteca ou câmera, recorte circular com
  Mantis e compressão JPEG em até 512 pixels. Demo reutiliza o componente do kit.
- Sessão de autenticação persistida no Keychain, com restauração no Demo,
  renovação de tokens e remoção ao sair. Registros separados por servidor/projeto.

- `UAPPUserScreen` e `UAPPKit.showUser` para consultar foto, nome e e-mail da
  conta conectada e sair. Demo abre a sheet de altura média ao tocar na conta.

- Autenticação aguarda os dados e a imagem do aplicativo, oferece uma escolha
  inicial entre login e cadastro com navegação de retorno e fecha ao conectar.
- Demo mostra a conta conectada e permite sair pela tela principal.

- `UAPPAccountScreen` pública com identidade visual do aplicativo, login,
  cadastro, confirmação de e-mail e recuperação de senha. Provedor automático
  e ícones dos serviços movidos para o kit; Demo consome a interface pública.
- APIs aditivas de cadastro/recuperação com implementações padrão no protocolo,
  preservando adaptadores existentes. Alteração ainda não lançada e não
  compilada/testada, conforme preferência do proprietário.

- Demo usa e-mail e senha para conectar a conta do aplicativo. O provedor ganha
  `signIn(email:password:)` com implementação padrão opcional, preservando
  compatibilidade com provedores existentes; senhas não são persistidas.

- Demo com conta do aplicativo por e-mail, Google, Apple e GitHub, compartilhada
  com Feedback/Roadmap; perfil local persistido com nome, e-mail e foto opcional.

- Login padrão de Feedback/Roadmap simplificado: configuração automática, e-mail com código somente ao participar e conta compartilhada entre as telas.
- Demo conectado ao fluxo padrão sem chave/provider/callback; cliente `makeParticipationClient()` para navegação própria.
- Serviço público de configuração publicado em PRD/DEV e código de confirmação de primeiro acesso incluído nos dois ambientes.

- Nome público do login opcional: `UAPPAuthentication` e `UAPPAuthenticationConfiguration`, sem referência ao fornecedor de infraestrutura. Renomeação da API ainda não lançada, sem mudança de comportamento.

- Autenticação informada ao abrir Feedback/Roadmap, com cliente isolado por apresentação; setup e leituras de Sobre, Changelog e Reviews independentes de access token.

- Checklist das telas Sobre o desenvolvedor, Sobre o aplicativo, Changelog e Reviews atualizado.
- Feedback e Roadmap com busca local e cor de destaque compartilhada por fechar, idioma, formulário e detalhes.
- Perfil opcional com URL de foto e ponte injetável de access token para reaproveitar a sessão do app cliente.
- Provider de autenticação do hospedeiro e login nativo opcional por Apple, Google, GitHub e código por e-mail, fornecidos ao abrir Feedback/Roadmap.
- Conta confirmada com foto, logout, renovação de sessão e retomada da ação após login; textos nos 13 idiomas do kit.
- Backend publicado em PRD/DEV com vínculo por aplicativo/sujeito validado e autoria/cache separados na troca de conta; login real no app consumidor ainda pendente.

- Destino dos detalhes do changelog registrado fora da lista para compatibilidade com a navegação SwiftUI.
- Correção do carregamento de traduções interrompidas no changelog, com reutilização do cache e tradução das linhas em lote.
- Indicador de páginas com cápsulas que interpolam largura e cor conforme a rolagem do carrossel.
- Datas de lançamento localizadas conforme o idioma selecionado na lista e nos detalhes do changelog.
- Pesquisa flutuante nativa com Liquid Glass no iOS 26+, destaque nas versões e ordenação decrescente.
- Parallax das imagens durante a rolagem no iOS 17+, preservando a imagem inteira em repouso.
- Changelog nativo com imagens por item, carrossel, pesquisa local e detalhes completos por versão.
- Reprodução automática opcional com intervalo configurável, indicadores de página e transição do texto.
- Decodificação compatível de `description_md` e `image_url`, com ordenação estável dos itens.
- Preparação do repositório independente e da primeira versão pública.
