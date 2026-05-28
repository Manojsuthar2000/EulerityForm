# EulerityForm — Dynamic Form Builder

A single-screen iOS app that renders a fully dynamic form from a local JSON
payload. Built for the Eulerity iOS take-home exercise.

- **Swift + SwiftUI**, iOS 16.0 minimum (tested on iOS 26).
- Fully offline — three JSON payloads bundled, no network calls.
- MVVM with a single observable view model.
- 15 XCTest cases covering the polymorphic decoder and malformed-data resilience.

To run: open `EulerityForm.xcodeproj`, build the `EulerityForm` scheme, ⌘R.
The showcase payload (`form_schema_showcase.json`) loads by default. Swap
the filename in `EulerityFormApp.swift` to see the baseline or edge-case
payloads. To run the tests, ⌘U.

---

## Approach and architecture

### The polymorphic decoder

The single most important design decision was how to model a field whose
shape depends on its `type`. I went with an **enum with associated values**
plus a custom decoder that peeks at `type` and dispatches to a concrete
config struct:

```swift
enum FormField {
    case text(TextFieldConfig)
    case dropdown(DropdownFieldConfig)
    case toggle(ToggleFieldConfig)
    case checkbox(CheckboxFieldConfig)
    case unknown(rawType: String)
}

extension FormField: Decodable {
    init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeKey.self)
        let typeString = try typeContainer.decode(String.self, forKey: .type)

        switch typeString {
        case "TEXT":
            if let c = try? TextFieldConfig(from: decoder) { self = .text(c) }
            else { self = .unknown(rawType: typeString) }
        // ... DROPDOWN, TOGGLE, CHECKBOX
        default:
            self = .unknown(rawType: typeString)
        }
    }
}
```

Two properties of this design matter:

1. **The same `Decoder` is passed to each sub-config.** Each
   `TextFieldConfig`, `DropdownFieldConfig`, etc. has its own
   `init(from:)` that reads only its keys from the same JSON object. No
   re-decoding from raw data.

2. **Decoding is total.** A malformed known-type field (e.g. `TEXT` missing
   its `id`) falls back to `.unknown` instead of throwing. So decoding the
   whole `[FormField]` array in one shot never throws, and `FormSchema`
   filters `.unknown` entries before they reach the UI. A single corrupt
   field can't break the whole form.

This is also how `COLOR_PICKER` (the unsupported type in the edge-case
payload) is handled — it decodes to `.unknown` and gets filtered.

### State model

Field values are heterogeneous (text, bool, single-select, multi-select),
so the view model holds a single `[String: FieldValue]` dictionary where
`FieldValue` is an enum with the appropriate cases. The view model exposes
typed bindings (`textBinding(for:)`, `boolBinding(for:)`, etc.) so the
field views never need to switch on the enum — they get back a
`Binding<String>` or `Binding<Bool>` and use it normally.

### Validation

Errors only appear after the first Save attempt. After that first attempt
fails, errors update live as the user types — so an error message
disappears the moment the user fixes the field. This is the standard
"don't yell at the user before they've tried" pattern.

The Save button stays tappable even when validation would fail — tapping
it surfaces the errors next to the offending fields. A disabled button
would leave the user wondering *why* they can't save.

### File structure

```
EulerityForm/
├── Models/
│   ├── Theme.swift             # Hex parsing + fallback theme
│   ├── FieldSubtypes.swift     # TextFieldConfig, DropdownFieldConfig, etc.
│   ├── FormField.swift         # The polymorphic enum + total decoder
│   ├── FormSchema.swift        # Top-level: theme + title + sorted fields
│   └── FieldValue.swift        # State enum (text / bool / single / multi)
├── ViewModel/
│   ├── FormViewModel.swift     # State, bindings, validation
│   └── KeyboardObserver.swift  # UIResponder keyboard tracking
├── Views/
│   ├── DynamicFormView.swift   # Root: title + scrolling fields + Save
│   ├── Fields/                 # One view per field type
│   └── Components/             # DropdownPanel, SelectedChipsView, RequiredLabel
├── Resources/                  # Three JSON payloads
EulerityFormTests/
└── DecodingTests.swift         # 15 tests, type mapping + resilience
```

