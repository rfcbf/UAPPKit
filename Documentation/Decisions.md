# Decisões de arquitetura

Este registro preserva decisões que orientam o contrato do pacote, inclusive
quando a motivação não está expressa no código.

## Integração nativa nos aplicativos

O UAPP fornece Feedback, Roadmap e Changelog para aplicativos Apple. A
integração deve configurar um projeto e abrir essas experiências por um
package Swift compartilhado.

## Decisão 0024 — Swift Package nativo, sem WebView

- O pacote usa Swift Package Manager, requer iOS 16 e macOS 13 e não tem
  dependências externas.
- A API de alto nível fornece `setup`, `identify`, `reset`, apresentação de
  Feedback/Roadmap/Changelog no iOS e `makeClient` para integração própria.
- A apresentação no iOS usa `UIHostingController` com views SwiftUI nativas.
  Não usar WebView ou Safari View Controller como implementação das telas.
- `UAPPTransport` permite substituir a camada de rede; `URLSessionTransport`
  é a implementação padrão e `UAPPClient` é um actor.
- `CodingKeys` explícitas evitam incompatibilidades entre convenções snake_case
  e camelCase na mesma resposta.
- `signatureProvider` prepara o envio de uma assinatura do servidor do
  integrador no header `x-uapp-signature`. A verificação server-side não está
  ativa e a assinatura não deve ser anunciada como proteção disponível.

## Markdown do Changelog

O corpo do changelog é Markdown. A UI SwiftUI interpreta o conteúdo com
`AttributedString` e usa texto simples se o parsing falhar. A sintaxe suportada
segue o Markdown do sistema Apple e deve continuar legível sem processamento
de HTML não confiável.

## Privacidade e credenciais

O projeto hospedeiro nunca deve receber segredos administrativos ou credenciais
do serviço. O SDK contém apenas o identificador público do projeto e, se
configurado pelo integrador, obtém o token de assinatura por closure. Identidade
de usuário final é opcional e separada de contas de painel.
