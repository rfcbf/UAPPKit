# Mascote UAPPKit

`Sources/UAPPKit/Resources/UAPPMascotPrototype.png` é a referência visual
aprovada: corpo creme arredondado, folhas roxas, detalhes lavanda, rosto simples
e membros curtos. Novas variações devem manter identidade, paleta, proporções e
estilo; variar somente expressão ou pose.

Variações disponíveis:

- `UAPPMascotEmptyFeedback.png`: ausência de feedback público.
- `UAPPMascotConnectionError.png`: falha ao carregar/conectar.
- `UAPPMascotEmptyChangelog.png`: changelog sem novidades.
- `UAPPMascotSuccess.png`: confirmação de sucesso.

`UAPPMascotIllustration` expõe essas artes para uso pelo pacote e pelo app de
exemplo. A tela de feedback e changelog apresenta as ilustrações nos estados
vazios; erros HTTP 403 mantêm a arte de conteúdo indisponível. A demonstração
usa as variações de conexão e sucesso no resultado do teste ao Supabase.
