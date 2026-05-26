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

        // Decode each field independently. If a single field fails to decode
        // (corrupt JSON, unexpected shape), we drop it and keep going rather
        // than failing the whole form.
        var fieldsContainer = try c.nestedUnkeyedContainer(forKey: .fields)
        var decoded: [FormField] = []
        while !fieldsContainer.isAtEnd {
            if let field = try? fieldsContainer.decode(FormField.self) {
                // Filter unknowns at the schema level so the UI never sees them
                if case .unknown = field {
                    // Skip silently. We could log here if we wanted observability.
                    continue
                }
                decoded.append(field)
            } else {
                // Skip past the bad element so we don't infinite-loop
                _ = try? fieldsContainer.decode(AnyDecodable.self)
            }
        }

        // Sort by `order` — never rely on JSON array index.
        fields = decoded.sorted { $0.order < $1.order }
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

/// Sink type for skipping past unparseable JSON values without infinite-looping.
private struct AnyDecodable: Decodable {}

// MARK: - Fallback

extension FormSchema {
    /// Used by the view model when JSON loading fails catastrophically.
    static func empty(title: String) -> FormSchema {
        FormSchema(theme: .fallback, formTitle: title, fields: [])
    }
}
