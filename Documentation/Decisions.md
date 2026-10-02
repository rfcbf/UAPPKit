# Decisões de arquitetura

## Conversa e imagens de feedback

Manter uma tela SwiftUI contínua com o compositor antes da conversa, avatares
circulares e respostas agrupadas por `parentCommentId`. Votos do feedback usam
`.vote`; comentários também usam `.vote`. Os nomes antigos no armazenamento
dos comentários são mantidos como detalhe de compatibilidade.
Reconsultar a cada 15 segundos somente no primeiro plano, sem substituir o
rascunho. Após enviar, consultar novamente todas as páginas para mostrar também
o comentário próprio em moderação. A leitura continua injetável e sem SDK de
Realtime adicional.

Anexar até duas imagens ao mesmo envio do texto, compactadas em JPEG de até
512 KiB e 1600 pixels cada. O seletor remove metadados ao reencodar; o servidor
valida quantidade/tamanho/assinatura, guarda os arquivos em bucket privado e
fornece URLs temporárias somente para linhas autorizadas. Falhas no segundo
upload ou ao associar os arquivos limpam os uploads recém-criados. O contrato
legado de uma imagem de até 2 MiB permanece compatível.
Campos/parâmetros novos são aditivos, para uma próxima versão minor após CI.
Nenhum build ou teste foi executado por preferência do proprietário.

## Recorte de fotos de perfil

Adicionar Mantis 3.1.0 como dependência SPM somente no iOS para oferecer o
editor circular em `UAPPProfilePhotoPicker`, evitando manter gestos e controles
de recorte próprios. O componente expõe apenas um binding de dados do perfil;
não exige que o aplicativo importe a biblioteca. O processamento final limita
o JPEG a 512 pixels com qualidade 0,72, e a persistência continua no hospedeiro.
Não há dependência de Mantis na compilação para macOS. Ver
[Foto de perfil](ProfilePhotos.md).

## Autenticação reutilizável no pacote

Login, cadastro e recuperação passam a pertencer ao UAPPKit por meio da view
pública `UAPPAccountScreen`. O Demo conserva somente o provedor e o perfil
local. Reutilizar o componente de ícone do Sobre, o tema e a navegação do kit;
manter o provedor injetável e persistir a sessão própria no Keychain. Métodos novos têm defaults
que retornam opção não suportada para preservar adaptadores existentes.
Recuperação confirma um código do tipo `recovery` antes de atualizar a senha,
sem comunicar a sessão temporária ao hospedeiro antes da conclusão.
O contrato requer o código nos modelos de e-mail. A mudança é aditiva, destinada
a uma versão minor futura; nenhum release ou validação foi executado nesta
etapa, conforme orientação do proprietário.

## Identidade de participação e sessão do hospedeiro

Reutilizar a camada de sessão do app através de um provider opcional de access
token, fornecido na abertura de Feedback/Roadmap e consultado nas requisições
dessas áreas. O setup não recebe sessão. Cada abertura cria um cliente isolado;
Sobre, Changelog e Reviews não consultam o access token. Manter perfil informativo (`UAPPIdentity`,
agora com foto opcional) separado de autenticação validada pelo UAPP. Nenhuma
dependência de SDK de autenticação ou persistência de credenciais entra no
pacote nesta etapa. O provider completo reutiliza a sessão do hospedeiro;
o adaptador Supabase opcional usa OAuth/PKCE e código por e-mail, em memória.
O backend vincula aplicativo e sujeito validado, sem unir contas por e-mail
ou transferir automaticamente histórico anônimo, conforme [Feedback](Feedback.md).
Login real e callback no app consumidor ainda precisam de validação.
As APIs são aditivas e devem integrar uma versão minor validada pela CI.

Este registro preserva decisões que orientam o contrato do pacote, inclusive
quando a motivação não está expressa no código.

## Integração nativa nos aplicativos

O UAPP fornece Feedback, Roadmap e Changelog para aplicativos Apple. A
integração deve configurar um projeto e abrir essas experiências por um
package Swift compartilhado.

## Decisão 0024 — Swift Package nativo, sem WebView

- O pacote usa Swift Package Manager, requer iOS 18 e macOS 13 e não tem
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
