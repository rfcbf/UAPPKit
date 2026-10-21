#if canImport(SwiftUI)
import SwiftUI

struct UAPPSubmitFeedbackScreen: View {
    private enum Field: Hashable {
        case title
        case description
    }

    static let minimumTitleLength = 3

    let sender: UAPPFeedbackSender
    var accentColor: Color?
    let onComplete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.uappTheme) private var theme
    #if os(macOS)
    private var closer = UAPPScreenCloser()
    #endif
    @AppStorage(UAPPLocalizationPreferences.presentationStorageKey)
    private var selectedLanguage = UAPPLocalizationPreferences.defaultIdentifier
    @State private var title = ""
    @State private var details = ""
    @State private var imageData: [Data] = []
    @State private var isProcessingImage = false
    @State private var category: UAPPFeedbackCategory = .feature
    @State private var isSending = false
    @State private var errorMessage: UAPPFeedbackSubmitFailure?
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .body) private var descriptionMinHeight: CGFloat = 140
    @ScaledMetric(relativeTo: .title2) private var headerIconSize: CGFloat = 52

    private var palette: UAPPResolvedPalette {
        theme.resolved(for: colorScheme)
    }

    private var resolvedAccent: Color {
        palette.accent ?? accentColor ?? .accentColor
    }

    private var trimmedTitleLength: Int {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        touchBody
        #endif
    }

    #if os(macOS)
    /// Compositor no Mac: formulário agrupado do sistema, tipo em controle segmentado e uma
    /// única barra no rodapé com Cancelar (Esc) e Enviar (⌘↩), como as sheets do Mac.
    private var macBody: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(UAPPFeedbackCategory.allCases, id: \.self) { option in
                        macCategoryChip(option)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: uappLocalized("feedback.compose.intro"))
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: uappLocalized("feedback.field.type"))
                }
            }

            Section {
                TextField(
                    text: $title,
                    prompt: Text(verbatim: uappLocalized("feedback.compose.title_placeholder"))
                ) {
                    Text(verbatim: uappLocalized("feedback.field.title"))
                }
                .labelsHidden()
                .focused($focusedField, equals: .title)
                .onSubmit { focusedField = .description }
            } header: {
                Text(verbatim: uappLocalized("feedback.field.title"))
            } footer: {
                if !title.isEmpty, trimmedTitleLength < Self.minimumTitleLength {
                    Text(verbatim: uappLocalized("feedback.compose.title_hint"))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextEditor(text: $details)
                    .focused($focusedField, equals: .description)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if details.isEmpty {
                            Text(verbatim: uappLocalized("feedback.compose.description_placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(Text(verbatim: uappLocalized("feedback.field.description")))
            } header: {
                macSectionHeader("feedback.field.description", detail: uappLocalized("feedback.compose.optional"))
            }

            Section {
                UAPPFeedbackComposerAttachments(
                    data: $imageData,
                    isProcessing: $isProcessingImage,
                    accent: .secondary,
                    palette: palette
                )
            } header: {
                macSectionHeader(
                    "feedback.compose.attachments",
                    detail: "\(imageData.count)/\(UAPPFeedbackComposerAttachments.limit)"
                )
            } footer: {
                Text(verbatim: uappLocalized("feedback.compose.attachments_hint"))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(isSending)
        .safeAreaInset(edge: .bottom, spacing: 0) { macActionBar }
        .navigationTitle(Text(verbatim: uappLocalized("feedback.new_title")))
        .environment(\.locale, Locale(identifier: selectedLanguage))
        .uappToast(message: Binding(
            get: { errorMessage?.message },
            set: {
                if $0 == nil {
                    errorMessage = nil
                }
            }
        ))
        .uappMacSheetFrame(width: 600, height: 640, minHeight: 520)
        .onAppear { focusedField = .title }
    }

    private var macActionBar: some View {
        HStack(spacing: 10) {
            if isSending || isProcessingImage {
                ProgressView().controlSize(.small)
            }
            Spacer(minLength: 0)
            Button(uappLocalized("common.cancel")) { closer() }
                .keyboardShortcut(.cancelAction)
            Button(uappLocalized("common.send")) {
                focusedField = nil
                Task { await submit() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    /// Cartão de tipo no Mac: ícone e nome numa linha, com o selecionado realçado na cor do sistema.
    private func macCategoryChip(_ option: UAPPFeedbackCategory) -> some View {
        let isSelected = option == category
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { category = option }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: option.composerSymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(UAPPFeedbackCategoryBadge.color(for: option))
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(verbatim: uappLocalized(option.composerTitleKey))
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.primary.opacity(0.03), in: shape)
            .overlay {
                shape.strokeBorder(Color.primary.opacity(isSelected ? 0.55 : 0.12), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func macSectionHeader(_ key: String, detail: String) -> some View {
        HStack {
            Text(verbatim: uappLocalized(key))
            Spacer()
            Text(verbatim: detail)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }
    #endif

    #if !os(macOS)
    private var touchBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                introHeader
                categorySection
                titleSection
                descriptionSection
                attachmentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(palette.background.ignoresSafeArea())
        .foregroundStyle(palette.primaryText)
        .tint(resolvedAccent)
        .environment(\.locale, Locale(identifier: selectedLanguage))
        #if canImport(UIKit)
        .toolbar(.visible, for: .navigationBar)
        #endif
        .uappNavigationBar(
            titleKey: "feedback.new_title",
            accentColor: resolvedAccent
        )
        .uappKeyboardFieldNavigation(
            focusedField: $focusedField,
            fields: [.title, .description],
            accentColor: resolvedAccent
        )
        .safeAreaInset(edge: .bottom) {
            sendBar
        }
        .uappToast(message: Binding(
            get: { errorMessage?.message },
            set: {
                if $0 == nil {
                    errorMessage = nil
                }
            }
        ))
    }

    // MARK: - Seções

    private var introHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: category.composerSymbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(resolvedAccent)
                .frame(width: headerIconSize, height: headerIconSize)
                .background(
                    resolvedAccent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .id(category)
                .uappMotionTransition(.scale(scale: 0.85).combined(with: .opacity))
                .accessibilityHidden(true)

            Text(verbatim: uappLocalized("feedback.compose.intro"))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("feedback.field.type")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(UAPPFeedbackCategory.allCases, id: \.self) { option in
                    categoryChip(option)
                }
            }
        }
    }

    private func categoryChip(_ option: UAPPFeedbackCategory) -> some View {
        let isSelected = option == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                category = option
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: option.composerSymbol)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 22)
                    .accessibilityHidden(true)
                Text(verbatim: uappLocalized(option.composerTitleKey))
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .uappMotionTransition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? resolvedAccent : palette.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? resolvedAccent.opacity(colorScheme == .dark ? 0.2 : 0.1) : palette.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? resolvedAccent : palette.separator.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("feedback.field.title")
            TextField(
                uappLocalized("feedback.field.title"),
                text: $title,
                prompt: Text(verbatim: uappLocalized("feedback.compose.title_placeholder"))
            )
            .textFieldStyle(.plain)
            .font(.body)
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .description }
            .disabled(isSending)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(fieldBackground(isFocused: focusedField == .title))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .title }

            if !title.isEmpty, trimmedTitleLength < Self.minimumTitleLength {
                Label {
                    Text(verbatim: uappLocalized("feedback.compose.title_hint"))
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: trimmedTitleLength < Self.minimumTitleLength)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("feedback.field.description", detailKey: "feedback.compose.optional")
            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text(verbatim: uappLocalized("feedback.compose.description_placeholder"))
                        .foregroundStyle(palette.secondaryText)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $details)
                    .focused($focusedField, equals: .description)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: descriptionMinHeight)
                    .disabled(isSending)
                    .accessibilityLabel(Text(verbatim: uappLocalized("feedback.field.description")))
            }
            .font(.body)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(fieldBackground(isFocused: focusedField == .description))
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "feedback.compose.attachments",
                detail: "\(imageData.count)/\(UAPPFeedbackComposerAttachments.limit)"
            )
            UAPPFeedbackComposerAttachments(
                data: $imageData,
                isProcessing: $isProcessingImage,
                accent: resolvedAccent,
                palette: palette
            )
            .disabled(isSending)
            Text(verbatim: uappLocalized("feedback.compose.attachments_hint"))
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sendBar: some View {
        Button {
            focusedField = nil
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView().tint(palette.buttonText)
                } else {
                    Image(systemName: "paperplane.fill")
                        .accessibilityHidden(true)
                }
                Text(verbatim: uappLocalized("common.send"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(palette.buttonText)
            .background(resolvedAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .opacity(canSend || isSending ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: canSend)
        .frame(maxWidth: 640)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            palette.background
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        }
    }

    // MARK: - Componentes

    private func sectionHeader(_ key: String, detailKey: String) -> some View {
        sectionHeader(key, detail: uappLocalized(detailKey))
    }

    private func sectionHeader(_ key: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: uappLocalized(key))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let detail {
                Text(verbatim: detail)
                    .monospacedDigit()
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
            }
        }
    }

    private func fieldBackground(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(palette.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? resolvedAccent : palette.separator.opacity(0.5),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
    #endif

    private var canSend: Bool {
        !isSending && !isProcessingImage && trimmedTitleLength >= Self.minimumTitleLength
    }

    private func submit() async {
        isSending = true
        errorMessage = nil
        do {
            try await sender.send(UAPPFeedbackSubmission(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                imagesData: imageData
            ))
            onComplete()
        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                errorMessage = sender.failure(for: error)
            }
        }
        isSending = false
    }
}

extension UAPPSubmitFeedbackScreen {
    /// Envia pelo cliente do projeto, como a lista de Feedback.
    init(client: UAPPClient, accentColor: Color? = nil, onComplete: @escaping () -> Void) {
        self.init(sender: .client(client), accentColor: accentColor, onComplete: onComplete)
    }

    /// Abre o compositor com título, descrição e tipo já preenchidos.
    init(
        client: UAPPClient,
        accentColor: Color? = nil,
        draft: UAPPFeedbackDraft,
        onComplete: @escaping () -> Void
    ) {
        self.init(sender: .client(client), accentColor: accentColor, draft: draft, onComplete: onComplete)
    }

    /// Abre o compositor preenchido com o envio informado.
    init(
        sender: UAPPFeedbackSender,
        accentColor: Color? = nil,
        draft: UAPPFeedbackDraft,
        onComplete: @escaping () -> Void
    ) {
        self.init(sender: sender, accentColor: accentColor, onComplete: onComplete)
        _title = State(initialValue: draft.title)
        _details = State(initialValue: draft.details)
        _category = State(initialValue: draft.category)
    }
}
#endif
