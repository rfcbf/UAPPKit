# Instruções do UAPPKit

## Estrutura

- `Sources/UAPPKit/`: biblioteca pública Swift.
- `Tests/UAPPKitTests/`: testes unitários em Swift Testing, sem rede externa.
- `Documentation/`: arquitetura, decisões e roadmap público do pacote.
- `.github/workflows/`: validação contínua em macOS.

## Desenvolvimento e validação

Use Swift tools 6.0 e linguagem Swift 6.

Por preferência explícita do proprietário, faça somente as alterações pedidas
e informe quando terminar. Não execute builds, testes automatizados, verificações
de cobertura nem testes ou inspeções de telas em simulador/dispositivo. Não abra,
instale ou rode o Demo para validar alterações. O proprietário faz a validação
e envia fotos e orientações quando precisar de ajustes.

Essa regra vale também para conversas futuras e prevalece sobre instruções de
validação automática neste arquivo. Só execute essas validações quando o
proprietário pedir explicitamente; não solicite autorização a cada alteração.
Se um problema estiver complicado, o proprietário poderá pedir explicitamente
para fazer o build e testar a tela. Nesse caso, valide apenas o escopo solicitado.

Instale SwiftFormat, SwiftLint e XcodeGen com
`brew install swiftformat swiftlint xcodegen`. Para aplicar o estilo antes de
validar, execute `swiftformat .`.

## Testes unitários

- Use exclusivamente Swift Testing (`import Testing`, `@Test`, `#expect`,
  `#require` e `Issue.record`). Não use XCTest, `XCTestCase` ou asserções
  `XCT*`.
- Organize os testes por unidade testada: por exemplo,
  `UAPPClientTests.swift`, `UAPPModelsTests.swift`,
  `UAPPAboutScreenTests.swift` e `UAPPReviewsScreenTests.swift`. Não concentre
  toda a suíte em um único arquivo.
- Mantenha `TestSupport.swift` apenas para doubles e helpers compartilhados,
  como `StubTransport`, recorder de requisições e fixtures pequenas.
- Todo teste de rede deve injetar um `UAPPTransport` falso. Os testes devem ser
  determinísticos, sem depender de internet, credenciais, estado remoto ou
  serviços externos.
- Toda alteração de comportamento público deve incluir ou atualizar testes da
  unidade correspondente, cobrindo sucesso, erro e campos opcionais quando
  aplicável.
- A cobertura mínima exigida na CI é 80% de linhas no código de produção.
  Quando o proprietário solicitar validação de cobertura, use
  `swift test --enable-code-coverage` e depois `bash Scripts/check-coverage.sh`.
  O verificador exclui somente arquivos gerados, o ponto de entrada dos testes
  e os próprios arquivos em `Tests/`; as telas SwiftUI e a internacionalização
  também fazem parte da cobertura exigida.

Não adicione dependências externas sem necessidade documentada. Mudanças no
contrato HTTP devem permanecer alinhadas aos endpoints públicos do UAPP e aos
fixtures dos testes. Nunca inclua credenciais, tokens ou dados privados.

## API e compatibilidade

Trate os tipos e métodos `public` como API consumida por aplicativos externos.
Antes de mudar ou remover uma API pública, documente a compatibilidade e use
versionamento semântico. Mantenha `CodingKeys` explícitas: as respostas podem
misturar snake_case e camelCase, por isso o decoder não deve usar conversão
global automática.

O transporte deve continuar injetável por `UAPPTransport`, para que os testes
sejam determinísticos e não dependam de rede.

## Apple platforms

As plataformas declaradas são iOS 18+ (inclui iPadOS) e macOS 13+. Não declare
suporte a outro sistema sem compilar e testar o pacote nessa plataforma.
Interface nova deve ser SwiftUI nativa, acessível e compatível com Dynamic
Type. Não introduza WebView para substituir as telas nativas.

Ícones customizados em widgets, controles do sistema, Lock Screen, Control
Center ou Apple Watch devem ser Symbol Images completos no asset catalog do
target que os renderiza. Não use PNG direto nem `systemImage` para esses ícones;
inclua as nove combinações de peso/tamanho e guides de Small, Medium e Large.

## Documentação e releases