---

## Product decisions

The take-home includes a stress-test payload with deliberate edge cases.
Three of those required product calls the spec didn't explicitly answer.

### 1. `max_length` enforcement: don't block input, block Save

**The spec says:** "prevent typing past the limit and display a character
counter." A literal reading means truncating or rejecting input past the
limit.

**What I built:** Users can type past the limit. The character counter
goes red ("47/20"). Save is blocked until they fix it.

**Why I diverged from the literal spec:**

- **Silent truncation throws away content without asking.** If someone
  pastes a 100-character string into a 20-character field, they should see
  what they pasted and decide what to cut — not have iOS silently chop
  the last 80 characters.
- **A counter that can't exceed the max is decoration, not information.**
  Red "47/20" tells the user *exactly* how much to remove.
- **It handles the `default_value` violation naturally.** The edge-case
  payload has a 47-character `default_value` against a 20-character
  `max_length`. With my approach, that just renders as "47/20" in red on
  launch — no special-case code needed, no silent default-truncation
  hiding the conflict from whoever wrote the JSON.

This is the central product decision in the project, and the one I'd
defend most strongly. Both approaches are reasonable, but I think mine
serves the user better.

### 2. Empty options array on a required dropdown

The edge-case payload has `"billing_account"` as a required `DROPDOWN`
with `"options": []`. The user can never satisfy this — what should the
UI do?

**What I built:** The closed-state header shows a non-interactive
placeholder ("No options available" in muted italic). The dropdown can't
open. On Save, validation fails with the field's error message (or a
generated "No options available for…" fallback if none was provided).

