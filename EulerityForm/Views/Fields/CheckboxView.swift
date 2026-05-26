//
//  CheckboxView.swift
//  EulerityForm
//
//  Custom checkbox (Toggle's checkbox style is macOS-only). Tapping
//  the box toggles state; tapping the label also toggles state EXCEPT
//  when the tap falls on a link substring — that opens the URL instead.
//
//  AttributedString with .link attributes handles the link tap natively
//  inside SwiftUI Text on iOS 15+, so we get correct behavior for free.
//

import SwiftUI

struct CheckboxFieldView: View {
    let config: CheckboxFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    private var errorMessage: String? { viewModel.error(for: config.id) }
    private var isChecked: Bool { viewModel.values[config.id]?.asBool ?? false }

    /// Color for clickable substrings inside the label.
    /// JSON-provided override takes precedence; falls back to theme.text.
    private var linkColor: Color {
        if let hex = config.clickableTextColor, let parsed = Color(hex: hex) {
            return parsed
        }
        return theme.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                // The box itself
                Button {
                    viewModel.boolBinding(for: config.id).wrappedValue.toggle()
                } label: {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .foregroundColor(isChecked ? theme.text : theme.border)
                }
                .buttonStyle(.plain)

                // The label — links inside the AttributedString handle their
                // own taps natively (opens URL in Safari). We deliberately do
                // NOT add .onTapGesture to the whole label: SwiftUI's gesture
                // resolution would let the outer gesture eat link taps and
                // break the rich text behavior. Users toggle the checkbox via
                // the box; they tap links to open URLs. Clean separation.
                Text(attributedLabel)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                if config.required {
                    Text("*").foregroundColor(theme.error)
                }
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(theme.error)
                    .padding(.leading, 34)  // Align under label
            }
        }
    }

    private var attributedLabel: AttributedString {
        RichTextLabel.build(
            label: config.label,
            metadata: config.metadata,
            baseColor: theme.text,
            linkColor: linkColor
        )
    }
}
