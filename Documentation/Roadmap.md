# Roadmap e limites conhecidos

## Estado desta primeira separação

UAPPKit cobre leitura de conteúdo público, submissão de feedback, reações,
comentários moderados e views SwiftUI para Feedback, Roadmap e Changelog.
Não há cache local ou modo offline, notificações push, uploads de screenshot,
captura automática de versão/build ou tradução automática do conteúdo dinâmico
publicado pelo projeto.

A interface nativa já usa um String Catalog com seleção manual de idioma,
preferência inicial derivada do app hospedeiro e persistência da escolha do
usuário. Conteúdo vindo do UAPP, como títulos e descrições publicados, continua
sendo exibido no idioma em que foi cadastrado no painel. Na tela Sobre, a
biografia usa primeiro a tradução cadastrada no UAPP; se ela não existir para
o idioma selecionado, pode ser traduzida sob demanda pelo framework Apple
Translation.

## Direção futura do kit Apple

O planejamento mais amplo do ecossistema Apple considera uma camada SwiftUI
compartilhada para tokens semânticos, tipografia adaptada a Dynamic Type,
espaçamento, raio, elevação e temas configuráveis por aplicativo. Também
considera componentes de feedback, changelog e notificações, com serviços
injetáveis, previews e mocks.

Requisitos de design previstos incluem:

- manter semântica de estado independente da cor de marca do aplicativo;
- alvos de toque de pelo menos 44 pt no iOS;
- navegação nativa adaptada a iPadOS e macOS;
- conteúdo compacto e legível no watchOS, se vier a ser suportado;
- temas claro/escuro, acessibilidade e localização;
- testes de Dynamic Type, acessibilidade, localização e funcionamento offline;
- não exigir Core Data, StoreKit ou dados específicos de um aplicativo.

Essas ideias não alteram os destinos nem o contrato suportado pelo pacote
atual. watchOS, tvOS e visionOS exigem implementação e validação próprias
antes de serem declarados compatíveis.

## Evolução técnica considerada

- ativar e documentar verificação server-side das assinaturas;
- adicionar cache local e fallback offline para leitura;
- permitir filtros adicionais e refinamentos de paginação para o changelog;
- enriquecer as telas nativas e ampliar a cobertura de localização;
- avaliar upload de screenshots com consentimento, limites e remoção de
  metadados antes do envio;
- planejar notificações push somente com desenho de backend e armazenamento
  seguro de tokens APNs.

Itens deste roadmap não são promessas de prazo nem capacidades da versão atual.
