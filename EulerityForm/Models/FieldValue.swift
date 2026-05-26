//
//  FieldValue.swift
//  EulerityForm
//
//  Heterogeneous value type stored in the view model.
//  One dict [String: FieldValue] holds the entire form's state.
//

import Foundation

enum FieldValue: Equatable {
    case text(String)
    case bool(Bool)
    case singleSelect(String?)
    case multiSelect([String])

    // MARK: - Convenience accessors
    // These unwrap the case or return a sensible default. Used by view
    // bindings so they don't have to switch every time.

    var asText: String {
        if case .text(let s) = self { return s }
        return ""
    }

    var asBool: Bool {
        if case .bool(let b) = self { return b }
        return false
    }

    var asSingleSelect: String? {
        if case .singleSelect(let s) = self { return s }
        return nil
    }

    var asMultiSelect: [String] {
        if case .multiSelect(let arr) = self { return arr }
        return []
    }

    /// Used by validation: is this field "empty" in the user's sense?
    /// Different cases have different notions of empty.
    var isEmpty: Bool {
        switch self {
        case .text(let s): return s.trimmingCharacters(in: .whitespaces).isEmpty
        case .bool(let b): return !b           // unchecked counts as "empty" for required checkboxes
        case .singleSelect(let s): return s == nil
        case .multiSelect(let arr): return arr.isEmpty
        }
    }

    /// JSON-friendly value for the final Save output.
    var jsonRepresentation: Any {
        switch self {
        case .text(let s): return s
        case .bool(let b): return b
        case .singleSelect(let s): return s ?? NSNull()
        case .multiSelect(let arr): return arr
        }
    }
}