Não cite projetos pessoais do proprietário na interface, na documentação ou
nos exemplos do UAPPKit. Use nomes e cenários genéricos.

Mantenha README, arquitetura, decisões, roadmap e changelog independentes do
checkout privado do UAPP. Exemplos de instalação devem apontar ao repositório
público do pacote e usar uma tag existente.

Use Conventional Commits e tags SemVer sem prefixo (`0.1.0`, `0.1.1`, `0.2.0`,
`1.0.0`).

### Fluxo de branches e Pull Requests

Nenhuma alteração entra direto na `main`. Todo trabalho segue este fluxo:

1. Crie uma branch a partir da `main` atualizada, com prefixo pelo tipo da
   mudança: `feat/`, `fix/`, `refactor/`, `docs/`, `test/` ou `chore/` (por
   exemplo, `feat/tela-de-avaliacoes`).
2. Faça os commits na branch seguindo Conventional Commits.
3. Abra um Pull Request da branch para a `main` e aguarde a CI ficar verde.
4. O merge na `main` acontece somente pelo Pull Request, nunca por `git push`
   direto.

### Sem referência ao uso de IA

Commits, Pull Requests, tags, comentários de código e documentação não podem
mencionar que foram produzidos com ajuda de IA. Isso vale mesmo quando a
ferramenta sugere incluir por padrão:

- Não adicione trailers como `Co-Authored-By:` de assistentes ou modelos nas
  mensagens de commit.
- Não inclua linhas como "Generated with ..." no corpo de Pull Requests.
- Não cite nomes de assistentes, modelos ou ferramentas de IA em títulos,
  descrições ou comentários.

### Versionamento e tags

Um pacote Swift não tem arquivo de versão: a versão é a tag. A fonte da versão
é o `CHANGELOG.md`. O primeiro título no formato `## X.Y.Z - AAAA-MM-DD`,
logo abaixo de `## Não lançado`, é a versão atual. A primeira versão do pacote
é `0.1.0`.

A casa a incrementar depende do tipo da mudança mergeada:

| Tipo da mudança                    | Casa incrementada | Exemplo           |
| ---------------------------------- | ----------------- | ----------------- |
| Reestruturação ou grande alteração | Primeira (major)  | `1.4.2` → `2.0.0` |
| Nova funcionalidade (`feat`)       | Segunda (minor)   | `1.4.2` → `1.5.0` |
| Correção de bug (`fix`)            | Terceira (patch)  | `1.4.2` → `1.4.3` |

Ao incrementar uma casa, as casas à direita voltam a zero. Se o Pull Request
misturar tipos, vale o de maior impacto. Remover ou mudar API `public` de forma
incompatível conta como grande alteração. Pull Requests que só mexem em
documentação, testes ou tarefas internas (`docs`, `test`, `chore`) não criam
versão e não geram tag.

#### Atualização automática da versão pelo agente

Atualizar a versão é responsabilidade do agente, não do proprietário. Sempre
que o proprietário pedir o commit e disser que vai abrir (ou pedir para abrir)
o Pull Request para a `main`, o agente deve, sem pedir confirmação:

1. Identificar o tipo da mudança da branch e escolher a casa a incrementar
   pela tabela acima, a partir da versão que está no `CHANGELOG.md` da `main`.
2. No `CHANGELOG.md`, mover as entradas de `## Não lançado` para um novo
   título `## X.Y.Z - AAAA-MM-DD`, mantendo `## Não lançado` vazio no topo.
3. Atualizar os exemplos de instalação do README que citam a versão, quando
   houver.
4. Incluir essas alterações no commit da branch, antes de abrir o Pull Request.
5. Informar ao proprietário a versão anterior, a nova e o motivo da casa
   escolhida.

Se a branch já tiver criado a versão em relação à `main`, não crie outra.
Nunca altere a versão direto na `main`.

#### Tag automática no merge

A tag não é criada na mão. O workflow `.github/workflows/release-tag.yml` roda
quando a CI da `main` termina verde, lê a versão atual do `CHANGELOG.md` e
cria a tag correspondente no commit mergeado, se ela ainda não existir. O
workflow só cria a tag; ele não faz commit nem altera arquivos. Enquanto o
`CHANGELOG.md` não tiver nenhum título de versão, nenhuma tag é criada.
