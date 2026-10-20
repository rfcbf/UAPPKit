# UAPPKit Demo

Aplicativo SwiftUI para testar as telas nativas de Feedback, Roadmap e
Changelog do pacote durante o desenvolvimento.

A tela inicial permite informar o `public_slug` do app e o servidor Supabase,
salvar essas configurações no dispositivo e testar a conexão antes de abrir as
telas do UAPPKit.

A tela principal oferece duas opções, cada uma em uma sheet própria:

- “Conectar”: conta por e-mail/senha, Google, Apple ou GitHub. O mesmo provedor
  é passado a Feedback e Roadmap, que reaproveitam a sessão em memória.
- “Preencher perfil”: nome, e-mail e foto opcional persistidos
  neste aparelho. Nome e e-mail são enviados ao kit como identidade declarada;
  a foto escolhida fica somente no Demo, sem upload público.

Perfil local não autentica uma conta. Se o visitante decidir participar, o kit
pode pedir login para validar autoria. Sair da conta preserva o perfil local;
o botão “Apagar perfil local” remove os dados salvos. Uma conta conectada
precisa de novo login depois de reiniciar o app. Trocar projeto/servidor
descarta a sessão anterior.

O provedor do kit descobre a configuração pública somente ao iniciar um login. O callback
OAuth é `uappkit://authentication`, registrado no target; o servidor precisa
permitir esse endereço e ter cada provedor configurado. Não há chave privada
nem token no setup. `Tests/DemoAccountModelTests.swift` cobre persistência,
sessão compartilhada e saída com um provedor falso.

Validação anterior à migração do fluxo para o kit: 148 testes do pacote e dois testes do Demo aprovados; compilação
do Demo no iPhone 18 Pro Simulator e abertura da página GitHub conferidas.
Entrega do código, retorno OAuth e login completo com contas reais continuam
pendentes. O aplicativo e o target de testes usam iOS 18+.

“Conectar” apresenta `UAPPAccountScreen`, pertencente ao pacote: login,
cadastro, confirmação de e-mail e recuperação de senha com ícone do aplicativo.
O Demo não implementa esses fluxos. O login próprio de participação do kit
continua disponível por código. Consulte [Autenticação](../../Documentation/Authentication.md)
para configurar o callback e os modelos de e-mail. Esta migração não foi
compilada nem testada, conforme orientação do proprietário.

A abertura usa `Resources/LaunchScreen.storyboard`, configurado no target por
`UILaunchStoryboardName`. O iOS apresenta o fundo roxo e o mascote enquanto
inicializa o processo, e o app entra diretamente em `ContentView`, sem splash
SwiftUI, temporizador ou atraso artificial. Ao retornar de segundo plano, o app
continua na tela atual sem reapresentar a abertura. A launch screen pertence ao
app de exemplo; aplicativos que consomem o pacote configuram sua própria tela
de abertura no target do aplicativo.

Quando há largura útil nos dois lados, como no iPhone Duo aberto em paisagem,
a tela inicial divide configuração e atalhos em dois painéis com
`ArrangementView` (iOS 27.1+). Com o Duo fechado, aberto em retrato ou em uma
janela estreita, um único `Form` mostra primeiro a configuração e depois os
atalhos. O layout é decidido pela size class, geometria local e região da
dobradiça; versões anteriores do iOS mantêm um `HStack` simples.

## App para Mac

O target `UAPPKitDemoMac` (scheme de mesmo nome, macOS 14+) é um app Mac
nativo para testar o kit no computador. A janela principal tem uma barra
lateral com:

- **Início**: projeto (`public_slug`) e servidor, salvos com as mesmas chaves do
  app do iPhone; botões que abrem cada tela do kit em janela própria por
  `UAPPKit.show…`; a conta (entrar, criar conta, abrir o perfil ou sair); e o
  perfil local (nome, e-mail e foto), com o mesmo modelo e as mesmas regras do
  app do iPhone.
- **Novidades embutidas**: o Changelog colocado na navegação do próprio app,
  sem `show…`.

O target é assinado com a equipe do projeto (`DEVELOPMENT_TEAM`), para a
assinatura não mudar a cada build: sem isso, o macOS pede a senha das chaves
"login" sempre que o app acessa a sessão guardada.

O menu Ajuda recebe os itens de `UAPPKitCommands`, e o item "Sobre" do menu do
app abre a tela Sobre do kit. O argumento `--mock-data` usa os mesmos dados
fictícios do app do iPhone. O target usa App Sandbox com acesso à rede e a
arquivos escolhidos pela pessoa (para a foto de perfil) e o esquema
`uappkit` para o retorno do login.

O projeto referencia o pacote pelo caminho local. Para gerar o projeto Xcode,
execute `xcodegen generate` neste diretório e abra `UAPPKitDemo.xcodeproj`.
