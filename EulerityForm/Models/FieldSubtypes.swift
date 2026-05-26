//
//  FieldSubtypes.swift
//  EulerityForm
//
//  Config structs that live inside FormField enum cases.
//  Each one decodes its own properties; FormField just dispatches on `type`.
//

import Foundation

// MARK: - Common protocol

/// All field configs share these properties. Useful for sorting & validation
/// at the call site without unwrapping the enum.
protocol FieldConfig {
    var id: String { get }
    var order: Int { get }
    var label: String { get }
    var required: Bool { get }
    var errorMessage: String? { get }
}

// MARK: - TEXT

struct TextFieldConfig: FieldConfig, Codable, Equatable {
    let id: String
    let order: Int
    let label: String
    let required: Bool
    let errorMessage: String?

    let subtype: TextSubtype
    let placeholder: String?
    let defaultValue: String?
    let maxLength: Int?
    let regex: String?

    enum CodingKeys: String, CodingKey {
        case id, order, label, required, subtype, placeholder, regex
        case errorMessage = "error_message"
        case defaultValue = "default_value"
        case maxLength = "max_length"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        label = try c.decode(String.self, forKey: .label)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? false
        errorMessage = try? c.decode(String.self, forKey: .errorMessage)

        // Defensive: if subtype is missing or unknown, fall back to PLAIN.
        // The spec calls this out as an edge case worth defending against.
        if let raw = try? c.decode(String.self, forKey: .subtype),
           let parsed = TextSubtype(rawValue: raw) {
            subtype = parsed
        } else {
            subtype = .plain
        }

        placeholder = try? c.decode(String.self, forKey: .placeholder)
        defaultValue = try? c.decode(String.self, forKey: .defaultValue)
        maxLength = try? c.decode(Int.self, forKey: .maxLength)
        regex = try? c.decode(String.self, forKey: .regex)
    }
}

enum TextSubtype: String, Codable {
    case plain = "PLAIN"
    case multiline = "MULTILINE"
    case number = "NUMBER"
    case uri = "URI"
    case secure = "SECURE"
}

// MARK: - DROPDOWN

struct DropdownOption: Codable, Equatable, Identifiable {
    let id: String
    let label: String
}

struct DropdownFieldConfig: FieldConfig, Codable, Equatable {
    let id: String
    let order: Int
    let label: String
    let required: Bool
    let errorMessage: String?

    let options: [DropdownOption]
    let allowMultiple: Bool
    let defaultValues: [String]

    enum CodingKeys: String, CodingKey {
        case id, order, label, required, options
        case errorMessage = "error_message"
        case allowMultiple = "allow_multiple"
        case defaultValues = "default_values"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        label = try c.decode(String.self, forKey: .label)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? false
        errorMessage = try? c.decode(String.self, forKey: .errorMessage)

        // Missing options array → empty. Empty options on a required
        // dropdown is a known edge case; we handle it in the view layer.
        options = (try? c.decode([DropdownOption].self, forKey: .options)) ?? []
        allowMultiple = (try? c.decode(Bool.self, forKey: .allowMultiple)) ?? false
        defaultValues = (try? c.decode([String].self, forKey: .defaultValues)) ?? []
    }
}

// MARK: - TOGGLE

struct ToggleFieldConfig: FieldConfig, Codable, Equatable {
    let id: String
    let order: Int
    let label: String
    let required: Bool
    let errorMessage: String?
    let defaultValue: Bool

    enum CodingKeys: String, CodingKey {
        case id, order, label, required
        case errorMessage = "error_message"
        case defaultValue = "default_value"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        label = try c.decode(String.self, forKey: .label)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? false
        errorMessage = try? c.decode(String.self, forKey: .errorMessage)
        defaultValue = (try? c.decode(Bool.self, forKey: .defaultValue)) ?? false
    }
}

// MARK: - CHECKBOX

struct CheckboxFieldConfig: FieldConfig, Codable, Equatable {
    let id: String
    let order: Int
    let label: String
    let required: Bool
    let errorMessage: String?

    /// Map of substring → URL. The substring is rendered as a clickable
    /// link inside the label. Optional — checkbox works fine without it.
    let metadata: [String: String]?

    /// Hex color override for the clickable substrings.
    /// Falls back to theme.text if absent.
    let clickableTextColor: String?

    let defaultValue: Bool

    enum CodingKeys: String, CodingKey {
        case id, order, label, required, metadata
        case errorMessage = "error_message"
        case clickableTextColor = "clickable_text_color"
        case defaultValue = "default_value"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        order = try c.decode(Int.self, forKey: .order)
        label = try c.decode(String.self, forKey: .label)
        required = (try? c.decode(Bool.self, forKey: .required)) ?? false
        errorMessage = try? c.decode(String.self, forKey: .errorMessage)
        metadata = try? c.decode([String: String].self, forKey: .metadata)
        clickableTextColor = try? c.decode(String.self, forKey: .clickableTextColor)
        defaultValue = (try? c.decode(Bool.self, forKey: .defaultValue)) ?? false
    }
}
