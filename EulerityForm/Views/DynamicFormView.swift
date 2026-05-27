//
//  DynamicFormView.swift
//  EulerityForm
//
//  The root view. Iterates the (already-sorted) fields from the schema
//  and dispatches each one to the right subview via an exhaustive switch
//  on the FormField enum.
//

import SwiftUI

struct DynamicFormView: View {
    @StateObject var viewModel: FormViewModel
    @State private var showingSuccessAlert = false

    /// Focus state for any text-style field in the form. Each TextFieldView
    /// registers itself with `.focused($focusedField, equals: config.id)`.
    /// The Done button in the keyboard accessory bar clears this to dismiss
    /// the keyboard.
    @FocusState private var focusedField: String?

    /// Observes UIResponder keyboard notifications. We position the Done bar
    /// manually using this height because SwiftUI's automatic keyboard
    /// avoidance has been unpredictable on iOS 26 when combined with
    /// ZStack + .ignoresSafeArea + .safeAreaInset — Save kept being lifted
    /// above the keyboard despite multiple modifier combinations.
    @StateObject private var keyboard = KeyboardObserver()

    private var isKeyboardVisible: Bool { keyboard.height > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed title at top
            Text(viewModel.schema.formTitle)
                .font(.title2.bold())
                .foregroundColor(viewModel.schema.theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Scrolling form fields
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.schema.fields, id: \.id) { field in
                        fieldView(for: field)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .scrollDismissesKeyboard(.interactively)

            // Bottom bar — switches between Save (no keyboard) and Done (keyboard active)
            bottomBar
        }
        .background(viewModel.schema.theme.background.ignoresSafeArea())
        // Critical: this prevents the whole VStack from being lifted by
        // SwiftUI's automatic keyboard avoidance. Without it the entire
        // form shifts up when the keyboard opens, which is exactly what
        // we don't want.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: viewModel.savedPayload) { payload in
            if payload != nil { showingSuccessAlert = true }
        }
        .alert("Form Submitted", isPresented: $showingSuccessAlert, presenting: viewModel.savedPayload) { _ in
            Button("OK") { viewModel.savedPayload = nil }
        } message: { payload in
            Text(payload)
        }
    }

    // MARK: - Bottom bar
    //
    // One slot at the bottom of the screen. When the keyboard is visible, it
    // shows the Done button positioned just above the keyboard. When the
    // keyboard is hidden, it shows the Save button at the screen bottom.
    //
    // They share the same slot rather than overlapping or competing for
    // space, which avoids the Save-on-top-of-Done issue.

    @ViewBuilder
    private var bottomBar: some View {
        if isKeyboardVisible {
            doneBar
                // Position above the keyboard. We subtract the bottom safe
                // area inset because the keyboard frame already includes it,
                // and our VStack already accounts for the safe area at the
                // bottom — without this subtraction we'd get a double gap.
                .padding(.bottom, keyboard.height - bottomSafeAreaInset)
                .transition(.opacity)
        } else {
            saveButton
                .transition(.opacity)
        }
    }

    private var saveButton: some View {
        Button(action: { viewModel.attemptSave() }) {
            Text("Save")
                .font(.headline)
                .foregroundColor(viewModel.schema.theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.schema.theme.text)
                .cornerRadius(10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var doneBar: some View {
        HStack {
            Spacer()
            Button {
                focusedField = nil
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// Reads the bottom safe area inset from the active window. Needed because
    /// UIResponder.keyboardFrameEndUserInfoKey gives the keyboard's frame in
    /// screen coordinates, which includes the home-indicator inset that our
    /// VStack already respects. We subtract it to avoid a double gap.
    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets
            .bottom ?? 0
    }

    /// Exhaustive switch — the compiler enforces we handle every case.
    /// `.unknown` is filtered out by FormSchema before it reaches here,
    /// but we still need the case for exhaustiveness.
    @ViewBuilder
    private func fieldView(for field: FormField) -> some View {
        switch field {
        case .text(let config):
            TextFieldView(
                config: config,
                theme: viewModel.schema.theme,
                viewModel: viewModel,
                focusedField: $focusedField
            )
        case .dropdown(let config):
            DropdownView(config: config, theme: viewModel.schema.theme, viewModel: viewModel)
        case .toggle(let config):
            ToggleFieldView(config: config, theme: viewModel.schema.theme, viewModel: viewModel)
        case .checkbox(let config):
            CheckboxFieldView(config: config, theme: viewModel.schema.theme, viewModel: viewModel)
        case .unknown:
            EmptyView()
        }
    }
}
