//
//  SelectedChipsView.swift
//  EulerityForm
//
//  Renders selected items as removable chips, wrapping to a max of 3 rows.
//  When chips exceed the cap, the last visible chip is replaced by a "+N"
//  chip showing how many are hidden.
//
//  Approach: a GeometryReader provides the available width. We compute
//  chip widths via UIKit text measurement (NSString.size) — accurate
//  enough since the font is fixed and small. Then we pack chips into
//  rows in plain Swift and render with VStack of HStacks.
//
//  Trade-off: this isn't pixel-perfect across font scaling because we
//  hardcode the font. For dynamic type support we'd need to use
//  UIFont.preferredFont. Good enough for this assessment.
//

import SwiftUI
import UIKit

struct SelectedChipsView: View {
    let options: [DropdownOption]
    let selectedIds: [String]
    let theme: Theme
    /// When true, the × buttons are visually present but tap-disabled.
    /// Used when the dropdown panel is open — chips shouldn't be mutable
    /// while the user has a draft selection in progress.
    let removeDisabled: Bool
    let onRemove: (String) -> Void

    private let maxRows = 3
    private let chipSpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 6

    var body: some View {
        // Preserve option order so chips render consistently across re-renders.
        let selected = options.filter { selectedIds.contains($0.id) }

        // GeometryReader gives us the parent's width. We use .frame(height:)
        // afterwards to size the chip area; without that, GeometryReader
        // would fill all available vertical space.
        GeometryReader { proxy in
            chipRows(available: proxy.size.width, items: selected)
        }
        .frame(height: heightForRows(count: rowCount(for: selected, width: lastKnownWidth)))
    }

    // MARK: - Render

    @State private var lastKnownWidth: CGFloat = 300  // initial guess; updated by GeometryReader

    private func chipRows(available: CGFloat, items: [DropdownOption]) -> some View {
        let plan = packRows(items: items, available: available)
        return VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(0..<plan.rows.count, id: \.self) { rowIdx in
                HStack(spacing: chipSpacing) {
                    ForEach(plan.rows[rowIdx], id: \.id) { item in
                        if item.isOverflow {
                            OverflowChip(count: plan.overflowCount, theme: theme)
                        } else {
                            Chip(
                                label: item.label,
                                theme: theme,
                                removeDisabled: removeDisabled,
                                onRemove: { onRemove(item.id) }
                            )
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Capture the available width into state so the parent frame is right
        // on the next render. Slight delay but no flicker because chip count
        // changes are user-driven, not scroll-driven.
        .onAppear { lastKnownWidth = available }
        .onChange(of: available) { lastKnownWidth = $0 }
    }

    // MARK: - Packing

    private struct Item: Identifiable {
        let id: String
        let label: String
        let isOverflow: Bool
    }

    private struct Plan {
        var rows: [[Item]]
        var overflowCount: Int
    }

    private func packRows(items: [DropdownOption], available: CGFloat) -> Plan {
        guard available > 0 else { return Plan(rows: [], overflowCount: 0) }

        let widths = items.map { chipWidth(for: $0.label) }
        let overflowW = overflowChipWidth(for: items.count)

        var rows: [[Item]] = []
        var current: [Item] = []
        var currentW: CGFloat = 0
        var idx = 0

        for (i, w) in widths.enumerated() {
            let projected = currentW + (current.isEmpty ? 0 : chipSpacing) + w
            if projected <= available || current.isEmpty {
                current.append(Item(id: items[i].id, label: items[i].label, isOverflow: false))
                currentW = projected
                idx = i
            } else {
                rows.append(current)
                if rows.count >= maxRows {
                    // We've filled max rows; current item & rest are hidden.
                    let hidden = items.count - i
                    return appendOverflowIfNeeded(rows: rows, widths: widths, overflowW: overflowW, available: available, hidden: hidden, items: items, fromIndex: i)
                }
                current = [Item(id: items[i].id, label: items[i].label, isOverflow: false)]
                currentW = w
                idx = i
            }
        }
        if !current.isEmpty { rows.append(current) }
        return Plan(rows: rows, overflowCount: 0)
    }

    /// When we've packed into maxRows but still have items left, try to
    /// fit "+N" at the end of the last row. If the last row is too full,
    /// pop chips off the end until "+N" fits.
    private func appendOverflowIfNeeded(
        rows: [[Item]],
        widths: [CGFloat],
        overflowW: CGFloat,
        available: CGFloat,
        hidden: Int,
        items: [DropdownOption],
        fromIndex: Int
    ) -> Plan {
        var rows = rows
        var hiddenCount = hidden

        // Compute current last-row width
        var lastRow = rows[rows.count - 1]
        func lastRowWidth() -> CGFloat {
            // Need to look up original widths by id
            return lastRow.reduce(0) { sum, item in
                let w = items.first(where: { $0.id == item.id }).flatMap { items.firstIndex(of: $0) }.map { widths[$0] } ?? 0
                return sum + w
            } + CGFloat(max(0, lastRow.count - 1)) * chipSpacing
        }

        while lastRowWidth() + chipSpacing + overflowW > available, !lastRow.isEmpty {
            lastRow.removeLast()
            hiddenCount += 1
        }
        // Append overflow chip to the last row
        lastRow.append(Item(id: "__overflow__", label: "", isOverflow: true))
        rows[rows.count - 1] = lastRow

        return Plan(rows: rows, overflowCount: hiddenCount)
    }

    // MARK: - Measurement

    /// Estimates chip width using UIKit text measurement of the label plus
    /// fixed padding for the × button and surrounding chrome.
    private func chipWidth(for label: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        let labelSize = (label as NSString).size(withAttributes: [.font: font])
        // padding: 8 (lead) + 8 (trail) + 6 (gap to ×) + 14 (× incl. padding)
        return ceil(labelSize.width) + 8 + 8 + 6 + 14
    }

    private func overflowChipWidth(for total: Int) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption1).withWeight(.medium)
        let text = "+\(total)"
        let size = (text as NSString).size(withAttributes: [.font: font])
        return ceil(size.width) + 16  // h-padding 8+8
    }

    private func rowCount(for items: [DropdownOption], width: CGFloat) -> Int {
        let plan = packRows(items: items, available: width)
        return max(1, plan.rows.count)
    }

    private func heightForRows(count: Int) -> CGFloat {
        let chipHeight: CGFloat = 26  // approx caption + padding
        return CGFloat(count) * chipHeight + CGFloat(max(0, count - 1)) * rowSpacing
    }
}

// MARK: - Chip subviews

private struct Chip: View {
    let label: String
    let theme: Theme
    let removeDisabled: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(theme.text)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(theme.text.opacity(removeDisabled ? 0.3 : 0.7))
                    .padding(2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(removeDisabled)
            .allowsHitTesting(!removeDisabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.text.opacity(0.08))
        )
    }
}

private struct OverflowChip: View {
    let count: Int
    let theme: Theme

    var body: some View {
        Text("+\(count)")
            .font(.caption.weight(.medium))
            .foregroundColor(theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.text.opacity(0.12))
            )
    }
}

// MARK: - UIFont weight helper

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
