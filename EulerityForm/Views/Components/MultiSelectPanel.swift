//
//  MultiSelectPanel.swift
//  EulerityForm
//
//  The expanding panel for multi-select dropdowns. Owns a local "draft"
//  selection set. Tapping rows mutates the draft. Apply commits to the
//  view model; Cancel discards. Closing via outside tap also discards.
//
//  Scrolls if there are more than 5 options. Each row supports up to 2
//  lines of label text, with the checkbox vertically centered.
//
//  This view is the opened body — the closed-state header (chips, chevron)
//  lives in DropdownView and toggles this in/out of the layout.
//

import SwiftUI

struct MultiSelectPanel: View {
    let options: [DropdownOption]
    let initialSelection: [String]
    let theme: Theme
    let onCancel: () -> Void
    let onApply: ([String]) -> Void

    @State private var draft: Set<String> = []
    @State private var didInitialize = false

    private let visibleRowCount = 5
    private let rowMinHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            optionsList
            Divider().background(theme.border)
            actionBar
        }
        .background(theme.background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            // Only initialize once. Re-renders mustn't reset the draft.
            if !didInitialize {
                draft = Set(initialSelection)
                didInitialize = true
            }
        }
    }

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
        // Cap height to visibleRowCount rows. Past that, scrolls.
        .frame(maxHeight: CGFloat(visibleRowCount) * rowMinHeight)
    }

    private func optionRow(_ option: DropdownOption) -> some View {
        let isSelected = draft.contains(option.id)
        return Button {
            if isSelected {
                draft.remove(option.id)
            } else {
                draft.insert(option.id)
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(isSelected ? theme.text : theme.border)
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

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .foregroundColor(theme.text.opacity(0.7))
            Spacer()
            Button {
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
