# Autenticação reutilizável

`UAPPAccountScreen` pertence ao UAPPKit. O aplicativo pode apresentá-la em uma
sheet, em navegação própria ou pela API `UAPPKit.showAuthentication`. A mesma
instância de `UAPPAuthenticationProvider` é usada em todas as apresentações e
em Feedback/Roadmap para reaproveitar a conta conectada.

O fluxo inclui login por e-mail/senha, Google, Apple e GitHub; cadastro com
nome obrigatório e confirmação de e-mail. No cadastro e na troca de senha,
`UAPPPasswordPolicy` exige pelo menos 8 caracteres, uma letra maiúscula e um
caractere especial (pontuação ou símbolo; espaços não atendem esse requisito).
`minimumPasswordLength` pode elevar o mínimo, mas nunca reduzi-lo abaixo de 8.
O login continua aceitando senhas existentes. Provedores próprios devem aplicar
a mesma política e configurar a exigência correspondente no servidor de autenticação.

O fluxo também inclui recuperação com código, confirmação da
nova senha e saída da conta. O kit reutiliza `UAPPApplicationIcon`, o mesmo
componente do Sobre, com ícone remoto do projeto e fallback para o ícone do
aplicativo hospedeiro. Os botões seguem o tema configurado. Os novos textos têm
traduções nos 13 idiomas do seletor do kit. O fluxo e a visualização da conta
acompanham a seleção de idioma sem fechar a tela nem apagar os dados digitados.

## Usar em qualquer parte do aplicativo

### Informações da conta conectada

`UAPPUserScreen(session:authentication:theme:onSessionChange:)` apresenta foto (quando disponível), nome,
e-mail e o estado conectado em uma sheet nativa. Recebe a sessão que o
aplicativo já possui, sem iniciar login nem expor tokens ou identificadores
internos. Campos ausentes são omitidos; uma foto indisponível usa um ícone de
perfil. A tela segue o tema do kit, com fechar e seleção de idioma. No iOS,
a sheet usa altura média, com rolagem para acomodar o conteúdo.

No SwiftUI, use `UAPPUserScreen(session: session, authentication: authentication,
onSessionChange: updateSession)` dentro de `.sheet`.
Para apresentação pelo kit no iOS, use `try UAPPKit.showUser(session: session,
authentication: authentication, onSessionChange: updateSession)`.
Use o mesmo provedor que mantém a conta do aplicativo. A ação **Sair** encerra
a sessão, informa `nil` pelo callback e fecha a sheet. Se houver falha e a
sessão continuar ativa, a tela apresenta uma mensagem e permite tentar novamente.
No Demo, toque na conta conectada na tela principal para abrir suas informações.

Depois do setup, crie e conserve o provedor na camada de conta do aplicativo:

```swift
let authentication = try UAPPKit.makeAuthentication(
    callbackURL: URL(string: "meuapp://authentication")!
)
```

O setup não exige sessão, token ou chave de autenticação. Essa criação não
inicia login nem consulta a configuração de autenticação. A configuração
pública é descoberta somente quando uma operação de autenticação é solicitada.

Para SwiftUI, apresente a view pública:

```swift
.sheet(isPresented: $showsLogin) {
    UAPPAccountScreen(
        authentication: authentication,
        client: try? UAPPKit.makeClient(),
        onSessionChange: { session in
            // Atualize o estado de conta do aplicativo.
        }
    )
}
```

Para manter uma tela de abertura própria até o formulário aparecer, passe
`onReady`: ele é chamado uma vez quando o login está pronto para uso e não é
chamado quando já existe sessão.

O `client` é opcional e permite descobrir nome e ícone do projeto, como no
Sobre. Também é possível passar `appName`, `appIconURL`, `theme`,
`minimumPasswordLength`, `termsURL` e `privacyURL`. A view já fornece seu
`NavigationStack` e os controles de fechar e idioma.

Para apresentação pelo kit:

```swift
try UAPPKit.showAuthentication(authentication: authentication)
try await UAPPKit.showFeedback(authentication: authentication)
try await UAPPKit.showRoadmap(authentication: authentication)
```

