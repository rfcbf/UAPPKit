import SwiftUI

struct UAPPStatusBadge: View {
    let status: UAPPRoadmapColumn.Status?
    var title: String? = nil
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    var body: some View {
        Text(verbatim: title ?? uappFeedbackStatusTitle(status, languageIdentifier: selectedLanguage))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(UAPPFeedbackStatusStyle.color(for: status), in: Capsule())
    }
}

struct UAPPStatusProgress: View {
    let status: UAPPRoadmapColumn.Status
    let statuses: [UAPPRoadmapColumn.Status]

    private var progress: CGFloat {
        let maximum = statuses.map(\.position).max() ?? 0
        return maximum > 0 ? min(1, max(0, CGFloat(status.position) / CGFloat(maximum))) : 0
    }

    var body: some View {
        ZStack {
            Circle().strokeBorder(UAPPFeedbackStatusStyle.color(for: status).opacity(0.2), lineWidth: 2)
            Circle().trim(from: 0, to: progress)
                .stroke(UAPPFeedbackStatusStyle.color(for: status), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(1).rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

@MainActor
struct UAPPStatusFilterOptions: View {
    let statuses: [UAPPRoadmapColumn.Status]
    @Binding var selection: String?
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier

    var body: some View {
        Picker(selection: $selection) {
            Text(verbatim: uappLocalized("feedback.filter.all_statuses"))
                .tag(Optional<String>.none)
            ForEach(statuses.sorted { $0.position < $1.position }, id: \.id) { status in
                Label {
                    Text(verbatim: uappFeedbackStatusTitle(status, languageIdentifier: selectedLanguage))
                } icon: {
                    menuImage(status)
                }
                .tag(Optional(status.id))
            }
        } label: {
            Text(verbatim: uappLocalized("feedback.filter.status"))
        }
    }

    private func menuImage(_ status: UAPPRoadmapColumn.Status) -> Image {
        // O menu nativo recebe imagens; preserve o anel colorido como imagem original.
        let renderer = ImageRenderer(content: UAPPStatusProgress(status: status, statuses: statuses))
        renderer.scale = 3
        #if canImport(UIKit)
        if let image = renderer.uiImage { return Image(uiImage: image).renderingMode(.original) }
        #elseif canImport(AppKit)
        if let image = renderer.nsImage { return Image(nsImage: image).renderingMode(.original) }
        #endif
        return Image(systemName: "circle")
    }
}
