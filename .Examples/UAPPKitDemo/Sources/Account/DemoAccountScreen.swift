import SwiftUI
import UIKit
import UAPPKit

enum DemoAccountDestination: String, Identifiable {
    case connect, profile, user
    var id: String { rawValue }
}

/// Apenas o perfil local do Demo. A autenticação é apresentada pelo UAPPKit.
struct DemoAccountScreen: View {
    private enum Field: Hashable {
        case name, email
    }

    @ObservedObject var model: DemoAccountModel
    let languageIdentifier: String
    let theme: UAPPTheme
    @Environment(\.dismiss) private var dismiss
    @State private var profileDetent: PresentationDetent = .medium
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 12) {
                    if model.hasProfile {
                        Button(role: .destructive) {
                            focusedField = nil
                            model.removeProfile()
                        } label: {
                            Text(t("Apagar perfil local", "Delete local profile"))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    Button {
                        focusedField = nil
                        model.saveProfile()
                        dismiss()
                    } label: {
                        Text(t("Salvar perfil", "Save profile"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canSaveProfile)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .navigationTitle(t("Preencher perfil", "Fill in profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(t("Fechar", "Close"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        focusedField = .name
                    } label: {
                        Label(t("Campo anterior", "Previous field"), systemImage: "chevron.up")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(focusedField != .email)
                    Button {
                        focusedField = .email
                    } label: {
                        Label(t("Próximo campo", "Next field"), systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(focusedField != .name)
                    Spacer()
                    Button(t("Fechar teclado", "Dismiss keyboard")) {
                        focusedField = nil
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $profileDetent)
        .onChange(of: focusedField) { _, field in
            if field != nil {
                withAnimation { profileDetent = .large }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            focusedField = nil
            withAnimation { profileDetent = .medium }
        }
    }

    private var profileSection: some View {
        Section {
            UAPPProfilePhotoPicker(photo: $model.photo, theme: theme, languageIdentifier: languageIdentifier)
                .controlSize(.small)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden, edges: .bottom)
            TextField(t("Nome", "Name"), text: $model.name)
                .textContentType(.name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
            TextField(t("E-mail do perfil", "Profile email"), text: $model.email)
                .keyboardType(.emailAddress).textContentType(.emailAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
        } header: {
            Text(t("Perfil sem autenticação", "Profile without authentication"))
        } footer: {
            Text(t(
                "O feedback e o roadmap usam este perfil sem pedir login. Ao enviar um feedback, nome, e-mail e foto são salvos no UAPP para identificar o autor.",
                "Feedback and roadmap use this profile without asking you to sign in. When you submit feedback, your name, email and photo are saved in UAPP to identify the author."
            ))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func t(_ portuguese: String, _ english: String) -> String { model.text(portuguese, english, languageIdentifier) }
}