Sem usar a fachada global, `UAPPAuthentication.automatic(configuration:callbackURL:)`
cria o provedor diretamente. Provedores próprios continuam suportados. Os novos
métodos de cadastro e recuperação têm implementação padrão que informa opção
não suportada, preservando a conformidade dos adaptadores existentes.

## Cadastro e recuperação

Se o servidor exigir confirmação de e-mail, o cadastro segue para a entrada
do código recebido. Caso o servidor já retorne uma sessão, a tela reconhece o
usuário conectado e fecha automaticamente a apresentação. O nome é obrigatório; a senha é confirmada antes do envio.

Na recuperação, o e-mail é solicitado sem afirmar que a conta existe. O código
é validado como `recovery` antes de permitir uma nova senha. A atualização usa
`PUT /auth/v1/user` com a sessão obtida na verificação. O callback da conta só
recebe essa sessão depois de salvar a senha. Se a tela for fechada depois de
validar o código e antes de concluir, o kit encerra a sessão temporária.

O serviço deve enviar `{{ .Token }}` nos modelos **Confirm signup** e
**Reset password**. Para manter os links existentes e acrescentar o código,
inclua uma mensagem como `Seu código: {{ .Token }}` no corpo desses modelos.
O envio também depende de SMTP, políticas de senha e limites do serviço.
Essas configurações remotas não foram alteradas nesta implementação.

Referências do contrato: [verificação de códigos](https://supabase.com/docs/reference/swift/auth-verifyotp),
[autenticação por senha](https://supabase.com/docs/guides/auth/passwords) e
[modelos de e-mail](https://supabase.com/docs/guides/auth/auth-email-templates).

## Sessão e dados privados

O provedor próprio do kit salva a sessão no Keychain do aplicativo, incluindo
perfil, tokens e expiração. Restaura a conta entre inicializações e renova o
token quando necessário. O provedor automático separa os registros por servidor
e projeto; sem sessão salva, consultar a conta não dispara descoberta de login.
Uma sessão ainda válida pode ser restaurada sem conexão. Falhas temporárias de
rede não apagam o registro salvo; uma renovação rejeitada exige novo login.
Sair remove o registro local mesmo quando o servidor está indisponível.
Senhas não são armazenadas. A sessão temporária de recuperação só é persistida
depois de salvar a nova senha. Perfil local permanece independente da conta.

Provedores externos continuam responsáveis pela própria persistência.
Ao construir `UAPPAuthenticationConfiguration` diretamente, use
`persistsSession: false` se precisar de uma sessão apenas em memória.
O Demo restaura a conta ao abrir e não grava tokens em UserDefaults.

O Demo contém apenas a escolha de apresentação, o estado da conta e o perfil
local. Não contém mais a implementação de descoberta, login ou recuperação.

## Validação

Foram adicionados casos de teste determinísticos para os contratos de cadastro
e recuperação e para as etapas do modelo, sem rede real. Conforme orientação
do proprietário, não foram executados builds, testes ou inspeções de telas
nesta alteração. A compilação, a aparência e os fluxos com contas reais ficam
para validação do proprietário.

A tela inicial oferece **Conectar** e **Criar conta**. Cada opção abre sua
própria página na navegação nativa, com retorno à escolha inicial. A apresentação
aguarda a consulta de sessão, os dados do aplicativo e o carregamento da imagem
antes de exibir o conteúdo, evitando a troca de ícone durante a abertura.

Após autenticar, a tela fecha e entrega a sessão pelo `onSessionChange`.
O cadastro por e-mail oferece uma foto opcional no iOS quando o provedor
suporta `supportsProfilePhoto`. Após confirmar a conta, a tela chama
`uploadProfilePhoto(_:)` e só entrega a sessão depois de associar o avatar.
Uma falha permite repetir o envio ou remover a foto sem criar outra conta.
Veja [foto de perfil e permissões](ProfilePhotos.md).

O Demo usa essa sessão para mostrar foto, nome e e-mail da conta conectada.
A ação **Sair** fica na tela de visualização do perfil, compartilhando o
provedor com Feedback/Roadmap.
