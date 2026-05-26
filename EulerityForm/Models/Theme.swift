//
//  Theme.swift
//  EulerityForm
//
//  Global theme parsed from JSON. Hex strings become SwiftUI Colors.
//

import SwiftUI

struct Theme: Codable, Equatable {
    let backgroundColor: String
    let textColor: String
    let borderColor: String
    let errorColor: String

    enum CodingKeys: String, CodingKey {
        case backgroundColor = "background_color"
        case textColor = "text_color"
        case borderColor = "border_color"
        case errorColor = "error_color"
    }

    // Fallback theme used if the JSON has no theme block at all,
    // or if a specific color string fails to parse.
    static let fallback = Theme(
        backgroundColor: "#FFFFFF",
        textColor: "#111827",
        borderColor: "#D1D5DB",
        errorColor: "#B91C1C"
    )

    // Computed SwiftUI Colors. We resolve lazily so a single bad hex
    // doesn't break the whole theme — that field just falls back.
    var background: Color { Color(hex: backgroundColor) ?? Color(hex: Theme.fallback.backgroundColor)! }
    var text: Color { Color(hex: textColor) ?? Color(hex: Theme.fallback.textColor)! }
    var border: Color { Color(hex: borderColor) ?? Color(hex: Theme.fallback.borderColor)! }
    var error: Color { Color(hex: errorColor) ?? Color(hex: Theme.fallback.errorColor)! }
}

// MARK: - Hex → Color

extension Color {
    /// Parses #RRGGBB or #RRGGBBAA (case-insensitive, # optional).
    /// Returns nil for malformed input so callers can fall back.
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else {
            return nil
        }

        let r, g, b, a: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
