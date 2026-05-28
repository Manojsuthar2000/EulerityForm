//
//  DecodingTests.swift
//  EulerityFormTests
//
//  Unit tests for the polymorphic JSON decoder, per the take-home's
//  optional enhancement: "verify that your JSON decoder correctly maps
//  the different types and handles malformed data without crashing."
//
//  Two groups:
//    1. Type mapping — each `type` string decodes to the correct enum case
//       with the right associated config values.
//    2. Resilience — malformed / unexpected JSON does not crash and is
//       handled gracefully (unknown types filtered, bad fields dropped,
//       missing fields defaulted).
//

import XCTest
@testable import EulerityForm

final class DecodingTests: XCTestCase {

    // MARK: - Helpers

    /// Decodes a single FormField from a JSON object string.
    private func decodeField(_ json: String) throws -> FormField {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(FormField.self, from: data)
    }

    /// Decodes a full schema from a JSON string.
    private func decodeSchema(_ json: String) throws -> FormSchema {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(FormSchema.self, from: data)
    }

    // MARK: - 1. Type mapping

    func testTextFieldDecodesToTextCase() throws {
        let json = """
        {
          "id": "name", "order": 1, "type": "TEXT", "subtype": "PLAIN",
          "label": "Name", "max_length": 30, "required": true
        }
        """
        let field = try decodeField(json)
        guard case .text(let config) = field else {
            return XCTFail("Expected .text, got \(field)")
        }
        XCTAssertEqual(config.id, "name")
        XCTAssertEqual(config.order, 1)
        XCTAssertEqual(config.subtype, .plain)
        XCTAssertEqual(config.maxLength, 30)
        XCTAssertTrue(config.required)
    }

    func testAllTextSubtypesMapCorrectly() throws {
        let subtypes: [(String, TextSubtype)] = [
            ("PLAIN", .plain),
            ("MULTILINE", .multiline),
            ("NUMBER", .number),
            ("URI", .uri),
            ("SECURE", .secure)
        ]
        for (raw, expected) in subtypes {
            let json = """
            { "id": "f", "order": 1, "type": "TEXT", "subtype": "\(raw)", "label": "L" }
            """
            let field = try decodeField(json)
            guard case .text(let config) = field else {
                return XCTFail("Expected .text for subtype \(raw)")
            }
            XCTAssertEqual(config.subtype, expected, "Subtype \(raw) mapped wrong")
        }
    }

    func testDropdownDecodesWithOptions() throws {
        let json = """
        {
          "id": "net", "order": 2, "type": "DROPDOWN", "label": "Networks",
          "allow_multiple": true, "default_values": ["a"],
          "options": [
            { "id": "a", "label": "Alpha" },
            { "id": "b", "label": "Beta" }
          ]
        }
        """
        let field = try decodeField(json)
        guard case .dropdown(let config) = field else {
            return XCTFail("Expected .dropdown, got \(field)")
        }
        XCTAssertTrue(config.allowMultiple)
        XCTAssertEqual(config.options.count, 2)
        XCTAssertEqual(config.options.first?.id, "a")
        XCTAssertEqual(config.options.first?.label, "Alpha")
        XCTAssertEqual(config.defaultValues, ["a"])
    }

    func testToggleDecodesWithDefault() throws {
        let json = """
        { "id": "t", "order": 3, "type": "TOGGLE", "label": "On?", "default_value": true }
        """
        let field = try decodeField(json)
        guard case .toggle(let config) = field else {
            return XCTFail("Expected .toggle, got \(field)")
        }
        XCTAssertTrue(config.defaultValue)
    }

    func testCheckboxDecodesWithMetadataLinks() throws {
        let json = """
        {
          "id": "legal", "order": 4, "type": "CHECKBOX",
          "label": "Agree to Terms of Service.", "required": true,
          "metadata": { "Terms of Service": "https://example.com/terms" },
          "clickable_text_color": "#2563EB"
        }
        """
        let field = try decodeField(json)
        guard case .checkbox(let config) = field else {
            return XCTFail("Expected .checkbox, got \(field)")
        }
        XCTAssertEqual(config.metadata?["Terms of Service"], "https://example.com/terms")
        XCTAssertEqual(config.clickableTextColor, "#2563EB")
    }

    // MARK: - 2. Resilience / malformed data

    func testUnknownTypeDecodesToUnknownCase() throws {
        let json = """
        { "id": "c", "order": 1, "type": "COLOR_PICKER", "label": "Color" }
        """
        let field = try decodeField(json)
        guard case .unknown(let rawType) = field else {
            return XCTFail("Expected .unknown, got \(field)")
        }
        XCTAssertEqual(rawType, "COLOR_PICKER")
    }

