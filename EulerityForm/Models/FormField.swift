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

        // Each subtype decodes from the same JSON object the parent is
        // looking at (each has its own init(from:) reading only its keys).
        //
        // If a known-type field is malformed (e.g. missing required `id`),
        // the typed decode throws. We catch that and fall back to .unknown
        // rather than letting the error propagate. This keeps FormField
        // decoding total (never throws as long as `type` is a string), so
        // an array of fields decodes cleanly and FormSchema simply filters
        // out the .unknown entries. No fragile container-skipping needed.
        switch typeString {
        case "TEXT":
            if let c = try? TextFieldConfig(from: decoder) { self = .text(c) }
            else { self = .unknown(rawType: typeString) }
        case "DROPDOWN":
            if let c = try? DropdownFieldConfig(from: decoder) { self = .dropdown(c) }
            else { self = .unknown(rawType: typeString) }
        case "TOGGLE":
            if let c = try? ToggleFieldConfig(from: decoder) { self = .toggle(c) }
            else { self = .unknown(rawType: typeString) }
        case "CHECKBOX":
            if let c = try? CheckboxFieldConfig(from: decoder) { self = .checkbox(c) }
            else { self = .unknown(rawType: typeString) }
        default:
            // Unrecognized type — also becomes .unknown, filtered by schema.
            self = .unknown(rawType: typeString)
        }
    }
}
