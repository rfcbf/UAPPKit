# Changelog nativo

O contrato HTTP continua usando `public-feedback`, `resource=changelog` e o
slug do projeto. Nenhuma alteração no painel ou no backend é necessária.

## Integração

```swift
try UAPPKit.showChangelog(
    configuration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10)
)
```

Para integração SwiftUI própria, dentro de um `NavigationStack`:

```swift
UAPPFeedbackScreen(
    client: client,
    mode: .changelog,
    changelogConfiguration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10)
)
```

Para o changelog aberto pela tela Sobre do app:

```swift
try UAPPKit.showAbout(configuration: .init(
    showsChangelog: true,
    changelogConfiguration: .init(automaticallyScrolls: true, interval: 5, pageSize: 10)
))
```

`pageSize` define os registros por página na primeira requisição, nas próximas
páginas e nas tentativas após falha. O padrão é 10, e valores fora da
faixa de 1 a 50 são ajustados aos limites aceitos pela API.

As chamadas existentes sem configuração continuam válidas. A reprodução
automática está desativada por padrão. O intervalo mínimo é um segundo; valores
não finitos usam cinco segundos. Depois da última imagem, o carrossel volta à
primeira. Com uma imagem, não há temporizador nem indicador de páginas.
VoiceOver e Reduzir Movimento suspendem a reprodução automática. A interação
manual reinicia o intervalo e a saída da tela cancela o temporizador.
O temporizador acompanha as notificações de atividade do aplicativo, incluindo
apresentações via `UIHostingController`, sem depender da cena SwiftUI herdada.
No demo recompilado para iPhone 18 Pro, foi confirmado o avanço automático
entre duas imagens a cada cinco segundos, com atualização do texto e indicador.

## Conteúdo e compatibilidade

O cabeçalho exibe a versão uma única vez, como “Versão: 2.0”, na cor de
destaque e no idioma selecionado. A linha abaixo contém apenas a build.
Entradas antigas sem número de versão preservam o título recebido da API.

Descrições gerais, itens com ou sem imagem e títulos legados usam a tradução
automática nativa já utilizada nas avaliações, para o idioma selecionado.
O cache é compartilhado entre a lista e os detalhes e separado por texto e
idioma. O cache é repassado explicitamente à navegação para os detalhes e
permanece disponível quando as células são recriadas pela rolagem. Traduções
concluídas são reutilizadas sem novas chamadas. Os detalhes aguardam uma
tradução já em andamento; se a tarefa da célula for cancelada, retomam o trabalho.
O cancelamento libera imediatamente o estado de carregamento, mesmo que a sessão
antiga ainda não tenha retornado. Uma resposta atrasada dessa sessão não substitui
a tradução nova, e cancelar uma tela que aguarda não cancela o trabalho de outra.
O Markdown e o limite de três linhas da lista são preservados. A tradução
recebe todas as linhas de cada texto em um único lote, sem os marcadores de lista ou de título;
esses marcadores e as quebras de linha são reconstruídos a partir do original,
evitando que o serviço introduza linhas vazias entre itens numerados.
No iOS 18+/macOS 15+, o sistema pode solicitar o download dos idiomas;
em sistemas anteriores ou quando a tradução falha, o original permanece
disponível. Durante a tradução, o texto mostra o mesmo placeholder das avaliações.
O simulador apresenta a limitação do sistema “Translation is not supported on
simulated devices”; a tradução real precisa ser conferida em um aparelho físico.
Os testes de sucesso, erro, Markdown e cache usam traduções injetadas, sem rede.

`UAPPChangelogEntry.descriptionMarkdown` é opcional e representa `description_md`.
Quando ausente, a apresentação usa `bodyMarkdown` e evita repetir os itens
textuais que já fazem parte dele. `sections` ausente vira uma lista vazia.
Cada seção aceita `imageURL`, opcional; URLs inválidas ou sem HTTPS viram `nil`
sem invalidar a entrada. Posições ausentes usam a ordem original na apresentação
e empates preservam essa ordem. Categorias repetidas são itens independentes.

Imagens são carregadas de forma assíncrona, com estados de carregamento e falha.
A área acompanha a largura disponível em 40:21. `scaledToFit` preserva imagens
antigas com outras proporções, sem cortar o conteúdo. A lista usa carrossel
nativo com parallax no iOS 18+ e seleção por
indicadores no macOS 13. Durante a rolagem, a imagem se desloca em sentido
contrário dentro do cartão; ao parar, a proporção original fica inteira. A descrição do
item selecionado muda com transição de opacidade. Os itens sem imagem aparecem
com marcadores por categoria, separados da descrição geral.

