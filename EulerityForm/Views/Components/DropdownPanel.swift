//
//  DropdownPanel.swift
//  EulerityForm
//
//  The unified inline panel for both single-select and multi-select
//  dropdowns. Behavior diverges in two places:
//
//  - Multi mode: rows show checkboxes, taps mutate a local draft set,
//    Cancel/Apply buttons at the bottom commit or discard the draft.
//
//  - Single mode: rows show radio buttons, tapping a row immediately
//    commits the selection and asks the parent to close. No draft state,
//    no action bar.
//
//  Both modes share: scroll cap at 5 rows, two-line label support with
//  the selection indicator vertically centered, the same chrome.
//
//  Mode is fixed at construction — passing the wrong handlers for the
//  wrong mode is a programmer error caught by the Mode enum.
//

import SwiftUI

struct DropdownPanel: View {
    enum Mode {
        /// Multi-select: tap rows to toggle a draft set; Apply commits, Cancel discards.
        case multi(initial: [String], onCancel: () -> Void, onApply: ([String]) -> Void)
        /// Single-select: tap a row to commit and close; no separate Apply needed.
        case single(initial: String?, onSelect: (String) -> Void)
    }

    let options: [DropdownOption]
    let theme: Theme
    let mode: Mode

    @State private var draft: Set<String> = []
    @State private var didInitialize = false

    private let visibleRowCount = 5
    private let rowMinHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            optionsList
            if case .multi = mode {
                Divider().background(theme.border)
                actionBar
            }
        }
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            // Initialize draft once. Re-renders mustn't reset it.
            // Only relevant in multi mode; single mode doesn't use draft.
            if !didInitialize {
                if case .multi(let initial, _, _) = mode {
                    draft = Set(initial)
                }
                didInitialize = true
            }
        }
    }

    // MARK: - Options list

    private var optionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    optionRow(option)
                    if index < options.count - 1 {
                        Divider().background(theme.border.opacity(0.4))
                    }
                }
            }
        }
        // Cap at visibleRowCount rows. ScrollView handles overflow.
        .frame(maxHeight: CGFloat(visibleRowCount) * rowMinHeight)
    }

    private func optionRow(_ option: DropdownOption) -> some View {
        let isSelected = isOptionSelected(option.id)
        return Button {
            handleTap(option)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                indicator(isSelected: isSelected)
                Text(option.label)
                    .font(.subheadline)
                    .foregroundColor(theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Selected-state indicator. Checkbox for multi, radio for single.
    @ViewBuilder
    private func indicator(isSelected: Bool) -> some View {
        switch mode {
        case .multi:
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(isSelected ? theme.text : theme.border)
        case .single:
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(isSelected ? theme.text : theme.border)
        }
    }

    // MARK: - Selection helpers

    private func isOptionSelected(_ id: String) -> Bool {
        switch mode {
        case .multi:
            return draft.contains(id)
        case .single(let initial, _):
            return initial == id
        }
    }

    private func handleTap(_ option: DropdownOption) {
        switch mode {
        case .multi:
            // Toggle in the local draft. Apply commits to VM.
            if draft.contains(option.id) {
                draft.remove(option.id)
            } else {
                draft.insert(option.id)
            }
        case .single(_, let onSelect):
            // Commit immediately and let the parent close.
            onSelect(option.id)
        }
    }

    // MARK: - Action bar (multi mode only)

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                if case .multi(_, let onCancel, _) = mode {
                    onCancel()
                }
            }
            .foregroundColor(theme.text.opacity(0.7))

            Spacer()

            Button {
                guard case .multi(_, _, let onApply) = mode else { return }
                // Preserve option order in the committed array (matches
                // the order chips render in the closed-state header).
                let result = options.map(\.id).filter { draft.contains($0) }
                onApply(result)
            } label: {
                Text("Apply")
                    .fontWeight(.semibold)
                    .foregroundColor(theme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(theme.text)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}
