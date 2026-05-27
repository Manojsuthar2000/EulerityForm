//
//  RequiredLabel.swift
//  EulerityForm
//
//  Builds an AttributedString for "Label *" where the asterisk is part of
//  the same Text run. This is important: when the label wraps to multiple
//  lines, the asterisk stays inline with the last word instead of floating
//  off to the side of the HStack like it used to.
//

import SwiftUI

enum RequiredLabel {
    /// Returns an AttributedString combining the label and a red asterisk
    /// when required. Without `required`, the asterisk is omitted entirely.
    static func build(
        label: String,
        required: Bool,
        textColor: Color,
        errorColor: Color
    ) -> AttributedString {
        var attributed = AttributedString(label)
        attributed.foregroundColor = textColor

        if required {
            var star = AttributedString(" *")
            star.foregroundColor = errorColor
            attributed += star
        }

        return attributed
    }

    /// For checkbox: combines label + asterisk + supports the metadata
    /// link substrings (linkified inline). Single AttributedString → wraps
    /// naturally and the asterisk hugs the last word.
    static func buildCheckboxLabel(
        label: String,
        required: Bool,
        metadata: [String: String]?,
        textColor: Color,
        errorColor: Color,
        linkColor: Color
    ) -> AttributedString {
        var attributed = AttributedString(label)
        attributed.foregroundColor = textColor

        if let metadata {
            for (substring, urlString) in metadata {
                guard let url = URL(string: urlString) else { continue }
                if let range = attributed.range(of: substring) {
                    attributed[range].link = url
                    attributed[range].foregroundColor = linkColor
                    attributed[range].underlineStyle = .single
                }
            }
        }

        if required {
            var star = AttributedString(" *")
            star.foregroundColor = errorColor
            attributed += star
        }

        return attributed
    }
}