    func testUnknownTypeIsFilteredFromSchema() throws {
        // The schema should drop unknown-typed fields entirely.
        let json = """
        {
          "theme": { "background_color": "#FFF", "text_color": "#000",
                     "border_color": "#CCC", "error_color": "#F00" },
          "form_title": "Test",
          "fields": [
            { "id": "ok", "order": 1, "type": "TEXT", "label": "OK" },
            { "id": "bad", "order": 2, "type": "DATE_PICKER", "label": "Bad" }
          ]
        }
        """
        let schema = try decodeSchema(json)
        XCTAssertEqual(schema.fields.count, 1, "Unknown type should be filtered out")
        XCTAssertEqual(schema.fields.first?.id, "ok")
    }

    func testMissingSubtypeFallsBackToPlain() throws {
        // A TEXT field with no subtype should default to PLAIN, not crash.
        let json = """
        { "id": "f", "order": 1, "type": "TEXT", "label": "No subtype" }
        """
        let field = try decodeField(json)
        guard case .text(let config) = field else {
            return XCTFail("Expected .text, got \(field)")
        }
        XCTAssertEqual(config.subtype, .plain)
    }

    func testUnknownSubtypeFallsBackToPlain() throws {
        // An unrecognized subtype should fall back to PLAIN rather than fail.
        let json = """
        { "id": "f", "order": 1, "type": "TEXT", "subtype": "RICH_HTML", "label": "L" }
        """
        let field = try decodeField(json)
        guard case .text(let config) = field else {
            return XCTFail("Expected .text, got \(field)")
        }
        XCTAssertEqual(config.subtype, .plain)
    }

    func testMissingOptionalArraysDefaultToEmpty() throws {
        // Dropdown with no options / no defaults / no allow_multiple should
        // decode with sensible empty defaults, not crash.
        let json = """
        { "id": "d", "order": 1, "type": "DROPDOWN", "label": "Empty", "required": true }
        """
        let field = try decodeField(json)
        guard case .dropdown(let config) = field else {
            return XCTFail("Expected .dropdown, got \(field)")
        }
        XCTAssertTrue(config.options.isEmpty)
        XCTAssertTrue(config.defaultValues.isEmpty)
        XCTAssertFalse(config.allowMultiple)
    }

    func testMissingRequiredFlagDefaultsToFalse() throws {
        let json = """
        { "id": "f", "order": 1, "type": "TEXT", "label": "L" }
        """
        let field = try decodeField(json)
        guard case .text(let config) = field else {
            return XCTFail("Expected .text")
        }
        XCTAssertFalse(config.required)
    }

    func testFieldsAreSortedByOrderNotArrayIndex() throws {
        // Fields given out of order must come back sorted by `order`.
        let json = """
        {
          "theme": { "background_color": "#FFF", "text_color": "#000",
                     "border_color": "#CCC", "error_color": "#F00" },
          "form_title": "Test",
          "fields": [
            { "id": "third",  "order": 3, "type": "TEXT", "label": "C" },
            { "id": "first",  "order": 1, "type": "TEXT", "label": "A" },
            { "id": "second", "order": 2, "type": "TEXT", "label": "B" }
          ]
        }
        """
        let schema = try decodeSchema(json)
        XCTAssertEqual(schema.fields.map(\.id), ["first", "second", "third"])
    }

    func testMalformedFieldIsDroppedSchemaStillDecodes() throws {
        // A field missing its required `id` should be dropped, but the rest
        // of the schema should still decode without throwing.
        let json = """
        {
          "theme": { "background_color": "#FFF", "text_color": "#000",
                     "border_color": "#CCC", "error_color": "#F00" },
          "form_title": "Test",
          "fields": [
            { "id": "good", "order": 1, "type": "TEXT", "label": "Good" },
            { "order": 2, "type": "TEXT", "label": "Missing id" }
          ]
        }
        """
        let schema = try decodeSchema(json)
        XCTAssertEqual(schema.fields.count, 1)
        XCTAssertEqual(schema.fields.first?.id, "good")
    }

    func testMissingThemeFallsBackToDefault() throws {
        // No theme block at all — should use the fallback theme, not crash.
        let json = """
        { "form_title": "No theme", "fields": [] }
        """
        let schema = try decodeSchema(json)
        XCTAssertEqual(schema.formTitle, "No theme")
        // Fallback theme background is white per Theme.fallback.
        XCTAssertEqual(schema.theme.backgroundColor, Theme.fallback.backgroundColor)
    }

    func testEmptyFieldsArrayDecodes() throws {
        let json = """
        {
          "theme": { "background_color": "#FFF", "text_color": "#000",
                     "border_color": "#CCC", "error_color": "#F00" },
          "form_title": "Empty", "fields": []
        }
        """
        let schema = try decodeSchema(json)
        XCTAssertTrue(schema.fields.isEmpty)
    }
}
