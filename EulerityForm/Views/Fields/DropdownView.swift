//
//  DropdownView.swift
//  EulerityForm
//
//  DROPDOWN renderer. Two modes:
//
//  - Single-select: uses iOS Menu — taps an option, menu dismisses,
//    selection commits immediately. The simple case where Menu works fine.
//
//  - Multi-select: custom UI. Closed state shows a chip area with each
//    selected option as a removable chip (× clears that one immediately,
//    no Apply needed). Open state shows a panel BELOW the field with
//    checkbox rows; the panel uses its own draft state, with Cancel and
//    Apply buttons. Apply commits to the view model. Cancel discards.
//
//  Empty-options edge case: rendered as a non-interactive placeholder.
//  Validation still fails for required fields, so the user sees the
//  problem on Save.
//

import SwiftUI

struct DropdownView: View {
    let config: DropdownFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    @State private var isPanelOpen = false

    // Shown error: suppress while the panel is open so we're not yelling
    // at the user while they're actively fixing the field.
    private var errorMessage: String? {
        guard !isPanelOpen else { return nil }
        return viewModel.error(for: config.id)
    }
    private var borderColor: Color { errorMessage != nil ? theme.error : theme.border }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RequiredLabel.build(
                label: config.label,
                required: config.required,
                textColor: theme.text,
                errorColor: theme.error
            ))
            .font(.subheadline)

            // Closed-state header (always visible)
            headerView
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Multi-select panel — inline, pushes content below down
            if isPanelOpen && config.allowMultiple && !config.options.isEmpty {
                MultiSelectPanel(
                    options: config.options,
                    initialSelection: viewModel.values[config.id]?.asMultiSelect ?? [],
                    theme: theme,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) { isPanelOpen = false }
                    },
                    onApply: { newSelection in
                        viewModel.multiSelectBinding(for: config.id).wrappedValue = newSelection
                        withAnimation(.easeInOut(duration: 0.15)) { isPanelOpen = false }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(theme.error)
            }
        }
    }

    // MARK: - Header (closed state)

    @ViewBuilder
    private var headerView: some View {
        if config.options.isEmpty {
            emptyOptionsHeader
        } else if config.allowMultiple {
            multiSelectHeader
        } else {
            singleSelectHeader
        }
    }

    private var emptyOptionsHeader: some View {
        HStack {
            Text("No options available")
                .foregroundColor(theme.text.opacity(0.5))
                .italic()
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundColor(theme.text.opacity(0.3))
        }
    }

    // MARK: - Single select (Menu — simple, closes on tap)

    private var singleSelectHeader: some View {
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
                    .foregroundColor(isSinglePlaceholder ? theme.text.opacity(0.5) : theme.text)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(theme.text.opacity(0.6))
            }
        }
    }

    private var isSinglePlaceholder: Bool {
        viewModel.values[config.id]?.asSingleSelect == nil
    }

    private var currentLabelForSingleSelect: String {
        if let id = viewModel.values[config.id]?.asSingleSelect,
           let option = config.options.first(where: { $0.id == id }) {
            return option.label
        }
        return "Select…"
    }

    // MARK: - Multi select header (chips + chevron, taps open the panel)

    private var multiSelectHeader: some View {
        // The whole header is one tap target — taps anywhere except a chip's
        // × button toggle the panel. Chip × is handled by SelectedChipsView
        // via its own Button, which absorbs taps.
        let selected = viewModel.values[config.id]?.asMultiSelect ?? []
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isPanelOpen.toggle()
            }
        } label: {
            HStack(alignment: .top) {
                if selected.isEmpty {
                    Text("Select…")
                        .foregroundColor(theme.text.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    SelectedChipsView(
                        options: config.options,
                        selectedIds: selected,
                        theme: theme,
                        onRemove: { id in
                            // Immediate removal — no Apply needed (per spec)
                            var updated = selected
                            updated.removeAll { $0 == id }
                            viewModel.multiSelectBinding(for: config.id).wrappedValue = updated
                        }
                    )
                }
                Image(systemName: isPanelOpen ? "chevron.up" : "chevron.down")
                    .foregroundColor(theme.text.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .buttonStyle(.plain)
    }
}
