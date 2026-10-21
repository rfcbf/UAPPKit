#if canImport(SwiftUI)
import SwiftUI

/// Lista avaliações da App Store importadas e publicadas pelo UAPP.
public struct UAPPReviewsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @StateObject private var model: UAPPReviewsModel

    /// Configura o tamanho das páginas, ajustado ao limite da API de 1 a 50 itens.
    public init(client: UAPPClient, pageSize: Int) {
        _model = StateObject(wrappedValue: UAPPReviewsModel(client: client, pageSize: pageSize))
    }

    init(
        client: UAPPClient,
        testingReviews reviews: [UAPPReview],
        isLoading: Bool,
        hasError: Bool = false
    ) {
        _model = StateObject(wrappedValue: UAPPReviewsModel(client: client, reviews: reviews, isLoading: isLoading, hasError: hasError))
    }

    init(model: UAPPReviewsModel) {
        _model = StateObject(wrappedValue: model)
    }

    /// Cantos do bloco de avaliações: só o primeiro e o último item são arredondados.
    static func rowShape(isFirst: Bool, isLast: Bool) -> UnevenRoundedRectangle {
        let radius = UAPPSurface.largeCornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? radius : 0,
            bottomLeadingRadius: isLast ? radius : 0,
            bottomTrailingRadius: isLast ? radius : 0,
            topTrailingRadius: isFirst ? radius : 0,
            style: .continuous
        )
    }

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    public var body: some View {
        screenBody.uappTextSizeLimit()
    }

    private var screenBody: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.hasError {
                UAPPUnavailableContent(
                    message: uappLocalized("reviews.load_error"),
                    accentColor: palette.accent ?? .accentColor
                ) {
                    Task { await model.load() }
                }
            } else if model.reviews.isEmpty {
                UAPPReviewEmptyState(palette: palette)
            } else {
                List {
                    if let summary = model.summary {
                        UAPPReviewSummaryCard(summary: summary, palette: palette)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 14, trailing: 4))
                            .listRowSeparator(.hidden)
                    }
                    ForEach(model.reviews) { review in
                        VStack(alignment: .leading, spacing: 0) {
                            UAPPReviewCard(review: review, targetIdentifier: selectedLanguage, palette: palette, translationCache: model.translationCache)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                            if review.id != model.reviews.last?.id {
                                Divider()
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .background(
                            palette.cardBackground,
                            in: Self.rowShape(
                                isFirst: review.id == model.reviews.first?.id,
                                isLast: review.id == model.reviews.last?.id
                            )
                        )
                        .listRowBackground(Color.clear)
                        // As avaliações formam um bloco só, com os cantos do primeiro e do último
                        // arredondados e a mesma largura do resumo.
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                        .listRowSeparator(.hidden)
                    }
                    if model.isLoadingMore {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(palette.accent ?? .accentColor)
                            Text(verbatim: uappLocalized("reviews.loading_more"))
                                .font(.footnote)
                                .foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if model.nextCursor != nil {
                        if model.hasMoreError {
                            Button(uappLocalized("reviews.load_more_retry")) {
                                Task { await model.loadMore() }
                            }
                            .disabled(model.isLoadingMore)
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .id(model.nextCursor)
                                .onAppear { Task { await model.loadMore() } }
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
                .background(palette.background)
            }
        }
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .uappNavigationBar(
            titleKey: "screen.reviews",
            accentColor: palette.accent ?? .accentColor
        )
        .task {
            await model.loadIfNeeded()
            await model.loadSummaryIfNeeded()
        }
    }
}

private struct UAPPReviewEmptyState: View {
    let palette: UAPPResolvedPalette

    var body: some View {
        VStack(spacing: 18) {
            UAPPMascotIllustration(state: .emptyFeedback)
            Text(verbatim: uappLocalized("reviews.empty.title"))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: uappLocalized("reviews.empty.message"))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 520)
        .uappEmptyStateSurface(palette)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
#endif
