# UAPPKit Demo

Aplicativo SwiftUI para testar as telas nativas de Feedback, Roadmap e
Changelog do pacote durante o desenvolvimento.

A tela inicial permite informar o `public_slug` do app e o servidor Supabase,
salvar essas configurações no dispositivo e testar a conexão antes de abrir as
telas do UAPPKit.

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

O projeto referencia o pacote pelo caminho local. Para gerar o projeto Xcode,
execute `xcodegen generate` neste diretório e abra `UAPPKitDemo.xcodeproj`.
