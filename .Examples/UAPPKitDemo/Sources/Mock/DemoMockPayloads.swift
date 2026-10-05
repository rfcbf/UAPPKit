import Foundation

// Gerado para o modo de demonstração; todos os nomes, textos e números são fictícios.
// swiftlint:disable file_length line_length
extension DemoMockData {

    static let feedbackJSON = #"""
{
  "project": {
    "slug": "uapp-demo",
    "displayName": "UAPP",
    "locale": "pt-BR",
    "appStoreURL": "https://apps.apple.com/app/id0000000000"
  },
  "items": [
    {
      "id": "20000000-0000-4000-8000-000000000001",
      "title": "Modo escuro automático conforme o horário",
      "body": "Seria ótimo se o aplicativo pudesse alternar entre o modo claro e o escuro automaticamente, de acordo com o horário do dia.\n\nHoje é preciso mudar manualmente nos ajustes, e muitas vezes esqueço de voltar para o modo claro pela manhã.",
      "vote_count": 128,
      "like_count": 0,
      "public_comment_count": 4,
      "category": "feature",
      "priority": 0,
      "viewer_voted": true,
      "viewer_liked": false,
      "created_at": "2026-09-28T14:20:00Z",
      "author_name": "Alex Lorem",
      "author_avatar_url": "https://i.pravatar.cc/200?img=12",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "voters": [
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        },
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        },
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        }
      ],
      "image_urls": [
        "https://picsum.photos/seed/uapp-feedback-a/900/600",
        "https://picsum.photos/seed/uapp-feedback-b/900/600"
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000002",
      "title": "Melhorar a busca com filtros por data",
      "body": "A busca funciona bem, mas seria muito útil poder filtrar os resultados por período e por categoria.",
      "vote_count": 42,
      "like_count": 0,
      "public_comment_count": 2,
      "category": "improvement",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-24T09:05:00Z",
      "author_name": "Sam Ipsum",
      "author_avatar_url": "https://i.pravatar.cc/200?img=32",
      "status_id": "10000000-0000-4000-8000-000000000003",
      "voters": [
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        },
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000003",
      "title": "Notificações chegam com atraso",
      "body": "Às vezes as notificações só aparecem alguns minutos depois do horário configurado, principalmente quando o aparelho está em modo de economia de bateria.",
      "vote_count": 17,
      "like_count": 0,
      "public_comment_count": 1,
      "category": "bug",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-19T18:40:00Z",
      "author_name": "Dani Dolor",
      "author_avatar_url": "https://i.pravatar.cc/200?img=47",
      "status_id": "10000000-0000-4000-8000-000000000001",
      "voters": [
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        },
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000004",
      "title": "Como exportar meus dados para uma planilha?",
      "body": "Não encontrei a opção de exportação. Existe alguma forma de gerar um arquivo com todos os meus registros?",
      "vote_count": 9,
      "like_count": 0,
      "public_comment_count": 0,
      "category": "question",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-12T11:15:00Z",
      "author_name": "Alex Lorem",
      "author_avatar_url": "https://i.pravatar.cc/200?img=12",
      "status_id": "10000000-0000-4000-8000-000000000004",
      "voters": [
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000005",
      "title": "Widget para a tela de início",
      "body": "Um widget com o resumo do dia ajudaria muito a acompanhar as informações sem precisar abrir o aplicativo.",
      "vote_count": 5,
      "like_count": 0,
      "public_comment_count": 0,
      "category": "feature",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-05T08:30:00Z",
      "author_name": "Sam Ipsum",
      "author_avatar_url": "https://i.pravatar.cc/200?img=32",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "voters": [
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        }
      ]
    }
  ],
  "nextCursor": null,
  "statuses": [
    {
      "id": "10000000-0000-4000-8000-000000000001",
      "key": "under_review",
      "name": "Em análise",
      "position": 0,
      "isRoadmapVisible": true,
      "color": "#8E8E93"
    },
    {
      "id": "10000000-0000-4000-8000-000000000002",
      "key": "planned",
      "name": "Planejado",
      "position": 1,
      "isRoadmapVisible": true,
      "color": "#5856D6"
    },
    {
      "id": "10000000-0000-4000-8000-000000000003",
      "key": "in_progress",
      "name": "Em andamento",
      "position": 2,
      "isRoadmapVisible": true,
      "color": "#FF9500"
    },
    {
      "id": "10000000-0000-4000-8000-000000000004",
      "key": "done",
      "name": "Concluído",
      "position": 3,
      "isRoadmapVisible": true,
      "color": "#34C759"
    }
  ]
}
"""#

    static let roadmapJSON = #"""
{
  "project": {
    "slug": "uapp-demo",
    "displayName": "UAPP",
    "locale": "pt-BR",
    "appStoreURL": "https://apps.apple.com/app/id0000000000"
  },
  "statuses": [
    {
      "id": "10000000-0000-4000-8000-000000000001",
      "key": "under_review",
      "name": "Em análise",
      "position": 0,
      "isRoadmapVisible": true,
      "color": "#8E8E93"
    },
    {
      "id": "10000000-0000-4000-8000-000000000002",
      "key": "planned",
      "name": "Planejado",
      "position": 1,
      "isRoadmapVisible": true,
      "color": "#5856D6"
    },
    {
      "id": "10000000-0000-4000-8000-000000000003",
      "key": "in_progress",
      "name": "Em andamento",
      "position": 2,
      "isRoadmapVisible": true,
      "color": "#FF9500"
    },
    {
      "id": "10000000-0000-4000-8000-000000000004",
      "key": "done",
      "name": "Concluído",
      "position": 3,
      "isRoadmapVisible": true,
      "color": "#34C759"
    }
  ],
  "items": [
    {
      "id": "20000000-0000-4000-8000-000000000001",
      "title": "Modo escuro automático conforme o horário",
      "body": "Seria ótimo se o aplicativo pudesse alternar entre o modo claro e o escuro automaticamente, de acordo com o horário do dia.\n\nHoje é preciso mudar manualmente nos ajustes, e muitas vezes esqueço de voltar para o modo claro pela manhã.",
      "vote_count": 128,
      "like_count": 0,
      "public_comment_count": 4,
      "category": "feature",
      "priority": 0,
      "viewer_voted": true,
      "viewer_liked": false,
      "created_at": "2026-09-28T14:20:00Z",
      "author_name": "Alex Lorem",
      "author_avatar_url": "https://i.pravatar.cc/200?img=12",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "voters": [
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        },
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        },
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        }
      ],
      "image_urls": [
        "https://picsum.photos/seed/uapp-feedback-a/900/600",
        "https://picsum.photos/seed/uapp-feedback-b/900/600"
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000002",
      "title": "Melhorar a busca com filtros por data",
      "body": "A busca funciona bem, mas seria muito útil poder filtrar os resultados por período e por categoria.",
      "vote_count": 42,
      "like_count": 0,
      "public_comment_count": 2,
      "category": "improvement",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-24T09:05:00Z",
      "author_name": "Sam Ipsum",
      "author_avatar_url": "https://i.pravatar.cc/200?img=32",
      "status_id": "10000000-0000-4000-8000-000000000003",
      "voters": [
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        },
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000003",
      "title": "Notificações chegam com atraso",
      "body": "Às vezes as notificações só aparecem alguns minutos depois do horário configurado, principalmente quando o aparelho está em modo de economia de bateria.",
      "vote_count": 17,
      "like_count": 0,
      "public_comment_count": 1,
      "category": "bug",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-19T18:40:00Z",
      "author_name": "Dani Dolor",
      "author_avatar_url": "https://i.pravatar.cc/200?img=47",
      "status_id": "10000000-0000-4000-8000-000000000001",
      "voters": [
        {
          "displayName": "Dani Dolor",
          "avatarUrl": "https://i.pravatar.cc/200?img=47"
        },
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000004",
      "title": "Como exportar meus dados para uma planilha?",
      "body": "Não encontrei a opção de exportação. Existe alguma forma de gerar um arquivo com todos os meus registros?",
      "vote_count": 9,
      "like_count": 0,
      "public_comment_count": 0,
      "category": "question",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-12T11:15:00Z",
      "author_name": "Alex Lorem",
      "author_avatar_url": "https://i.pravatar.cc/200?img=12",
      "status_id": "10000000-0000-4000-8000-000000000004",
      "voters": [
        {
          "displayName": "Alex Lorem",
          "avatarUrl": "https://i.pravatar.cc/200?img=12"
        }
      ]
    },
    {
      "id": "20000000-0000-4000-8000-000000000005",
      "title": "Widget para a tela de início",
      "body": "Um widget com o resumo do dia ajudaria muito a acompanhar as informações sem precisar abrir o aplicativo.",
      "vote_count": 5,
      "like_count": 0,
      "public_comment_count": 0,
      "category": "feature",
      "priority": 0,
      "viewer_voted": false,
      "viewer_liked": false,
      "created_at": "2026-09-05T08:30:00Z",
      "author_name": "Sam Ipsum",
      "author_avatar_url": "https://i.pravatar.cc/200?img=32",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "voters": [
        {
          "displayName": "Sam Ipsum",
          "avatarUrl": "https://i.pravatar.cc/200?img=32"
        }
      ]
    }
  ]
}
"""#

    static let changelogJSON = #"""
{
  "project": {
    "slug": "uapp-demo",
    "displayName": "UAPP",
    "locale": "pt-BR",
    "appStoreURL": "https://apps.apple.com/app/id0000000000"
  },
  "nextCursor": null,
  "totalCount": 3,
  "entries": [
    {
      "title": "Novos temas e busca aprimorada",
      "slug": "versao-2-1",
      "version": "2.1.0",
      "build": "210",
      "platform": "ios",
      "released_at": "2026-09-30",
      "published_at": "2026-09-30T12:00:00Z",
      "description_md": "Esta versão traz novos temas, uma busca mais rápida e várias correções pedidas pela comunidade.",
      "body_md": "",
      "sections": [
        {
          "category": "new",
          "body_md": "**Novos temas**\n\nEscolha entre seis combinações de cores para deixar o aplicativo com a sua cara.",
          "position": 0,
          "image_url": "https://picsum.photos/seed/uapp-changelog-a/1200/800"
        },
        {
          "category": "improved",
          "body_md": "**Busca mais rápida**\n\nOs resultados agora aparecem enquanto você digita, com filtros por período.",
          "position": 1,
          "image_url": "https://picsum.photos/seed/uapp-changelog-b/1200/800"
        },
        {
          "category": "fixed",
          "body_md": "Corrigimos o atraso das notificações quando o aparelho estava em modo de economia de bateria.",
          "position": 2
        }
      ]
    },
    {
      "title": "Uma nova experiência",
      "slug": "versao-2-0",
      "version": "2.0.0",
      "build": "200",
      "platform": "ios",
      "released_at": "2026-08-18",
      "published_at": "2026-08-18T12:00:00Z",
      "description_md": "Redesenhamos a tela inicial para que você encontre tudo com menos toques.",
      "body_md": "",
      "sections": [
        {
          "category": "new",
          "body_md": "**Nova tela inicial**\n\nUm resumo do seu dia logo na abertura, com atalhos para as ações mais usadas.",
          "position": 0,
          "image_url": "https://picsum.photos/seed/uapp-changelog-c/1200/800"
        },
        {
          "category": "security",
          "body_md": "Seus dados agora podem ser protegidos com Face ID ao abrir o aplicativo.",
          "position": 1
        }
      ]
    },
    {
      "title": "Melhorias de desempenho",
      "slug": "versao-1-5",
      "version": "1.5.0",
      "build": "150",
      "platform": "ios",
      "released_at": "2026-06-02",
      "published_at": "2026-06-02T12:00:00Z",
      "description_md": "O aplicativo ficou mais leve e abre mais rápido em todos os aparelhos.",
      "body_md": "",
      "sections": [
        {
          "category": "improved",
          "body_md": "A sincronização em segundo plano consome menos bateria.",
          "position": 0
        },
        {
          "category": "fixed",
          "body_md": "Corrigimos um problema que impedia a exportação de arquivos grandes.",
          "position": 1
        }
      ]
    }
  ]
}
"""#

    static let reviewsJSON = #"""
{
  "project": {
    "slug": "uapp-demo",
    "displayName": "UAPP",
    "locale": "pt-BR",
    "appStoreURL": "https://apps.apple.com/app/id0000000000"
  },
  "nextCursor": null,
  "reviews": [
    {
      "id": "40000000-0000-4000-8000-000000000001",
      "rating": 5,
      "title": "Simplesmente excelente",
      "body": "Uso todos os dias e nunca me deixou na mão. A interface é limpa, rápida e muito fácil de entender.",
      "reviewer_nickname": "lorem.ipsum",
      "reviewed_at": "2026-09-27T10:00:00Z",
      "response_body": "Muito obrigado pelo carinho! Ficamos felizes em fazer parte da sua rotina."
    },
    {
      "id": "40000000-0000-4000-8000-000000000002",
      "rating": 5,
      "title": "Recomendo para todo mundo",
      "body": "O melhor aplicativo da categoria que já testei. As atualizações são frequentes e sempre trazem novidades úteis.",
      "reviewer_nickname": "dolor_sit",
      "reviewed_at": "2026-09-21T10:00:00Z",
      "response_body": null
    },
    {
      "id": "40000000-0000-4000-8000-000000000003",
      "rating": 4,
      "title": "Muito bom, falta pouco",
      "body": "Gosto bastante, mas sinto falta de um widget para a tela de início. Com isso seria nota máxima.",
      "reviewer_nickname": "amet2026",
      "reviewed_at": "2026-09-14T10:00:00Z",
      "response_body": "Obrigado pela avaliação! O widget já está no nosso roadmap."
    },
    {
      "id": "40000000-0000-4000-8000-000000000004",
      "rating": 5,
      "title": "Suporte nota dez",
      "body": "Tive uma dúvida e fui respondido no mesmo dia. Dá para ver que a equipe se importa com os usuários.",
      "reviewer_nickname": "consectetur",
      "reviewed_at": "2026-09-02T10:00:00Z",
      "response_body": null
    },
    {
      "id": "40000000-0000-4000-8000-000000000005",
      "rating": 3,
      "title": "Bom, mas pode melhorar",
      "body": "Funciona bem na maior parte do tempo, porém as notificações às vezes chegam atrasadas.",
      "reviewer_nickname": "adipiscing_",
      "reviewed_at": "2026-08-25T10:00:00Z",
      "response_body": null
    },
    {
      "id": "40000000-0000-4000-8000-000000000006",
      "rating": 4,
      "title": "Prático e bonito",
      "body": "Design caprichado e fácil de usar. Estou gostando muito das últimas versões.",
      "reviewer_nickname": "elit.sed",
      "reviewed_at": "2026-08-11T10:00:00Z",
      "response_body": null
    }
  ]
}
"""#

    static let aboutJSON = #"""
{
  "project": {
    "slug": "uapp-demo",
    "displayName": "UAPP",
    "locale": "pt-BR",
    "appStoreURL": "https://apps.apple.com/app/id0000000000"
  },
  "about": {
    "developer_name": "Lorem Ipsum",
    "developer_image_url": "https://i.pravatar.cc/200?img=60",
    "developer_bio": "Olá! Sou uma pessoa desenvolvedora independente e crio aplicativos simples, úteis e agradáveis de usar.\n\nAcredito que os melhores produtos nascem quando ouvimos com atenção quem os utiliza todos os dias. Este espaço reúne os meus projetos e as formas de entrar em contato.",
    "developer_bio_default_language": "pt-BR",
    "developer_bio_translations": {},
    "about_apps": [
      {
        "name": "Dolor Notes",
        "subtitle": "Suas notas sempre à mão",
        "appStoreURL": "https://apps.apple.com/app/id0000000001",
        "appleAppId": "0000000001",
        "iconURL": "https://picsum.photos/seed/uapp-app-a/240/240"
      },
      {
        "name": "Amet Tasks",
        "subtitle": "Organize o seu dia",
        "appStoreURL": "https://apps.apple.com/app/id0000000002",
        "appleAppId": "0000000002",
        "iconURL": "https://picsum.photos/seed/uapp-app-b/240/240"
      },
      {
        "name": "Elit Weather",
        "subtitle": "Previsão do tempo sem complicação",
        "appStoreURL": "https://apps.apple.com/app/id0000000003",
        "appleAppId": "0000000003",
        "iconURL": "https://picsum.photos/seed/uapp-app-c/240/240"
      }
    ],
    "social_links": {
      "x": "https://x.com/example",
      "instagram": "https://instagram.com/example",
      "youtube": "https://youtube.com/@example"
    }
  }
}
"""#

    static let commentsJSON = #"""
{
  "20000000-0000-4000-8000-000000000001": [
    {
      "id": "30000000-0000-4000-8000-000000000001",
      "body": "Também sinto falta disso! Uso o aplicativo principalmente à noite e seria perfeito.",
      "parentCommentId": null,
      "likeCount": 12,
      "createdAt": "2026-09-28T16:02:00Z",
      "authorKind": "community",
      "viewerLiked": true,
      "authorName": "Sam Ipsum",
      "authorAvatarUrl": "https://i.pravatar.cc/200?img=32",
      "moderationState": "approved",
      "viewerOwned": false
    },
    {
      "id": "30000000-0000-4000-8000-000000000002",
      "body": "Obrigado pela sugestão! Já está no nosso planejamento para a próxima versão.",
      "parentCommentId": "30000000-0000-4000-8000-000000000001",
      "likeCount": 8,
      "createdAt": "2026-09-29T10:30:00Z",
      "authorKind": "team",
      "viewerLiked": false,
      "authorName": "Equipe UAPP",
      "authorAvatarUrl": null,
      "moderationState": "approved",
      "viewerOwned": false
    },
    {
      "id": "30000000-0000-4000-8000-000000000003",
      "body": "Seria ainda melhor se desse para escolher os horários de início e de fim.",
      "parentCommentId": null,
      "likeCount": 3,
      "createdAt": "2026-09-30T08:45:00Z",
      "authorKind": "community",
      "viewerLiked": false,
      "authorName": "Dani Dolor",
      "authorAvatarUrl": "https://i.pravatar.cc/200?img=47",
      "moderationState": "approved",
      "viewerOwned": false
    },
    {
      "id": "30000000-0000-4000-8000-000000000004",
      "body": "Ótima notícia, obrigado pelo retorno tão rápido.",
      "parentCommentId": null,
      "likeCount": 1,
      "createdAt": "2026-10-01T19:10:00Z",
      "authorKind": "community",
      "viewerLiked": false,
      "authorName": "Alex Lorem",
      "authorAvatarUrl": "https://i.pravatar.cc/200?img=12",
      "moderationState": "approved",
      "viewerOwned": false
    }
  ],
  "20000000-0000-4000-8000-000000000002": [
    {
      "id": "30000000-0000-4000-8000-000000000005",
      "body": "Filtrar por categoria já resolveria a maior parte dos meus casos.",
      "parentCommentId": null,
      "likeCount": 4,
      "createdAt": "2026-09-25T12:00:00Z",
      "authorKind": "community",
      "viewerLiked": false,
      "authorName": "Dani Dolor",
      "authorAvatarUrl": "https://i.pravatar.cc/200?img=47",
      "moderationState": "approved",
      "viewerOwned": false
    },
    {
      "id": "30000000-0000-4000-8000-000000000006",
      "body": "Estamos trabalhando nisso e em breve teremos novidades.",
      "parentCommentId": null,
      "likeCount": 2,
      "createdAt": "2026-09-26T09:20:00Z",
      "authorKind": "team",
      "viewerLiked": false,
      "authorName": "Equipe UAPP",
      "authorAvatarUrl": null,
      "moderationState": "approved",
      "viewerOwned": false
    }
  ],
  "20000000-0000-4000-8000-000000000003": [
    {
      "id": "30000000-0000-4000-8000-000000000007",
      "body": "Acontece comigo também, principalmente nas notificações da manhã.",
      "parentCommentId": null,
      "likeCount": 1,
      "createdAt": "2026-09-20T07:55:00Z",
      "authorKind": "community",
      "viewerLiked": false,
      "authorName": "Alex Lorem",
      "authorAvatarUrl": "https://i.pravatar.cc/200?img=12",
      "moderationState": "approved",
      "viewerOwned": false
    }
  ]
}
"""#

    static let activityJSON = #"""
{
  "totals": {
    "likes": 0,
    "votes": 14,
    "comments": 6,
    "feedbacks": 3
  },
  "items": [
    {
      "id": "20000000-0000-4000-8000-000000000001",
      "title": "Modo escuro automático conforme o horário",
      "body": "Seria ótimo se o aplicativo pudesse alternar entre o modo claro e o escuro automaticamente, de acordo com o horário do dia.\n\nHoje é preciso mudar manualmente nos ajustes, e muitas vezes esqueço de voltar para o modo claro pela manhã.",
      "state": "published",
      "app_name": "UAPP",
      "app_slug": "uapp-demo",
      "status_key": "planned",
      "status_name": "Planejado",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "status_color": "#5856D6",
      "like_count": 0,
      "vote_count": 128,
      "public_comment_count": 4,
      "created_at": "2026-09-28T14:20:00Z"
    },
    {
      "id": "20000000-0000-4000-8000-000000000004",
      "title": "Como exportar meus dados para uma planilha?",
      "body": "Não encontrei a opção de exportação. Existe alguma forma de gerar um arquivo com todos os meus registros?",
      "state": "published",
      "app_name": "UAPP",
      "app_slug": "uapp-demo",
      "status_key": "done",
      "status_name": "Concluído",
      "status_id": "10000000-0000-4000-8000-000000000004",
      "status_color": "#34C759",
      "like_count": 0,
      "vote_count": 9,
      "public_comment_count": 0,
      "created_at": "2026-09-12T11:15:00Z"
    },
    {
      "id": "20000000-0000-4000-8000-000000000005",
      "title": "Widget para a tela de início",
      "body": "Um widget com o resumo do dia ajudaria muito a acompanhar as informações sem precisar abrir o aplicativo.",
      "state": "published",
      "app_name": "UAPP",
      "app_slug": "uapp-demo",
      "status_key": "planned",
      "status_name": "Planejado",
      "status_id": "10000000-0000-4000-8000-000000000002",
      "status_color": "#5856D6",
      "like_count": 0,
      "vote_count": 5,
      "public_comment_count": 0,
      "created_at": "2026-09-05T08:30:00Z"
    }
  ],
  "nextCursor": null,
  "statuses": [
    {
      "id": "10000000-0000-4000-8000-000000000001",
      "key": "under_review",
      "name": "Em análise",
      "position": 0,
      "isRoadmapVisible": true,
      "color": "#8E8E93"
    },
    {
      "id": "10000000-0000-4000-8000-000000000002",
      "key": "planned",
      "name": "Planejado",
      "position": 1,
      "isRoadmapVisible": true,
      "color": "#5856D6"
    },
    {
      "id": "10000000-0000-4000-8000-000000000003",
      "key": "in_progress",
      "name": "Em andamento",
      "position": 2,
      "isRoadmapVisible": true,
      "color": "#FF9500"
    },
    {
      "id": "10000000-0000-4000-8000-000000000004",
      "key": "done",
      "name": "Concluído",
      "position": 3,
      "isRoadmapVisible": true,
      "color": "#34C759"
    }
  ]
}
"""#

}
// swiftlint:enable file_length line_length
