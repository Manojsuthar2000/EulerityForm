//
//  DropdownView.swift
//  EulerityForm
//
//  DROPDOWN renderer. Single-select uses a Menu with options.
//  Multi-select uses a Menu containing checkbox-style buttons that
//  toggle each option without dismissing the menu.
//
//  Empty options array (a required edge case) renders a disabled
//  control with a "No options available" placeholder. The field still
//  fails validation, since it can never be satisfied.
//

import SwiftUI

struct DropdownView: View {
    let config: DropdownFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    private var errorMessage: String? { viewModel.error(for: config.id) }
    private var borderColor: Color { errorMessage != nil ? theme.error : theme.border }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(config.label).foregroundColor(theme.text)
                if config.required {
                    Text("*").foregroundColor(theme.error)
                }
            }
            .font(.subheadline)

            menuContent
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(theme.error)
            }
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if config.options.isEmpty {
            // Empty options edge case — render a non-interactive placeholder.
            // Validation still fails for required fields, so user gets feedback
            // on Save tap.
            HStack {
                Text("No options available")
                    .foregroundColor(theme.text.opacity(0.5))
                    .italic()
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(theme.text.opacity(0.3))
            }
        } else if config.allowMultiple {
            multiSelectMenu
        } else {
            singleSelectMenu
        }
    }

    // MARK: - Single select

    private var singleSelectMenu: some View {
        Menu {
            ForEach(config.options) { option in
                Button {
                    viewModel.singleSelectBinding(for: config.id).wrappedValue = option.id
                } label: {
                    if viewModel.values[config.id]?.asSingleSelect == option.id {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text(currentLabelForSingleSelect)
                    .foregroundColor(currentLabelForSingleSelect == placeholderText
                                     ? theme.text.opacity(0.5)
                                     : theme.text)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(theme.text.opacity(0.6))
            }
        }
    }

    private var placeholderText: String { "Select…" }

    private var currentLabelForSingleSelect: String {
        if let id = viewModel.values[config.id]?.asSingleSelect,
           let option = config.options.first(where: { $0.id == id }) {
            return option.label
        }
        return placeholderText
    }

    // MARK: - Multi select

    private var multiSelectMenu: some View {
        Menu {
            ForEach(config.options) { option in
                // Toggle without dismissing — iOS keeps Menu open if we
                // pass `.continuous` via a wrapper. Simpler approach:
                // just provide a Button; user can re-tap the menu to keep
                // multi-selecting. (Apple changed this behavior across
                // iOS versions; this is the lowest-friction stable approach
                // on iOS 16.)
                Button {
                    viewModel.toggleMultiSelect(fieldId: config.id, optionId: option.id)
                } label: {
                    let selected = viewModel.values[config.id]?.asMultiSelect.contains(option.id) ?? false
                    if selected {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack {
                Text(currentLabelForMultiSelect)
                    .foregroundColor(currentLabelForMultiSelect == placeholderText
                                     ? theme.text.opacity(0.5)
                                     : theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(theme.text.opacity(0.6))
            }
        }
    }

    private var currentLabelForMultiSelect: String {
        let selected = viewModel.values[config.id]?.asMultiSelect ?? []
        if selected.isEmpty { return placeholderText }
        let labels = selected.compactMap { id in
            config.options.first(where: { $0.id == id })?.label
        }
        if labels.count <= 2 {
            return labels.joined(separator: ", ")
        }
        return "\(labels.count) selected"
    }
}
