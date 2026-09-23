# Instruções do UAPPKit

## Estrutura

- `Sources/UAPPKit/`: biblioteca pública Swift.
- `Tests/UAPPKitTests/`: testes XCTest sem rede externa.
- `Documentation/`: arquitetura, decisões e roadmap público do pacote.
- `.github/workflows/`: validação contínua em macOS.

## Desenvolvimento e validação

Use Swift tools 5.9 como mínimo do manifesto. Antes de enviar uma alteração,
execute `swift package dump-package`, `swift build` e `swift test` em macOS com
Xcode. A CI também compila o produto de release e testa os destinos macOS e iOS
Simulator declarados.

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
