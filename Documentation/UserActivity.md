# Conta e participação global

`UAPPUserScreen` apresenta foto, nome abreviado e e-mail uma única vez. Abaixo,
exibe os totais e o histórico da conta em todos os aplicativos associados ao
mesmo usuário autenticado no serviço configurado. O aplicativo que abriu a
sheet não limita os resultados. Contas de serviços de autenticação diferentes
não são agrupadas por e-mail ou nome.

Os totais representam votos ativos feitos em feedbacks ou comentários,
comentários enviados (sem os internos) e feedbacks criados pelo usuário.
Incluem a participação nos aplicativos vinculados à conta; não representam
votos recebidos nem somente os itens da página atual do histórico.
Registros excluídos não são contados.

O histórico traz os feedbacks do próprio usuário, do mais recente ao mais
antigo, com aplicativo, data de criação e status atual. Envios em curadoria
aparecem como aguardando aprovação. Conteúdo arquivado ou não publicado é
identificado; informações internas de moderação não são expostas. As páginas
usam cursor por data/ID e o botão de carregar mais. Totais não carregados
aparecem como `—`, com erro e nova tentativa quando necessário.

Ao usar a view diretamente, forneça um `UAPPClient`:

```swift
UAPPUserScreen(
    session: session,
    authentication: authentication,
    client: try UAPPKit.makeClient()
)
```

Para apps de administração que mostram a atividade global da conta sem
representar um aplicativo UAPP específico, crie um cliente restrito a esse
histórico com o host do ambiente desejado:

```swift
let activityClient = UAPPClient(accountActivityHost: serverURL)
UAPPUserScreen(
    session: session,
    authentication: authentication,
    client: activityClient
)
```

Esse cliente não exige nem envia um slug de aplicativo e deve ser usado somente
para a atividade da conta.

`UAPPKit.showUser` fornece o cliente configurado automaticamente. A inicialização
sem cliente continua compatível, mas não consulta atividade. A sheet abre em
altura média e pode ser expandida. O botão vermelho de saída permanece na barra.

### Editar perfil

O aplicativo pode oferecer a edição do perfil com o próprio editor. Ao informar
`onEditProfile`, o cabeçalho da conta conectada mostra um botão com lápis, na
cor de destaque do tema e com o rótulo "Editar perfil" nos idiomas do pacote.
Sem a ação, nada muda. Perfis públicos e o perfil local nunca mostram o botão.

```swift
UAPPUserScreen(
    session: session,
    authentication: authentication,
    client: try UAPPKit.makeClient(),
    onSessionChange: { accountModel.session = $0 },
    onEditProfile: { isEditingProfile = true }
)
```

Depois de salvar, passe a sessão atualizada em `session` (por exemplo, a de
`authentication.currentSession()`). A tela adota essa sessão quando ela é da
mesma conta e mostra o novo nome sem ser reaberta.

`UAPPClient.userActivity(session:limit:cursor:)` consulta o endpoint autenticado
`public-user-activity`. A identidade é validada pelo token no servidor: o
aplicativo não escolhe um usuário por ID, e-mail ou instalação. Cada consulta
de participação é limitada aos vínculos desse usuário em `app_end_users`.
As respostas usam `Cache-Control: no-store`.

As estatísticas usam `totals.votes`; o histórico público usa `vote_count`.
Campos legados permanecem decodificáveis por compatibilidade e não alimentam
as contagens de votos dos feedbacks. Comentários expõem `voteCount` e
`viewerVoted`, preservando os nomes antigos apenas no transporte. Chamadas
legadas a `UAPPReactionKind.like` são convertidas em `.vote` pelo cliente.

`UAPPDisplayName.abbreviated(_:)` é compartilhado entre o kit e o Demo.
Quando existem mais de três nomes, preserva o primeiro, o segundo e o último;
os intermediários viram iniciais. Partículas `de`, `da`, `do`, `das`, `dos`,
`e` e `d'` permanecem inteiras e não entram nessa contagem. O perfil original
não é modificado, e a acessibilidade mantém o nome completo.
