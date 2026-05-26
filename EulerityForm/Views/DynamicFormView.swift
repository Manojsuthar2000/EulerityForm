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
        .onChange(of: viewModel.savedPayload) { payload in
            if payload != nil { showingSuccessAlert = true }
        }
        .alert("Form Submitted", isPresented: $showingSuccessAlert, presenting: viewModel.savedPayload) { _ in
            Button("OK") { viewModel.savedPayload = nil }
        } message: { payload in
            Text(payload)
        }
    }

    /// Exhaustive switch — the compiler enforces we handle every case.
    /// `.unknown` is filtered out by FormSchema before it reaches here,
    /// but we still need the case for exhaustiveness.
    @ViewBuilder
    private func fieldView(for field: FormField) -> some View {
        switch field {
        case .text(let config):
            TextFieldView(config: config, theme: viewModel.schema.theme, viewModel: viewModel)
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
