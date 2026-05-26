//
//  FormField.swift
//  EulerityForm
//
//  The polymorphic field type. Decodes based on the `type` discriminator,
//  dispatches to the appropriate subtype struct.
//
//  Unknown types decode to `.unknown` (with the raw type string preserved
//  for debugging) so the schema decoder can filter them out without crashing.
//

import Foundation

enum FormField: Equatable {
    case text(TextFieldConfig)
    case dropdown(DropdownFieldConfig)
    case toggle(ToggleFieldConfig)
    case checkbox(CheckboxFieldConfig)
    case unknown(rawType: String)

    /// Common accessor for sorting. The unknown case sorts to a stable
    /// position (.max) but it shouldn't ever reach view rendering anyway —
    /// FormSchema filters it out.
    var order: Int {
        switch self {
        case .text(let c): return c.order
        case .dropdown(let c): return c.order
        case .toggle(let c): return c.order
        case .checkbox(let c): return c.order
        case .unknown: return .max
        }
    }

    /// Stable id used as dictionary key in the view model state.
    var id: String {
        switch self {
        case .text(let c): return c.id
        case .dropdown(let c): return c.id
        case .toggle(let c): return c.id
        case .checkbox(let c): return c.id
        case .unknown(let raw): return "unknown_\(raw)"
        }
    }
}

// MARK: - Decoding

extension FormField: Decodable {
    /// We only need to peek at "type" to choose a branch.
    /// Each subtype struct knows how to decode the rest of its fields.
    private enum TypeKey: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let typeString = try typeContainer.decode(String.self, forKey: .type)

        // The single-value-container trick: each subtype decodes from
        // the same JSON object the parent is looking at. This avoids
        // duplicating decode logic here.
        switch typeString {
        case "TEXT":
            self = .text(try TextFieldConfig(from: decoder))
        case "DROPDOWN":
            self = .dropdown(try DropdownFieldConfig(from: decoder))
        case "TOGGLE":
            self = .toggle(try ToggleFieldConfig(from: decoder))
        case "CHECKBOX":
            self = .checkbox(try CheckboxFieldConfig(from: decoder))
        default:
            // Defensive: anything we don't recognize becomes .unknown.
            // The schema decoder filters these out before they reach the UI.
            self = .unknown(rawType: typeString)
        }
    }
}
