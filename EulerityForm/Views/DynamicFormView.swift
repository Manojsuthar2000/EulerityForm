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
    ///
    /// Lives at the form root (not per-field) so we share a single keyboard
    /// accessory bar across all fields rather than declaring one per field.
    @FocusState private var focusedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text(viewModel.schema.formTitle)
                    .font(.title2.bold())
                    .foregroundColor(viewModel.schema.theme.text)

                // Fields — already sorted by `order` in FormSchema
                ForEach(viewModel.schema.fields, id: \.id) { field in
                    fieldView(for: field)
                }

                // Save button
                Button(action: { viewModel.attemptSave() }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(viewModel.schema.theme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.schema.theme.text)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(viewModel.schema.theme.background.ignoresSafeArea())
        // Swipe down on the scroll view to dismiss the keyboard. Combined
        // with the Done toolbar, this gives users two dismissal paths.
        .scrollDismissesKeyboard(.interactively)
        // Custom keyboard accessory bar.
        //
        // We deliberately don't use .toolbar(placement: .keyboard) because
        // iOS 26+ wraps toolbar buttons in a Liquid Glass capsule that
        // clips custom backgrounds (we'd see a chopped-up blue rectangle
        // inside a glass circle). The opt-out API is unreliable across
        // iOS 26 patch versions.
        //
        // Instead, we render a regular view at the bottom safe area when
        // a field is focused. The keyboard pushes our bar up with it
        // because the safe area shrinks as the keyboard appears, so the
        // accessory sits exactly at keyboard top — no glass styling involved.
        .safeAreaInset(edge: .bottom) {
            if focusedField != nil {
                keyboardAccessoryBar
            }
        }
        .onChange(of: viewModel.savedPayload) { payload in
            if payload != nil { showingSuccessAlert = true }
        }
        .alert("Form Submitted", isPresented: $showingSuccessAlert, presenting: viewModel.savedPayload) { _ in
            Button("OK") { viewModel.savedPayload = nil }
        } message: { payload in
            Text(payload)
        }
    }

    // MARK: - Keyboard accessory

    /// Custom bar that sits above the keyboard when any text field is focused.
    /// Uses safeAreaInset rather than .toolbar so we can fully control styling
    /// without iOS 26's Liquid Glass treatment.
    private var keyboardAccessoryBar: some View {
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