**Why:** Silently hiding the field would confuse whoever wrote the JSON
(they're staring at a working app and not seeing their field). Showing a
working-looking empty picker would be misleading. Showing it disabled
with a clear placeholder and failing validation gives both the user and
the JSON author useful feedback.

### 3. `default_value` violates `max_length`

The edge-case payload's `campaign_name` ships with a 47-character default
against a 20-character limit. Options: truncate silently, truncate and
flag, accept as-is and flag, reject the field entirely.

**What I built:** Accept the default as-is. The counter renders red
("47/20") on launch. Validation fails on Save until the user shortens it.

**Why:** This falls out naturally from product decision #1 — defaults
load through the same path as user input, and the same "type freely,
counter goes red, Save blocked" pattern applies. The conflict is visible
from the first frame. Silent truncation would hide the bug from whoever
configured the JSON; a hard error on load would prevent the whole form
from rendering and seems heavy-handed for what might be a typo.

---

## What I'd improve with more time

**A proper SwiftUI `Layout` for the chip overflow.** The current
`SelectedChipsView` uses a `GeometryReader` to read the available width,
then packs chips into rows in plain Swift. This works but has a one-frame
layout shift on first appearance because the geometry isn't known until
after the first render. A custom `Layout`-conforming type would be
single-pass and pixel-perfect. I started one and got tangled in passing
overflow counts back from the layout, backed out to the simpler approach.

**Next button in the keyboard toolbar.** The spec's optional enhancement
described a Next + Done toolbar that cycles focus through text fields. I
shipped Done-only because it's simpler, but the Next-cycling version
would require tracking field order in the view model and exposing a
"next field id after this one" helper. Maybe 30 minutes of work.

**Cleaner keyboard handling without `NotificationCenter`.** I fell back
to `UIResponder.keyboardWillShowNotification` because SwiftUI's
`.ignoresSafeArea(.keyboard)` + `.safeAreaInset` combinations didn't
reliably produce the layout I wanted on iOS 26. As iOS 26's keyboard
avoidance APIs stabilize, this could move back to pure SwiftUI.

**Off-main-thread decoding.** The project's `-default-isolation
MainActor` setting puts model decoding on the main actor. For tiny
payloads like this, that's fine. For a production app with larger schemas
I'd mark the model `Decodable` conformances `nonisolated` so parsing
could happen off the main thread.

**Accessibility audit.** I haven't run the form through VoiceOver or
Dynamic Type at the largest sizes. Each field type would need attention
— particularly the custom checkbox, dropdown chips, and the keyboard
accessory bar.

**Persisting input across app launches.** The form resets on every cold
start. Real campaign-creation flows would persist drafts.

---

## What I got stuck on and how I worked through it

### The keyboard layout, three failed attempts

The hardest piece by far was the layout once I added a fixed Save button
at the bottom. The requirement was straightforward in concept: title at
top (fixed), fields scrolling in the middle, Save at the bottom (fixed),
and a Done button above the keyboard when any text field is focused. The
catch was that Save kept getting lifted by SwiftUI's automatic keyboard
avoidance, ending up on top of the Done button.

I tried three SwiftUI-native combinations:

1. **`.ignoresSafeArea(.keyboard, edges: .bottom)` on the outer VStack.**
   Save still lifted with the keyboard.
2. **Reordering the modifier to apply *after* `.safeAreaInset`.** I
   caught this myself — it would have hidden the Done bar under the
   keyboard. Bad fix.
3. **ZStack layering: form (Layer 1), Save with
   `.ignoresSafeArea(.keyboard)` (Layer 2), Done bar via
   `.safeAreaInset(.bottom)` (Layer 3).** Save *still* ended up over the
   Done bar, because `safeAreaInset` adds a safe area that Layer 2's
   `.ignoresSafeArea(.keyboard)` doesn't override.

After the third failed attempt I stepped away from SwiftUI's keyboard
avoidance entirely and observed the keyboard directly via UIKit's
`NotificationCenter`. The `KeyboardObserver` is a small `ObservableObject`
that publishes the current keyboard height; the view shows Save when
height is zero and the Done bar when it isn't. They share a single slot
at the bottom of the VStack and are never both visible.

This works perfectly. It's the standard pattern from pre-SwiftUI iOS
development, and the lesson worth carrying forward is that when an
abstraction isn't holding, the underlying foundation usually is.

### The decoder bug that unit tests caught

While writing tests for "what happens with a malformed field?" I caught a
latent infinite-loop risk in the original `FormSchema` decoder. The
original used an empty `private struct AnyDecodable: Decodable {}` to
skip past unparseable fields in the array. An empty `Decodable` struct's
synthesized initializer doesn't actually consume the container element,
so a bad field could leave the unkeyed container cursor stuck — risking
infinite iteration or incorrect counts.

The fix was structural rather than surgical: I made `FormField` decoding
*total*. Instead of letting a malformed typed sub-decode throw, the
sub-decode result is wrapped in `try?` and falls back to `.unknown`. So
decoding `[FormField]` never throws, the whole array decodes in one
shot, and `FormSchema` filters `.unknown` entries. No container-skipping
logic at all.

This is the kind of bug a happy-path demo would never have found. Writing
the malformed-field test is what surfaced it.

---

## Running the tests

The tests are in a separate `EulerityFormTests` target (Unit Testing
Bundle). They use `XCTest` and `@testable import EulerityForm`. Run with
⌘U or via `xcodebuild test -scheme EulerityForm`. The 15 cases split into
two groups:

- **Type mapping** — each `type` decodes to the right enum case, all 5
  text subtypes, dropdown options/defaults/multi flag, toggle defaults,
  checkbox metadata links.
- **Resilience** — unknown types filtered, missing/unknown subtype falls
  back to PLAIN, missing optional arrays default to empty, missing
  `required` defaults to false, malformed fields dropped, missing theme
  falls back, out-of-order fields sort by `order`, empty fields array
  decodes cleanly.

---

## On AI tool usage

I built this with Claude (Anthropic's web app, Incognito mode) as a
pair-programming partner. `AI_COLLABORATION_LOG.md` records the full
process across nine sessions — including where I pushed back, where I
overrode AI recommendations on product grounds, and where Claude got
something wrong and how we worked through it. The keyboard saga and the
decoder bug are the two most useful case studies.

I'm prepared to walk through any part of the code in the follow-up
interview. Everything I submitted, I wrote with intent and can defend.