O indicador usa cápsulas de oito pontos de altura: a página ativa tem largura
de 26 pontos e as demais, oito. Ao rolar no iOS 18+, os 18 pontos extras e a cor
ativa passam gradualmente da cápsula atual para a próxima, conforme o progresso
real do carrossel. Tocar em uma cápsula seleciona sua imagem. No macOS,
a transição acompanha a seleção. Com Reduzir Movimento, o destaque
acompanha a página selecionada sem animação; zero ou uma imagem não mostram
indicador. Cada controle mantém o rótulo de página localizado para VoiceOver.

O botão de pesquisa filtra versão, título e descrições nas páginas já carregadas,
ignorando diferenças de caixa e acentos. Ao chegar ao fim da lista, as versões
anteriores são carregadas automaticamente em páginas de até 50 entradas,
inclusive durante a pesquisa. O rodapé mostra o carregamento ou uma ação de
tentar novamente em caso de erro. Entradas repetidas são removidas pelo slug;
o carregamento termina quando não há cursor ou quando ele se repete.
Testes com transporte falso cobrem o fim da lista, duplicatas, falha e retry,
cursores cíclicos, páginas vazias e requisições concorrentes. Nesta validação,
a rolagem visual da amostra ficou pendente porque a automação do simulador
não respondeu às interações; o modelo e os estados do rodapé foram testados.
O detalhe apresenta todos os itens completos em
ordem, sem carrossel, e inclui a ação Voltar.
A seleção e o destino de navegação pertencem à tela, fora da `List` e das
células criadas sob demanda. Os cartões apenas solicitam a abertura da versão,
e Voltar limpa a seleção mantendo o cache compartilhado de traduções.
Seu título é “Versão 2.0”, sem repetir a versão no conteúdo: a build inicia o
texto da tela, seguida da data e da descrição. Voltar usa a mesma cor de
destaque da lista. O Markdown preserva quebras de linha, parágrafos, marcadores,
numeração, títulos, negrito, itálico e links, inclusive após tradução.
O detalhe foi conferido visualmente no mesmo simulador: título localizado,
build no início do conteúdo, Voltar na cor de destaque, numeração e marcadores
com negrito preservados.

No iOS 26+, o campo fica oculto até tocar na lupa. Cancelar ou tocar na lupa
novamente fecha o campo e limpa o filtro. A pesquisa usa `searchable` e
`DefaultToolbarItem` na barra inferior,
com o campo flutuante e Liquid Glass fornecidos pelo sistema. Nas versões
anteriores e no macOS 13, o campo aparece sobre o conteúdo na área inferior.
Não há célula explicativa na lista. A lupa, os títulos e os números das versões
usam a cor de destaque do tema.

A data de lançamento acompanha o idioma selecionado no menu da tela, na lista
e nos detalhes, usando o formato de data médio do sistema. A data ISO recebida
é interpretada como um dia civil em UTC para evitar mudanças de dia por fuso
horário. Valores inválidos permanecem legíveis no formato recebido.

A lista ordena as versões em ordem decrescente, com comparação numérica
(`2.10` antes de `2.9`). Data de lançamento, publicação e build resolvem empates;
entradas sem versão usam essas datas, e empates completos preservam a ordem
original. A ordenação é aplicada novamente ao carregar páginas anteriores.

Referência da pesquisa nativa:
[Apple — ToolbarDefaultItemKind.search](https://developer.apple.com/documentation/swiftui/toolbardefaultitemkind/search).
Referência da tradução em lote:
[Apple — TranslationSession.translations(from:)](https://developer.apple.com/documentation/translation/translationsession/translations%28from%3A%29).

## Demo

O demo usa reprodução automática a cada cinco segundos. Em builds Debug,
`--changelog-preview` abre uma amostra com três imagens ilustrativas públicas
do Picsum e descrições distintas. A amostra possui duas páginas de versões,
com atraso de um segundo na segunda para conferir o rodapé de carregamento.
O conteúdo vem de transporte falso, e as
imagens dessa amostra requerem internet. Os testes unitários substituem também
o carregamento de imagens e não acessam rede externa.

Esta alteração é aditiva e deve integrar uma versão minor validada pela CI.
Nenhuma tag é criada por esta implementação.

## Validação desta implementação

Em 30/09/2026, `swift package dump-package`, `swift build`, `swift test
--enable-code-coverage`, `Scripts/check-coverage.sh`, `swiftformat . --lint` e
`swiftlint lint --strict` passaram no macOS com Xcode. Foram 120 testes aprovados,
com 84,70% de cobertura de linhas no código de produção. O demo também compilou
para iOS Simulator.

No iPhone 17 Pro, foi conferida a amostra com três imagens e descrições
distintas, a reprodução automática, os indicadores, a navegação aos detalhes e
o retorno, além da pesquisa por versão. Texto ampliado preservou a leitura, e
ativar VoiceOver suspendeu a reprodução automática. Os ajustes do simulador
foram restaurados após a verificação.

A imagem de referência mencionada na solicitação não estava disponível nesta
conversa. A composição segue os requisitos descritos e o exemplo de carrossel,
com controles nativos compatíveis com iOS 16 e macOS 13.
