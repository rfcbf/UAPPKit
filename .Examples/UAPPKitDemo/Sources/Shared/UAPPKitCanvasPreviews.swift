import Foundation
import SwiftUI
import UAPPKit

#Preview("Feedback · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPFeedbackScreen(client: DemoCanvasPreview.client, mode: .feedback)
    }
}

#Preview("Roadmap · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPRoadmapScreen(client: DemoCanvasPreview.client)
    }
}

#Preview("Changelog · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPFeedbackScreen(client: DemoCanvasPreview.client, mode: .changelog)
    }
}

#Preview("Avaliações · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPReviewsScreen(client: DemoCanvasPreview.client, pageSize: 20)
    }
}

#Preview("Sobre do desenvolvedor · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPDeveloperAboutScreen(client: DemoCanvasPreview.client)
    }
}

#Preview("Sobre do aplicativo · CalcJuros DEV") {
    DemoCanvasNavigation {
        UAPPAboutScreen(configuration: UAPPAboutConfiguration(
            shortDescription: "Feedback público para aplicativos independentes.",
            descriptionLanguageIdentifier: "pt-BR",
            websiteURL: URL(string: "https://uapp.example.com"),
            supportURL: URL(string: "mailto:suporte@uapp.example.com"),
            privacyPolicyURL: URL(string: "https://uapp.example.com/privacy"),
            license: "MIT"
        ))
    }
}

private struct DemoCanvasNavigation<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack { content }
            .preferredColorScheme(.light)
    }
}

@MainActor
enum DemoCanvasPreview {
    static let client = UAPPClient(
        configuration: UAPPConfiguration(
            projectId: "calcjuros-dev",
            host: URL(string: "https://zmmdvtykqbpwkwddjeyb.supabase.co")!
        ),
        transport: DemoCanvasPreviewTransport()
    )
}

private struct DemoCanvasPreviewTransport: UAPPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let resource = request.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "resource" })?.value
        }
        let cursor = request.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "cursor" })?.value
        }
        if resource == "changelog", cursor != nil {
            try await Task.sleep(for: .seconds(1))
        }
        let payload = Data(DemoCanvasPayload.response(for: resource, cursor: cursor).utf8)
        let url = request.url ?? URL(string: "https://localhost")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (payload, response)
    }
}

private enum DemoCanvasPayload {
    static func response(for resource: String?, cursor: String? = nil) -> String {
        switch resource {
        case "feedback": feedback
        case "roadmap": roadmap
        case "changelog": cursor == nil ? changelog : olderChangelog
        case "reviews": reviews
        default: about
        }
    }

