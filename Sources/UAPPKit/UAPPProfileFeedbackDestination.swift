import SwiftUI

struct UAPPProfileFeedbackDestination: View {
    @ObservedObject var model: UAPPUserModel
    let itemId: String
    let accentColor: Color
    @State private var page: UAPPFeedbackPage?
    @State private var failed = false

    var body: some View {
        Group {
            if let item = page?.items.first(where: { $0.id == itemId }), let client = model.profileClient {
                UAPPFeedbackDetailScreen(client: client, item: item, accentColor: accentColor,
                                         status: page?.statuses.first { $0.id == item.statusId })
            } else if failed {
                VStack(spacing: 16) {
                    Text(verbatim: uappLocalized("user.activity_error"))
                    Button(uappLocalized("user.retry")) { Task { await load() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard page == nil else { return }
        failed = false
        do {
            let result = try await model.feedbackPage(itemId: itemId)
            guard !Task.isCancelled else { return }
            guard result?.items.contains(where: { $0.id == itemId }) == true else {
                failed = true
                return
            }
            page = result
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
