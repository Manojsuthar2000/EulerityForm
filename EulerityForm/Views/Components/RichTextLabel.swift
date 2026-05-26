//
//  RichTextLabel.swift
//  EulerityForm
//
//  Builds an AttributedString from a label and a metadata map of
//  substring -> URL. Substrings present in the label become tappable
//  links styled with `clickableTextColor` (or theme.text if absent).
//
//  Used by CheckboxFieldView. AttributedString supports native tap-to-open
//  in SwiftUI Text on iOS 15+, so no gesture plumbing needed.
//

import SwiftUI

enum RichTextLabel {

    /// Builds an AttributedString where every key of `metadata` that
    /// appears as a substring of `label` is styled and linkified.
    /// Multiple links in one label are supported.
    static func build(
        label: String,
        metadata: [String: String]?,
        baseColor: Color,
        linkColor: Color
    ) -> AttributedString {
        var attributed = AttributedString(label)
        attributed.foregroundColor = baseColor

        guard let metadata, !metadata.isEmpty else { return attributed }

        for (substring, urlString) in metadata {
            guard let url = URL(string: urlString) else { continue }

            // Find the substring in the attributed string. We do a
            // case-sensitive search — that's the convention in the spec.
            // If a substring appears multiple times we link the first match;
            // doing all matches would also be reasonable.
            if let range = attributed.range(of: substring) {
                attributed[range].link = url
                attributed[range].foregroundColor = linkColor
                attributed[range].underlineStyle = .single
            }
        }

        return attributed
    }
}
