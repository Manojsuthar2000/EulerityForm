//
//  FormSchema.swift
//  EulerityForm
//
//  Top-level wrapper for the entire form JSON. Theme + title + fields.
//

import Foundation

struct FormSchema: Decodable {
    let theme: Theme
    let formTitle: String
    let fields: [FormField]

    enum CodingKeys: String, CodingKey {
        case theme
        case formTitle = "form_title"
        case fields
    }

    /// Internal memberwise init for tests and fallback states.
    /// Production code should always go through `load(from:)` or JSONDecoder.
    init(theme: Theme, formTitle: String, fields: [FormField]) {
        self.theme = theme
        self.formTitle = formTitle
        self.fields = fields.sorted { $0.order < $1.order }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theme = (try? c.decode(Theme.self, forKey: .theme)) ?? Theme.fallback
        formTitle = (try? c.decode(String.self, forKey: .formTitle)) ?? "Form"

        // FormField decoding is total: it never throws as long as each
        // element has a string `type`. Malformed known-type fields and
        // unrecognized types both become .unknown. So we decode the whole
        // array in one shot, then filter out .unknown before it reaches the
        // UI. A single bad field is dropped; the rest of the form survives.
        let allFields = (try? c.decode([FormField].self, forKey: .fields)) ?? []
        let usableFields = allFields.filter { field in
            if case .unknown = field { return false }
            return true
        }

        // Sort by `order` — never rely on JSON array index.
        fields = usableFields.sorted { $0.order < $1.order }
    }

    /// Convenience for loading from the app bundle.
    static func load(from filename: String, bundle: Bundle = .main) throws -> FormSchema {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw FormSchemaError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FormSchema.self, from: data)
    }
}

enum FormSchemaError: Error, LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Could not find \(name).json in app bundle."
        }
    }
}

// MARK: - Fallback

extension FormSchema {
    /// Used by the view model when JSON loading fails catastrophically.
    static func empty(title: String) -> FormSchema {
        FormSchema(theme: .fallback, formTitle: title, fields: [])
    }
}
