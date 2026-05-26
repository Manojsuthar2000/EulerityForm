//
//  ToggleView.swift
//  EulerityForm
//
//  Standard Toggle. Required-toggle validation is handled by the VM.
//

import SwiftUI

struct ToggleFieldView: View {
    let config: ToggleFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    private var errorMessage: String? { viewModel.error(for: config.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: viewModel.boolBinding(for: config.id)) {
                HStack(spacing: 2) {
                    Text(config.label).foregroundColor(theme.text)
                    if config.required {
                        Text("*").foregroundColor(theme.error)
                    }
                }
                .font(.subheadline)
            }
            .tint(theme.border) // Use border color as the toggle accent

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(theme.error)
            }
        }
    }
}
