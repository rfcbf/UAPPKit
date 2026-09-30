# Instruções do UAPPKit

## Estrutura

- `Sources/UAPPKit/`: biblioteca pública Swift.
- `Tests/UAPPKitTests/`: testes unitários em Swift Testing, sem rede externa.
- `Documentation/`: arquitetura, decisões e roadmap público do pacote.
- `.github/workflows/`: validação contínua em macOS.

## Desenvolvimento e validação

Use Swift tools 6.0 e linguagem Swift 6. Antes de enviar uma alteração,
execute `swift package dump-package`, `swift build`, `swift test`,
`swiftformat . --lint` e `swiftlint lint --strict` em macOS com Xcode.

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
- A cobertura mínima exigida é 80% de linhas no código de produção. Rode
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

As plataformas declaradas são iOS 16+ (inclui iPadOS) e macOS 13+. Não declare
suporte a outro sistema sem compilar e testar o pacote nessa plataforma.
Interface nova deve ser SwiftUI nativa, acessível e compatível com Dynamic
Type. Não introduza WebView para substituir as telas nativas.

Ícones customizados em widgets, controles do sistema, Lock Screen, Control
Center ou Apple Watch devem ser Symbol Images completos no asset catalog do
target que os renderiza. Não use PNG direto nem `systemImage` para esses ícones;
inclua as nove combinações de peso/tamanho e guides de Small, Medium e Large.

## Documentação e releases

Mantenha README, arquitetura, decisões, roadmap e changelog independentes do
checkout privado do UAPP. Exemplos de instalação devem apontar ao repositório
público do pacote e usar uma tag existente.

Use Conventional Commits e tags SemVer (`0.1.0`, `0.1.1`, `0.2.0`, `1.0.0`).
Não crie tag de release enquanto a versão correspondente não estiver pronta e
validada pela CI.
