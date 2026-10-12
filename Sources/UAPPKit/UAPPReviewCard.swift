#if canImport(SwiftUI)
import SwiftUI

struct UAPPReviewCard: View {
    let review: UAPPReview
    let targetIdentifier: String
    let palette: UAPPResolvedPalette
    let translationCache: UAPPReviewTranslationCache?
    @State private var showsResponse = false
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        palette.accent ?? .accentColor
    }

    init(review: UAPPReview, targetIdentifier: String, palette: UAPPResolvedPalette, showsResponse: Bool = false, translationCache: UAPPReviewTranslationCache? = nil) {
        self.review = review
        self.targetIdentifier = targetIdentifier
        self.palette = palette
        self.translationCache = translationCache
        _showsResponse = State(initialValue: showsResponse)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    stars
                    Spacer(minLength: 8)
                    attribution
                }
                VStack(alignment: .trailing, spacing: 8) {
                    stars.frame(maxWidth: .infinity, alignment: .leading)
                    attribution
                }
            }
            if let title = review.title, !title.isEmpty {
                UAPPReviewTranslatedText(text: title, targetIdentifier: targetIdentifier, cache: translationCache)
                    .font(.headline)
            }
            if let body = review.body, !body.isEmpty {
                UAPPReviewTranslatedText(text: body, targetIdentifier: targetIdentifier, cache: translationCache)
                    .foregroundStyle(palette.secondaryText)
            }
            if let response = review.responseBody, !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    withAnimation { showsResponse.toggle() }
                } label: {
                    Label(
                        uappLocalized(showsResponse ? "reviews.hide_response" : "reviews.show_response"),
                        systemImage: showsResponse ? "chevron.up" : "bubble.left.and.text.bubble.right"
                    )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(accent.opacity(colorScheme == .dark ? 0.2 : 0.1), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
                .padding(.vertical, 6)
                .accessibilityValue(Text(verbatim: uappLocalized(showsResponse ? "reviews.expanded" : "reviews.collapsed")))
                if showsResponse {
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text(verbatim: uappLocalized("reviews.developer_response"))
                        } icon: {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .foregroundStyle(accent)
                                .accessibilityHidden(true)
                        }
                        .font(.caption.weight(.semibold))
                        UAPPReviewTranslatedText(text: response, targetIdentifier: targetIdentifier, cache: translationCache)
                            .font(.subheadline)
                    }
                    .padding(12)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        accent.opacity(colorScheme == .dark ? 0.14 : 0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(accent)
                            .frame(width: 3)
                            .padding(.vertical, 10)
                            .accessibilityHidden(true)
                    }
                    .uappMotionTransition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var stars: some View {
        HStack(spacing: 3) {
            ForEach(1 ... 5, id: \.self) { value in
                Image(systemName: value <= review.rating ? "star.fill" : "star")
                    .foregroundStyle(palette.accent ?? .yellow)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: uappLocalizedFormat("reviews.rating", review.rating)))
    }

    private var attribution: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(verbatim: review.reviewerName ?? uappLocalized("common.user"))
            if let date = review.reviewedAt {
                Text(date, format: .dateTime.day().month().year())
            }
        }
        .font(.caption)
        .foregroundStyle(palette.secondaryText)
        .multilineTextAlignment(.trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
