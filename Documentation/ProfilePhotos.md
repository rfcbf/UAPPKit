# Foto de perfil

No iOS, `UAPPProfilePhotoPicker` fornece o menu de biblioteca/câmera, a prévia
da foto e o editor de recorte circular. O resultado é entregue em um binding
de `Data?`; o aplicativo decide quando salvar seu perfil. Cancelar o editor
preserva a foto anterior, e remover a foto entrega `nil`.

O seletor acompanha o `locale` do ambiente por padrão. Se o aplicativo mantém
uma escolha própria de idioma, passe `languageIdentifier: "pt-BR"` (ou o
identificador selecionado) para aplicar essa escolha aos textos, menus e
mensagens do componente. O cadastro do kit passa o idioma da apresentação;
o perfil manual do Demo passa o idioma configurado no Demo.

```swift
import SwiftUI
import UAPPKit

struct ProfilePhotoSection: View {
    @State private var photo: Data?

    var body: some View {
        UAPPProfilePhotoPicker(photo: $photo)
    }
}
```

O recorte usa [Mantis](https://github.com/guoyingtao/Mantis/tree/v3.1.0),
dependência SPM restrita ao iOS e fixada em 3.1.0 para manter a API utilizada.
O integrador adiciona somente UAPPKit, sem configurar Mantis separadamente.
Se já depender de Mantis, use a mesma URL do pacote para evitar dois produtos
com o mesmo nome. No macOS, Mantis não é compilado: o mesmo
`UAPPProfilePhotoPicker` oferece o app Fotos (`PhotosPicker`) e um arquivo do
Finder (`fileImporter`), e o recorte circular é feito pelo próprio pacote
(`UAPPProfilePhotoCropper`, com arrasto e zoom). A câmera não é oferecida no
Mac. Em app com App Sandbox, a leitura do arquivo exige o direito
`com.apple.security.files.user-selected.read-only`.

A seleção da biblioteca usa o seletor nativo de fotos. Para oferecer a câmera,
o aplicativo precisa incluir `NSCameraUsageDescription` em seu Info.plist,
com uma descrição do uso, por exemplo: “A câmera permite tirar uma foto para
o seu perfil.” O Demo já inclui essa descrição. A câmera fica indisponível em
dispositivos sem câmera; permissões negadas apresentam uma orientação e a
opção de abrir os Ajustes. A solicitação acontece somente ao escolher a câmera.
O pacote não pode inserir a descrição de uso no Info.plist do aplicativo.
O seletor nativo da biblioteca permite escolher uma foto sem autorizar acesso
à biblioteca inteira; esse fluxo não exige `NSPhotoLibraryUsageDescription`.

`UAPPProfileImageProcessor.compressedJPEG(from:)` normaliza a orientação,
limita a imagem a 512 pixels, mantém a proporção quadrada e aplica máscara
circular. A qualidade final do JPEG é 0,72. Como JPEG não possui transparência,
o fundo externo ao círculo é branco; exiba o avatar com `clipShape(Circle())`.
Não há envio da imagem nem gravação automática pelo seletor isolado. No perfil
manual do Demo, salvar persiste os dados no aparelho. Feedback e roadmap usam
esse perfil sem abrir autenticação, e a toolbar mostra o avatar local.
Ao enviar um feedback, o kit inclui a foto de `UAPPIdentity.avatarData`, com
fallback para um arquivo local de `UAPPIdentity.avatarURL`,
em `profilePhoto` (JPEG/PNG em base64, até 512 KiB), junto com nome e e-mail.
O serviço salva a imagem e sua URL no cadastro do autor do aplicativo; ela fica
disponível no UAPP e nos feedbacks públicos. Omitir `profilePhoto` preserva a
foto anterior; `null` remove a foto do perfil local. Contas autenticadas
continuam usando o avatar da própria conta.

`avatarData` é opcional (default `nil`) e não altera chamadas existentes. Use
`avatarURL` para exibição e `avatarData` para transmitir a foto de um perfil local.

Para mostrar o perfil local com estatísticas e histórico públicos, use
`UAPPUserScreen(profile: identity, client: client, theme: theme)`. A toolbar de
participação usa essa apresentação. `client.participationProfile()` resolve
o autor pela instalação no aplicativo, sem exigir um feedback como ponto de
entrada ou uma conta autenticada. O perfil aberto pelo card continua consultando
o autor daquele feedback. Novas APIs são aditivas e preservam os inicializadores
existentes.

## Foto no cadastro

`UAPPAccountScreen` também oferece o seletor no cadastro por e-mail, quando o
provedor declara `supportsProfilePhoto`. A foto é opcional. O kit mantém a
imagem durante a confirmação do e-mail e chama `uploadProfilePhoto(_:)` apenas
depois que existe uma sessão autenticada. A sessão entregue ao aplicativo já
contém a URL do avatar. Se o envio falhar, é possível tentar novamente ou
remover a foto para continuar, sem repetir o cadastro ou a confirmação.

`UAPPAuthentication` salva o JPEG no bucket público `avatars`, em um caminho
`<id-do-usuário>/<identificador-único>.jpg`, e associa a URL aos metadados da
conta em `avatar_url` e `uapp_avatar_url`. Provedores sociais (Apple, Google,
GitHub) podem reescrever `avatar_url` a cada login, mas não `uapp_avatar_url`;
por isso a sessão prioriza `uapp_avatar_url` e a última foto definida pelo
usuário prevalece, qualquer que seja o provedor usado depois. O servidor deve permitir leitura pública e gravação/exclusão somente
pelo proprietário desse diretório. A sessão atualizada também é persistida no
Keychain. O método aceita JPEG de até 512 KB; use o processador do kit antes de
enviar uma imagem obtida fora do seletor.

## Foto no perfil conectado

`UAPPUserScreen(session:authentication:...)` torna o avatar editável no iOS
quando o provedor declara `supportsProfilePhoto`. Tocar no avatar abre o mesmo
menu de biblioteca/câmera e o recorte circular; não há opção de remover, porque
o provedor só oferece envio. Depois do recorte, a tela mostra imediatamente a
nova foto, chama `uploadProfilePhoto(_:)` e, ao concluir, exibe a URL da sessão
atualizada e a entrega em `onSessionChange`. Sair e fechar a tela ficam
bloqueados durante o envio. Se o envio falhar, a última foto definida volta a
ser exibida e um aviso permite tentar novamente. Em provedores sem suporte, o
avatar continua somente para leitura; no macOS o fluxo é o mesmo do iOS.

Adaptadores próprios continuam compatíveis: `supportsProfilePhoto` tem valor
padrão `false` e `uploadProfilePhoto(_:)` lança `unsupportedMethod` por padrão.
Para oferecer a foto no cadastro, implemente ambos e retorne a sessão com o
avatar atualizado. A seleção e o recorte estão disponíveis somente no iOS.
