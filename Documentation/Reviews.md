# Avaliações da App Store

A tela mostra as estrelas à esquerda e autor/data à direita. Com Dynamic Type,
os metadados podem ocupar uma linha abaixo, mantendo o alinhamento à direita.
Quando `response_body` tem texto, um botão discreto permite expandir e recolher
a resposta do desenvolvedor.
O separador é desenhado fora do card e ocupa a largura do conteúdo da linha,
inclusive quando o botão ou a resposta expandida estão presentes. Cada card
tem 16 pontos de espaço no topo e na base, com os insets verticais automáticos
da lista zerados. A linha aparece apenas entre reviews, nunca após o último
item carregado. Quando outra página chega, o antigo último item recebe sua
divisão com o novo item. O rodapé
mostra um indicador enquanto carrega a próxima página, também na nova tentativa.

## Paginação e compatibilidade

`UAPPClient.reviewsPage(limit:cursor:)` é uma API aditiva, com limite padrão 20.
Para configurar a tela, use `try UAPPKit.showReviews(pageSize: 10)` ou
`UAPPReviewsScreen(client: client, pageSize: 10)` na composição SwiftUI.
O parâmetro `pageSize` é obrigatório nas duas entradas públicas. As chamadas
anteriores `showReviews()` e `UAPPReviewsScreen(client:)` precisam ser migradas
para informar explicitamente o tamanho. Esta é uma alteração incompatível da
API pública e deve integrar a próxima versão minor enquanto o pacote estiver
em 0.x (ou major após 1.0), sem criar uma tag antes da validação da CI.
O tamanho configurado é ajustado à faixa de 1 a 50 e usado tanto na primeira
página quanto nas seguintes e nas novas tentativas. Enquanto uma página está
carregando, o rodapé mantém o indicador circular com o texto localizado
“Carregando mais avaliações…”. O gatilho de rolagem inicia a consulta sem
vincular sua duração ao tempo em que a linha do gatilho fica visível.

O método existente `reviews(limit:)` conserva seu retorno e limite padrão 50.
`UAPPReview.responseBody` é opcional, com CodingKey explícita `response_body`.

O recurso HTTP `reviews` recebe `limit` e um `cursor` opaco opcional. Retorna
`reviews` e `nextCursor` (string ou null). O servidor ordena por `reviewed_at`
e `id`, ambos decrescentes, e consulta um item extra para detectar a próxima
página. O cursor usa a data e o ID do último item devolvido. Esse desempate
evita perder reviews que tenham a mesma data.

O SDK impede cargas simultâneas, remove IDs duplicados e interrompe a leitura
se o servidor repetir o cursor. Um erro na próxima página preserva a lista e
permite repetir a consulta. Sem `nextCursor`, a lista termina — inclusive com
endpoints antigos, que não oferecem paginação. Respostas e paginação remota
dependem da versão atualizada do endpoint.

## Tradução

No iOS 18+/macOS 15+, os textos visíveis usam Apple Translation para o idioma
selecionado na apresentação do UAPPKit. Natural Language identifica o idioma
de cada título, corpo ou resposta, que podem ter idiomas diferentes. Quando a
identificação não for conclusiva, Apple Translation recebe origem nil e tenta
identificá-la. Textos no idioma selecionado não são traduzidos.

A lista mantém um cache em memória de traduções por texto e idioma de destino
durante sua apresentação. Ao sair e voltar para uma linha na rolagem, a tradução
concluída é reutilizada; ao voltar para um idioma anterior, sua tradução também
é reutilizada. Título, corpo e resposta usam o mesmo cache, que é liberado ao
fechar a tela. O conteúdo exibe um skeleton durante a tradução e impede iniciar
duas traduções simultâneas para o mesmo texto e idioma. Falhas não ficam no cache
como traduções concluídas e permitem nova tentativa.

A troca de idioma seleciona o estado correspondente, evitando mostrar uma tradução
do idioma anterior. A resposta é traduzida ao ser expandida. O framework pode
solicitar a instalação de idiomas; idiomas indisponíveis, falhas, cancelamentos
e sistemas anteriores preservam o original. A tradução real e os diálogos de
download precisam ser verificados em dispositivo compatível.

Referência: [identificação automática no Apple Translation](https://developer.apple.com/documentation/translation/translationsession/configuration/source).

## Validação em 30 de setembro de 2026

- Compilação do pacote em macOS e para iOS Simulator aprovada.
- `swift package dump-package`, testes Swift Testing, SwiftFormat e SwiftLint
  estrito aprovados. Cobertura de produção: **81,68%**, incluindo telas e
  internacionalização. O verificador também exclui os símbolos de strings
  gerados pelo Xcode, além dos demais arquivos gerados já excluídos.
- Paginação e estado de tradução têm 100% de cobertura de linhas nos models;
  os testes usam transporte falso e tradutores injetados, sem rede externa.
- Sete testes do endpoint aprovados; verificação TypeScript/Deno aprovada.
- Endpoint publicado em produção e depois no DEV. As versões publicadas foram
  comparadas antes da alteração; só o recurso de reviews mudou.
- Consulta real no DEV retornou duas páginas distintas com resposta opcional,
  cursor válido e rejeição de cursor inválido com HTTP 400.
- A tradução real e a solicitação de download dos idiomas ainda precisam ser
  conferidas em dispositivo compatível. O original permanece visível em erro,
  com um aviso discreto de tradução indisponível.
- Os ajustes de skeleton, cache ao recriar linhas, troca de idiomas e loading
  do rodapé foram verificados com tradutores e transportes falsos, incluindo
  carregamento suspenso de página para verificar o estado intermediário.