    private static let feedback = #"""
    {
      "project": { "slug": "calcjuros-dev", "displayName": "CalcJuros", "primaryColor": "#2F6344", "locale": "pt-BR" },
      "items": [
        { "id": "feedback-1", "title": "Adicionar simulador de parcelas", "body": "Uma forma rápida de comparar diferentes condições de pagamento.", "vote_count": 24, "like_count": 8, "public_comment_count": 5, "category": "feature", "priority": 1, "viewer_voted": false, "viewer_liked": false },
        { "id": "feedback-2", "title": "Exibir o valor total com juros", "body": "Facilitaria a comparação entre as opções.", "vote_count": 13, "like_count": 4, "public_comment_count": 2, "category": "improvement", "priority": 2, "viewer_voted": true, "viewer_liked": false }
      ],
      "nextCursor": null
    }
    """#

    private static let roadmap = #"""
    {
      "project": { "slug": "calcjuros-dev", "displayName": "CalcJuros", "primaryColor": "#2F6344", "locale": "pt-BR" },
      "statuses": [
        { "id": "status-planned", "key": "planned", "name": "Planejado", "position": 0, "isRoadmapVisible": true },
        { "id": "status-progress", "key": "in_progress", "name": "Em andamento", "position": 1, "isRoadmapVisible": true },
        { "id": "status-done", "key": "done", "name": "Concluído", "position": 2, "isRoadmapVisible": true }
      ],
      "items": [
        { "id": "roadmap-1", "title": "Adicionar simulador de parcelas", "body": "Comparação de cenários de pagamento.", "status_id": "status-planned", "vote_count": 24, "like_count": 8, "public_comment_count": 5, "category": "feature", "priority": 1, "viewer_voted": false, "viewer_liked": false },
        { "id": "roadmap-2", "title": "Melhorar acessibilidade dos resultados", "body": null, "status_id": "status-progress", "vote_count": 17, "like_count": 6, "public_comment_count": 3, "category": "improvement", "priority": 2, "viewer_voted": false, "viewer_liked": true },
        { "id": "roadmap-3", "title": "Corrigir arredondamento de taxas", "body": null, "status_id": "status-done", "vote_count": 9, "like_count": 2, "public_comment_count": 1, "category": "bug", "priority": 3, "viewer_voted": false, "viewer_liked": false }
      ]
    }
    """#

    private static let changelog = #"""
    {
      "project": { "slug": "calcjuros-dev", "displayName": "CalcJuros", "primaryColor": "#2F6344", "locale": "pt-BR" },
      "entries": [
        { "title": "Mais clareza nos resultados", "slug": "resultados-2-4", "body_md": "Agora ficou mais fácil entender **quanto será pago** ao final.\n\nResumo do custo total.\n\nComparação de cenários.\n\nHistórico atualizado.\n\nArredondamento corrigido.", "description_md": "Agora ficou mais fácil entender **quanto será pago** ao final. Compare as opções, acompanhe seu histórico e consulte cada melhoria desta versão.", "version": "2.4.0", "build": "240", "platform": "ios", "sections": [
          { "category": "improved", "body_md": "Resumo do custo total e dos juros em destaque. Os valores estão organizados para facilitar a leitura e a comparação entre diferentes condições de pagamento.", "image_url": "https://picsum.photos/id/1018/1200/630", "position": 0 },
          { "category": "new", "body_md": "1. Compare cenários de pagamento.\n2. Encontre a opção mais adequada.\n\nCada simulação mantém seus valores e taxas separados.", "image_url": "https://picsum.photos/id/1015/1200/630", "position": 1 },
          { "category": "improved", "body_md": "- **O histórico ganhou uma apresentação mais clara.**\n\nConsulte seus cálculos anteriores com *mais facilidade*.", "image_url": "https://picsum.photos/id/1016/1200/630", "position": 2 },
          { "category": "fixed", "body_md": "Corrigido o arredondamento de taxas mensais.", "position": 3 }
        ], "released_at": "2026-09-20" },
        { "title": "Correções e estabilidade", "slug": "correcoes-2-3", "body_md": "Pequenos ajustes para deixar os cálculos ainda mais confiáveis.", "version": "2.3.2", "build": "232", "platform": "all", "sections": [{ "category": "fixed", "body_md": "Corrigido um caso de arredondamento em taxas mensais.", "position": 0 }], "released_at": "2026-09-02" }
      ],
      "nextCursor": "older-changelog",
      "totalCount": 4
    }
    """#

    private static let olderChangelog = #"""
    {
      "entries": [
        { "title": "Histórico de cálculos", "slug": "historico-2-2", "body_md": "Consulte os cálculos anteriores no histórico.", "version": "2.2.0", "build": "220", "released_at": "2026-08-15" },
        { "title": "Primeira versão", "slug": "primeira-1-0", "body_md": "Primeira versão com cálculo de juros e comparação de parcelas.", "version": "1.0.0", "build": "100", "released_at": "2026-07-01" }
      ],
      "nextCursor": null,
      "totalCount": 4
    }
    """#

    private static let reviews = #"""
    {
      "project": { "slug": "calcjuros-dev", "displayName": "CalcJuros", "primaryColor": "#2F6344", "locale": "pt-BR" },
      "reviews": [
        { "id": "review-1", "rating": 5, "title": "Simples e muito útil", "body": "Consigo conferir os juros rapidamente antes de fechar uma compra. Muito bom!", "reviewer_nickname": "Mariana", "reviewed_at": "2026-09-18T12:00:00Z" },
        { "id": "review-2", "rating": 4, "title": "Resolve o que preciso", "body": "Direto ao ponto e fácil de usar.", "reviewer_nickname": "Rafael", "reviewed_at": "2026-09-12T12:00:00Z" }
      ]
    }
    """#

    private static let about = #"""
    {
      "project": { "slug": "calcjuros-dev", "displayName": "CalcJuros", "publicBaseURL": "https://uapp.renatoferraz.net", "appStoreUrl": "https://apps.apple.com/app/id6753683438", "appleAppId": "6753683438", "primaryColor": "#2F6344", "locale": "pt-BR" },
      "about": {
        "developer_name": null,
        "developer_image_url": null,
        "developer_bio": "Oi! Sou o Renato, criador de aplicativos e apaixonado por tecnologia. 💡📱\n\nGosto de transformar ideias em experiências simples, úteis e agradáveis de usar. Por trás de cada projeto tem muita curiosidade, café e vontade de aprender. ☕✨\n\nEstou sempre experimentando, melhorando e criando coisas novas. 🚀",
        "about_apps": [
          { "name": "MediCasa", "subtitle": "Gerencia suas medicações e sua farmácia residencial.", "appStoreURL": "https://apps.apple.com/app/id6753683438", "appleAppId": "6753683438", "iconURL": null },
          { "name": "Parcelamento", "subtitle": null, "appStoreURL": "https://apps.apple.com/app/id904013167", "appleAppId": "904013167", "iconURL": null }
        ],
        "social_links": {
          "youtube": "https://www.youtube.com/@CasalSemFronteira",
          "instagram": "https://www.instagram.com/renatoferrazdf",
          "linkedin": "https://www.linkedin.com/in/rfcbf/",
          "x": "https://x.com/",
          "facebook": "https://www.facebook.com/",
          "tiktok": "https://www.tiktok.com/"
        }
      }
    }
    """#
}
