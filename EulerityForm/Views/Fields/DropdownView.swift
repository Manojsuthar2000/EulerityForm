//
//  DropdownView.swift
//  EulerityForm
//
//  DROPDOWN renderer. Uses the unified DropdownPanel for both single
//  and multi-select to keep the visual language consistent across the form.
//
//  Closed states differ:
//    - Single: shows the selected option's label (or "Select…" placeholder)
//    - Multi:  shows chips with × buttons, max 3 rows, "+N" overflow
//
//  Open state is always the same inline panel below the field, with rows
//  styled by mode (radio for single, checkbox for multi) and an action bar
//  in multi mode.
//
//  Empty options array on a required field renders a non-interactive
//  placeholder and fails validation on Save.
//

import SwiftUI

struct DropdownView: View {
    let config: DropdownFieldConfig
    let theme: Theme
    @ObservedObject var viewModel: FormViewModel

    @State private var isPanelOpen = false

    // Suppress error display while the panel is open so we're not yelling
    // at the user mid-fix.
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

            headerView
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )

            if isPanelOpen && !config.options.isEmpty {
                DropdownPanel(
                    options: config.options,
                    theme: theme,
                    mode: panelMode
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(theme.error)
            }
        }
    }

    // MARK: - Panel mode wiring

    /// Builds the appropriate Mode for the panel based on field config.
    /// Closes the panel after commit in both modes (with animated batching
    /// to prevent the flicker where new selection appears before the panel
    /// transition completes).
    private var panelMode: DropdownPanel.Mode {
        if config.allowMultiple {
            return .multi(
                initial: viewModel.values[config.id]?.asMultiSelect ?? [],
                onCancel: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPanelOpen = false
                    }
                },
                onApply: { newSelection in
                    // Both state changes in one animation transaction.
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.multiSelectBinding(for: config.id).wrappedValue = newSelection
                        isPanelOpen = false
                    }
                }
            )
        } else {
            return .single(
                initial: viewModel.values[config.id]?.asSingleSelect,
                onSelect: { id in
                    // Single-select commits immediately and closes the panel.
                    // Same batched-animation pattern as multi for consistency.
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.singleSelectBinding(for: config.id).wrappedValue = id
                        isPanelOpen = false
                    }
                }
            )
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

    // MARK: - Single select header

    private var singleSelectHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPanelOpen.toggle()
            }
        } label: {
            HStack {
                Text(currentLabelForSingleSelect)
                    .foregroundColor(isSinglePlaceholder ? theme.text.opacity(0.5) : theme.text)
                Spacer()
                Image(systemName: isPanelOpen ? "chevron.up" : "chevron.down")
                    .foregroundColor(theme.text.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
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

    // MARK: - Multi select header (chips + chevron)

    private var multiSelectHeader: some View {
        let selected = viewModel.values[config.id]?.asMultiSelect ?? []
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
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
                        removeDisabled: isPanelOpen,
                        onRemove: { id in
                            // Immediate removal — no Apply needed (per spec).
                            // Disabled when panel open (see removeDisabled).
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
