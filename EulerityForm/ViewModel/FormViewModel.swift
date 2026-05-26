//
//  FormViewModel.swift
//  EulerityForm
//
//  Owns the form schema, the live field values, and the validation state.
//  Exposes typed Bindings so SwiftUI views never have to switch on FieldValue.
//
//  Validation model:
//    - Initial state: errors are empty, Save has never been tapped.
//    - First Save tap: validate everything, populate `errors`, mark
//      hasAttemptedSave = true. If valid, emit the final payload.
//    - After first Save tap: every value change re-runs validation live,
//      so errors disappear as the user fixes them.
//
//  This mirrors the standard "don't yell at the user before they've tried"
//  pattern. Max-length counter is the only thing that updates live before
//  Save — it's informational, not a blocking error.
//

import Foundation
import SwiftUI
import Combine

final class FormViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var schema: FormSchema
    @Published private(set) var values: [String: FieldValue] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var hasAttemptedSave: Bool = false

    /// Set when a Save succeeds. The view shows an alert with this payload.
    @Published var savedPayload: String? = nil

    // MARK: - Init

    init(schema: FormSchema) {
        self.schema = schema
        self.values = Self.initialValues(for: schema.fields)
    }

    /// Convenience: load from bundle file.
    convenience init(bundleFile: String) {
        do {
            let schema = try FormSchema.load(from: bundleFile)
            self.init(schema: schema)
        } catch {
            // Catastrophic: file missing or unparseable.
            // We surface an empty schema with a clear title rather than crashing.
            let empty = FormSchema.empty(title: "Failed to load form")
            self.init(schema: empty)
            print("[FormViewModel] Failed to load \(bundleFile): \(error)")
        }
    }

    /// Builds the initial values dict from each field's default.
    /// Defaults bypass any input restrictions (e.g. max_length) — they
    /// load as-is so violations are visible. See README for rationale.
    private static func initialValues(for fields: [FormField]) -> [String: FieldValue] {
        var dict: [String: FieldValue] = [:]
        for field in fields {
            switch field {
            case .text(let c):
                dict[c.id] = .text(c.defaultValue ?? "")
            case .dropdown(let c):
                if c.allowMultiple {
                    dict[c.id] = .multiSelect(c.defaultValues)
                } else {
                    dict[c.id] = .singleSelect(c.defaultValues.first)
                }
            case .toggle(let c):
                dict[c.id] = .bool(c.defaultValue)
            case .checkbox(let c):
                dict[c.id] = .bool(c.defaultValue)
            case .unknown:
                continue
            }
        }
        return dict
    }

    // MARK: - Bindings (Pattern A)
    //
    // Each helper exposes a Binding the view uses directly. The setter
    // updates `values` and, if we've already failed a Save once, re-runs
    // live validation on that field.

    func textBinding(for id: String) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.values[id]?.asText ?? "" },
            set: { [weak self] newValue in
                guard let self else { return }
                self.values[id] = .text(newValue)
                self.revalidateIfNeeded(fieldId: id)
            }
        )
    }

    func boolBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.values[id]?.asBool ?? false },
            set: { [weak self] newValue in
                guard let self else { return }
                self.values[id] = .bool(newValue)
                self.revalidateIfNeeded(fieldId: id)
            }
        )
    }

    func singleSelectBinding(for id: String) -> Binding<String?> {
        Binding(
            get: { [weak self] in self?.values[id]?.asSingleSelect },
            set: { [weak self] newValue in
                guard let self else { return }
                self.values[id] = .singleSelect(newValue)
                self.revalidateIfNeeded(fieldId: id)
            }
        )
    }

    func multiSelectBinding(for id: String) -> Binding<[String]> {
        Binding(
            get: { [weak self] in self?.values[id]?.asMultiSelect ?? [] },
            set: { [weak self] newValue in
                guard let self else { return }
                self.values[id] = .multiSelect(newValue)
                self.revalidateIfNeeded(fieldId: id)
            }
        )
    }

    /// Toggles an item in a multi-select array. View calls this from the
    /// checkbox-in-menu UI instead of building the array itself.
    func toggleMultiSelect(fieldId: String, optionId: String) {
        var current = values[fieldId]?.asMultiSelect ?? []
        if let idx = current.firstIndex(of: optionId) {
            current.remove(at: idx)
        } else {
            current.append(optionId)
        }
        values[fieldId] = .multiSelect(current)
        revalidateIfNeeded(fieldId: fieldId)
    }

    // MARK: - Validation

    /// Called by setters. Before the first Save attempt, this is a no-op
    /// (we don't show errors until the user has tried). After the first
    /// failed Save, every change re-validates that one field so the error
    /// clears as the user fixes it.
    private func revalidateIfNeeded(fieldId: String) {
        guard hasAttemptedSave else { return }
        let error = validate(fieldId: fieldId)
        if let error {
            errors[fieldId] = error
        } else {
            errors.removeValue(forKey: fieldId)
        }
    }

    /// Validates a single field. Returns the error message to show, or nil if valid.
    private func validate(fieldId: String) -> String? {
        guard let field = schema.fields.first(where: { $0.id == fieldId }) else { return nil }
        let value = values[fieldId]

        switch field {
        case .text(let c):
            let text = value?.asText ?? ""

            // Required
            if c.required && text.trimmingCharacters(in: .whitespaces).isEmpty {
                return c.errorMessage ?? "\(c.label) is required."
            }

            // Max length — content over the limit blocks Save.
            // (User can still type past it, the counter just goes red.)
            if let max = c.maxLength, text.count > max {
                return c.errorMessage ?? "\(c.label) must be \(max) characters or fewer."
            }

            // Regex (optional enhancement)
            if !text.isEmpty, let pattern = c.regex {
                if (try? NSRegularExpression(pattern: pattern))?
                    .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) == nil {
                    return c.errorMessage ?? "\(c.label) is not in the expected format."
                }
            }

            // Subtype-specific: NUMBER must parse as a number when non-empty
            if c.subtype == .number, !text.isEmpty, Double(text) == nil {
                return c.errorMessage ?? "\(c.label) must be a number."
            }

            return nil

        case .dropdown(let c):
            // Empty options array on a required dropdown — always invalid.
            // No way for the user to succeed; we show the error message.
            if c.required && c.options.isEmpty {
                return c.errorMessage ?? "No options available for \(c.label)."
            }
            if c.required {
                if c.allowMultiple {
                    if (value?.asMultiSelect ?? []).isEmpty {
                        return c.errorMessage ?? "Please select an option for \(c.label)."
                    }
                } else {
                    if value?.asSingleSelect == nil {
                        return c.errorMessage ?? "Please select an option for \(c.label)."
                    }
                }
            }
            return nil

        case .toggle(let c):
            // A "required" toggle that's off counts as missing.
            // (Most toggles aren't required; this just covers the case cleanly.)
            if c.required && !(value?.asBool ?? false) {
                return c.errorMessage ?? "\(c.label) is required."
            }
            return nil

        case .checkbox(let c):
            if c.required && !(value?.asBool ?? false) {
                return c.errorMessage ?? "\(c.label) is required."
            }
            return nil

        case .unknown:
            return nil
        }
    }

    /// Called when the user taps Save. Validates the whole form.
    /// If valid, builds the final payload and stores it in `savedPayload`
    /// (the view shows an alert with it).
    func attemptSave() {
        hasAttemptedSave = true
        var newErrors: [String: String] = [:]

        for field in schema.fields {
            if let err = validate(fieldId: field.id) {
                newErrors[field.id] = err
            }
        }

        errors = newErrors

        if newErrors.isEmpty {
            savedPayload = buildPayloadString()
            print("[FormViewModel] Save valid. Payload:")
            print(savedPayload ?? "")
        } else {
            print("[FormViewModel] Save blocked. Errors: \(newErrors)")
        }
    }

    /// Builds a pretty-printed JSON-ish string of the current values.
    /// Used for the success alert and console output.
    private func buildPayloadString() -> String {
        var dict: [String: Any] = [:]
        for (id, value) in values {
            dict[id] = value.jsonRepresentation
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return String(describing: dict)
        }
        return str
    }

    // MARK: - View helpers

    /// Returns the current error for a field, but only if we've attempted save.
    /// Views use this to decide whether to show a red border / error text.
    func error(for fieldId: String) -> String? {
        guard hasAttemptedSave else { return nil }
        return errors[fieldId]
    }

    /// Has the user typed past the max_length for this text field?
    /// Drives the red color on the counter — independent of save attempts.
    func isOverMaxLength(fieldId: String, maxLength: Int?) -> Bool {
        guard let max = maxLength else { return false }
        return (values[fieldId]?.asText.count ?? 0) > max
    }
}

// (Empty schema fallback now lives in FormSchema.swift)
