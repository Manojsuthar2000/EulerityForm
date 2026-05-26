//
//  TextFieldView.swift
//  EulerityForm
//
//  Renders a TEXT field. Branches on subtype for keyboard / SecureField /
//  TextEditor. Counter and error display are subtype-agnostic.
//

import SwiftUI

struct TextFieldView: View {
    let config: TextFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    private var errorMessage: String? { viewModel.error(for: config.id) }
    private var isOverLimit: Bool {
        viewModel.isOverMaxLength(fieldId: config.id, maxLength: config.maxLength)
    }
    private var hasError: Bool { errorMessage != nil }

    /// Border color reflects the most urgent state.
    /// Error (red) > over-limit (red) > normal theme border.
    private var borderColor: Color {
        if hasError || isOverLimit { return theme.error }
        return theme.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label with required asterisk
            HStack(spacing: 2) {
                Text(config.label).foregroundColor(theme.text)
                if config.required {
                    Text("*").foregroundColor(theme.error)
                }
            }
            .font(.subheadline)

            // The actual input — branches on subtype
            inputField
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Counter + error row
            HStack(alignment: .top) {
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(theme.error)
                }
                Spacer(minLength: 8)
                if let max = config.maxLength {
                    let current = viewModel.values[config.id]?.asText.count ?? 0
                    Text("\(current)/\(max)")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(isOverLimit ? theme.error : theme.text.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch config.subtype {
        case .plain:
            TextField(config.placeholder ?? "", text: viewModel.textBinding(for: config.id))
                .foregroundColor(theme.text)
                .textInputAutocapitalization(.sentences)

        case .multiline:
            // Axis-constrained TextField grows naturally on iOS 16+
            TextField(
                config.placeholder ?? "",
                text: viewModel.textBinding(for: config.id),
                axis: .vertical
            )
            .lineLimit(3...8)
            .foregroundColor(theme.text)

        case .number:
            TextField(config.placeholder ?? "", text: viewModel.textBinding(for: config.id))
                .keyboardType(.decimalPad)
                .foregroundColor(theme.text)

        case .uri:
            TextField(config.placeholder ?? "", text: viewModel.textBinding(for: config.id))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(theme.text)

        case .secure:
            SecureField(config.placeholder ?? "", text: viewModel.textBinding(for: config.id))
                .foregroundColor(theme.text)
        }
    }
}
