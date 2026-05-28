# AI Collaboration Log

This document records my AI-assisted workflow for the Eulerity iOS take-home.
Per Eulerity's submission requirements, it captures how I prompted, where I
accepted suggestions, where I pushed back, and what design decisions came out
of the back-and-forth.

**Tool used:** Claude (Anthropic), via the Claude web app in Incognito mode.

**Why Incognito:** I wanted a clean per-session context with no memory of prior
unrelated conversations leaking in. The trade-off is that the log below *is*
my continuity — if I open a new Incognito session later, I paste this back in
to resume.

---

## Session 1 — Architecture planning (no code yet)

### My opening prompt

I uploaded the take-home spec as a markdown file and wrote:

> let start with this project assessment

### Claude's response

Instead of dumping a plan, Claude asked three structured questions before
giving any architectural guidance:

- How much SwiftUI experience do I have?
- What do I want from this conversation right now?
- How much time do I have?

It also flagged early: *"The trickiest parts aren't the obvious ones
(rendering components is straightforward) — they're the polymorphic Codable
decoding and the product decisions in the all-in-one payload."*

**My take:** This was useful. It avoided the "here's 2000 lines, good luck"
failure mode that AI tools often default to. I answered: comfortable with
SwiftUI, want to plan architecture first, 2-3 days available.

### The three architectural calls

Claude laid out three decisions with trade-offs for each. I'll record them
along with how I responded.

#### Decision 1: How to model the polymorphic field type

Claude proposed three options:

- **(A)** A single struct with every property optional. Easy to decode, lose
  type safety at the render site.
- **(B)** An enum with associated values. Custom decoder peeks at `type`,
  dispatches to subtype struct. Type-safe, exhaustive switch at render time.
- **(C)** Protocol + type erasure. Flexible but awkward in SwiftUI.

**Claude's recommendation:** B. **My response:** Agreed, picked B.

Reasoning I committed to: an exhaustive switch in the view layer means adding
a new field type is a compile-time forcing function — the compiler tells me
every site I need to update. With Option A I'd have runtime branching and
silent omissions.

#### Decision 2: State storage shape

- **(A)** A `FieldValue` enum with cases (`.text(String)`, `.bool(Bool)`,
  `.singleSelect(String?)`, `.multiSelect([String])`). One `[String: FieldValue]`
  dictionary in the view model.
- **(B)** Separate typed dictionaries (`[String: String]`, `[String: Bool]`,
  etc.).

**Claude's recommendation:** A, with a caveat: "every field view needs a
custom binding that wraps/unwraps the enum case. Bit of boilerplate."

**My response:** Picked A. The boilerplate is a one-time cost — wrote it as
typed binding helpers on the view model (`textBinding(for:)`,
`boolBinding(for:)`, etc.) so views don't switch on the enum.

#### Decision 3: When to show validation errors

Claude's recommendation was "show errors after first Save attempt, then
live-update after that."

**My pushback:** *"No, do this error when tap on save, live validation is
only for max char count"*

We landed on a hybrid the next round: errors appear on Save tap, then update
live *after the first failed Save* so they disappear as the user fixes
fields. Counter for max_length is always visible (it's informational, not an
error gate).

This is the validation model that's in `FormViewModel.swift` now.

---

## Session 2 — The max_length decision (where I overrode the spec)

Claude wrote up a question about how to enforce max_length, with two options:
**reject the input past the limit**, or **truncate to the limit**. It
recommended truncation with the justification *"that's what iOS does in most
native fields, so it matches user expectation."*

### My pushback

> "I will allow user to type pass max limit but it will become red count, and
> don't allow to save"

### Why I pushed back

The spec literally says *"prevent typing past the limit and display a
character counter."* So Claude's truncation suggestion was actually closer
to the spec than my approach. But I disagreed for product reasons:

1. **Silent truncation throws away user content without asking.** If someone
   pastes a long string and we silently chop it, they don't see what was lost
   until they look up and realize their text is shorter than expected.
2. **A counter that can't exceed the max is just decoration.** Letting the
   number go red ("47/20") is genuinely informative — it tells the user
   exactly how much they need to remove.
3. **It's consistent with our validation philosophy.** We already decided
   validation runs on Save tap, not live. Truncating on input would
   contradict that.
4. **It handles `default_value` violations naturally.** The all-in-one
   payload has a 47-char `default_value` against a 20-char `max_length`.
   With my approach, that just renders as "47/20" in red on launch — no
   special-case code needed. With truncation, the default would silently get
   chopped on load, hiding the conflict.

### How Claude responded to the pushback

It conceded immediately, with reasoning:

> *"That's a better call than mine, actually. ... The original spec says
> 'prevent typing past the limit and display a character counter' — strictly
> read, that's 'block input.' But your interpretation serves the user better,
> and this is exactly the kind of product decision the README is asking
> about."*

This is the central product decision in the README writeup. I'm overriding a
literal spec requirement because it serves the user better, and I can defend
the trade-off.

---

## Session 3 — Save button disabled vs. tappable

Claude raised one follow-up question I hadn't considered:

> "Should the Save button be disabled when validation would fail, or should it
> stay tappable and show errors on tap?"

It argued for tappable: *"A disabled Save button leaves the user wondering
'why can't I save?' — they have to hunt for the problem."*

**My response:** Agreed. Save stays tappable; tapping it surfaces errors next
to the offending fields.

---

## Session 4 — Building the models

Claude wrote the model layer top-down: `Theme` → `FieldSubtypes` →
`FormField` (the polymorphic enum) → `FormSchema` (top-level decoder) →
`FieldValue`.

### What I scrutinized

I read each file before approving the next. A few things I want to note that
matter for the interview:

1. **The polymorphic decoder pattern.** Inside `FormField.init(from:)`, the
   decoder reads only the `type` key from the container, then passes the
   *same decoder* to the appropriate subtype struct. This works because each
   subtype has its own `init(from decoder:)` and reads only the keys it
   cares about. No re-decoding from raw JSON. This was the most elegant
   piece of the model layer and I'd want to be able to explain it.

2. **Defensive decoding.** Every property in the subtype configs is decoded
   with `try?` if it's optional in the JSON. Required properties (`id`,
   `order`, `label`) use `try` and will fail the field. The result: a single
   malformed field doesn't break the form — `FormSchema` decodes fields one
   at a time and drops failures.

3. **Unknown type handling.** The `FormField` enum has an `.unknown(rawType:)`
   case. `FormSchema` filters it out before it reaches the UI. This handles
   the `COLOR_PICKER` edge case in the all-in-one payload without crashing.

### What I had Claude verify before moving on

After the model layer was written, I asked Claude to verify both JSON
payloads parsed correctly. It ran a Python simulation (since the container
doesn't have Xcode) that mirrored the decoder's logic. The simulation
confirmed:

- All fields parse for both payloads
- Unknown `COLOR_PICKER` is filtered out (1 unknown filtered from edge-case payload)
- Sort by `order` works correctly across the gap (1, 2, 3, 4, 5, 6, *8*, 9, 10)
- The 47-char default vs 20 max_length is preserved, not truncated
- Empty options array is preserved, not crashing decoder

I asked because I wanted independent confirmation before building the views on top.

---

## Session 5 — The checkbox/links bug Claude caught in its own output

Claude wrote `CheckboxView.swift` with this on the label:

```swift
Text(attributedLabel)
    .contentShape(Rectangle())
    .onTapGesture {
        viewModel.boolBinding(for: config.id).wrappedValue.toggle()
    }
```

The idea: tap anywhere on the label to toggle the checkbox, but the links in
the metadata should still open in Safari.

**The bug:** This is wrong. SwiftUI's `.onTapGesture` on a `Text` with
embedded links eats the link taps. The user would tap "Terms of Service" and
the checkbox would toggle instead of opening the URL.

Claude caught this itself in the same response — re-read its own code and
wrote: *"there's a real conflict: Text with attributed links handles taps on
link ranges natively, but my .onTapGesture on the whole Text will eat all
taps including the ones on links."*

It fixed it by removing the outer `.onTapGesture` entirely — the box toggles
the state, and the links inside the label handle their own taps. Cleaner
separation, matches iOS dialog convention (think Settings → Privacy: you
tap a checkbox, you tap a link, they're different zones).

**Why I'm noting this:** the interview prompt explicitly asks about times
where the AI got something wrong and how I worked through it. This is one,
and notably it's also a case where the AI caught its own mistake rather than
me catching it. I would have caught it on first run (the link wouldn't have
opened) and that would have cost me 15 minutes debugging. Better to think
about it before generating.

---

## Session 6 — Rewriting the multi-select dropdown

The first build had a Menu-based dropdown for multi-select. I built and ran it
and didn't like how it worked. I wrote a long feedback list — 10 specific issues:

> 1) checkbox * mandatory sign should be in attributedLabel ...
> 2) same in DropdownView * should be in text not in Hstack ...
> 3) I don't like the menu ui for multiple select it should not close on every single tap
>    and their should be checkbox in front of all open to select and deselect and have
>    cancel and apply button
> 4) In dropdown, should open below not on top of it ...
> 5) if option are to many u need to make options scrollable ...
> 6) dropdown menu width should be equal to dropdown selected showing
> 7) only max 5 option shown if more than scrolling
> 8) if option text is multiple line than check box will be horizontally center and
>    only max 2 line allow for option text
> 9) selected option are applied than they should shown in box with cross button and
>    max only 3 row are allow if more not showing last box will be like 5+ etc whatever
>    is remaining
> 10) currently this selected option in dropdown I am seeing flicker for first time
>     after selection when I scroll main view

This was the biggest rebuild of the project. Claude asked four design questions
to lock in behavior before writing code (push-down vs overlay, × button behavior,
Apply-with-no-changes behavior, chip wrap vs scroll), and we agreed on a custom
panel that pushes content below it down, with chips that have immediate-remove
× buttons, and chip wrap capped at 3 rows with "+N" overflow.

### A code path that didn't survive

For the chip overflow ("+N" when chips don't fit in 3 rows), Claude tried a
custom `Layout` protocol implementation. It got tangled — the design needed
to pass an overflow count from the Layout back up to a child view, and
SwiftUI's Layout protocol doesn't have a clean way to do that.

Claude wrote two failed versions before stopping itself: *"I'm overcomplicating
this... Let me take the simpler iOS-native pattern."* The third version used
plain Swift to estimate chip widths via UIFont measurement, packed rows in
a normal function, rendered with VStack of HStacks. Works fine; not as
"clever" as a true Layout but actually delivers.

**My take:** I appreciated that Claude flagged its own over-engineering and
backed out rather than digging deeper. Worth recording because the AI-instinct
default is often "more code, more abstraction." This time the AI caught itself.

The chip wrap layout still has a small one-frame layout shift on first render
because the GeometryReader needs one pass to measure available width. Not
blocking for submission; noted in the README as something to improve.

---

## Session 7 — Unifying single and multi dropdown panels

After multi-select was working, I asked for consistency:

> "for single select dropdown, plz use same MultiSelectPanel without checkbox
>  and cancel and apply button don't use menu, we want both consistent"

Claude proposed two approaches: (1) one panel with a `Mode` enum carrying
different closures per mode, or (2) two separate panel files sharing a base.
It picked (1) and justified it: *"Option 1 is less code, Option 2 is more
'correct' by single-responsibility lights. For a take-home with 2-3 days,
Option 1 is the right call."*

I accepted the call. The result is `DropdownPanel.Mode.single(...)` and
`.multi(...)` with associated values — the type system makes it impossible
to pass an `onApply` closure to single-select where it has no meaning.

For single-select indicator I picked radio buttons over checkmark/highlight,
and "tap commits immediately and closes."

---

## Session 8 — The keyboard saga (the longest debug)

This is the longest session and the most useful for the AI-collaboration writeup.

### The starting problem

Number and Multiline keyboards on iOS don't have a Return key that dismisses,
so I had no way to close the keyboard for those text subtypes. I asked Claude
for a fix.

### What we agreed up front

A keyboard accessory bar with just a Done button. Claude asked design
questions (just Done vs Next+Done; which fields get it) and I picked the
simplest: Done only, on every text subtype.

### The styling fight

I asked for the Done button to be a small blue rectangle (not iOS default
plain text). Claude wrote it with `.buttonStyle(.plain)` + a `RoundedRectangle`
background.

I built it and saw:

> "this is totally not correct I am seeing liquid glass circle then blue
> text with D cut and no 'one' char"

That's iOS 26's new "Liquid Glass" design system. Toolbar buttons get
wrapped in a glass capsule, which was clipping our custom styling.

Claude searched the web for the right opt-out modifier and suggested
`.sharedBackgroundVisibility(.hidden)`. I tried it — compile error:

> "Value of type 'some View' has no member 'sharedBackgroundVisibility'"

Claude went back and re-searched. Turns out the API name it found was from
one questionable forum post; the actual iOS 26 docs say there's no reliable
opt-out for toolbar Liquid Glass styling. Claude wrote in its own log:

> *"I confidently told you to use .sharedBackgroundVisibility(.hidden) based
> on one search result. The follow-up search shows there was no reliable
> opt-out API for Liquid Glass on toolbar items. I should have flagged
> uncertainty when I first suggested it."*

### The pivot to safeAreaInset

Claude proposed switching from `.toolbar(placement: .keyboard)` to
`.safeAreaInset(edge: .bottom)` — render the Done bar as a normal view
positioned at the bottom safe area. The safe area shrinks when the keyboard
appears, so the bar lands above the keyboard. This worked for the Done
button styling.

But then I asked for the layout to be restructured: fixed title at top,
scrolling middle, fixed Save at bottom. I built it and saw:

> "one issue save button is coming on top of keyboard but nothing should
>  have happen"

### Multiple rounds of SwiftUI modifier attempts

The next three rounds were Claude trying different SwiftUI modifier
combinations to keep Save anchored at the screen bottom while the Done bar
rendered above the keyboard. Each one failed in a specific way:

1. `.ignoresSafeArea(.keyboard, edges: .bottom)` on the outer VStack —
   didn't work. Save still lifted with keyboard.

2. Moving `.ignoresSafeArea(.keyboard)` to apply *after* `.safeAreaInset` —
   Claude paused itself realizing this would hide the Done bar under the
   keyboard. Bad fix.

3. ZStack with three layers: form (Layer 1), Save with
   `.ignoresSafeArea(.keyboard)` (Layer 2), Done bar via `.safeAreaInset`
   (Layer 3). I built it — Save still ended up sitting on top of the Done
   bar. Claude realized `safeAreaInset` adds a safe area that Layer 2
   respects, defeating the ignoreSafeArea on Layer 2.

4. ZStack with Done bar as Layer 3 *inside* the ZStack (not via inset).
   This was supposed to be the fix. I built it:

   > "still coming on top of keyboard, it's on top of done button"

### Each round I rejected the result

I want to call this out because the writeup brief asks about "how I push
back." I didn't accept "well, that's just SwiftUI on iOS 26" or "good
enough." I rebuilt and rejected three times before Claude reached for a
different abstraction. The pushback is what forced the next step.

### Claude's pivot to NotificationCenter

After the third rejection Claude wrote:

> *"OK. So the ZStack approach is still failing the same way. The
> .ignoresSafeArea(.keyboard) modifier is genuinely not having the effect I
> expect on iOS 26 — or it's being overridden somewhere. Time to stop
> guessing and go bulletproof. I'll abandon SwiftUI's keyboard avoidance
> system entirely and observe the keyboard directly via NotificationCenter."*

Claude wrote `KeyboardObserver.swift` — a small `ObservableObject` that
subscribes to `UIResponder.keyboardWillShowNotification` /
`keyboardWillHideNotification` and publishes the keyboard height.

Claude also proposed the show-one-or-the-other pattern: keyboard up → Done
bar at the observed height, keyboard down → Save button at the bottom. One
slot, two views, never both visible. This sidesteps every overlap problem
because Save and Done are never on screen simultaneously.

I tried it. It worked.

### What I take from this

The most important AI-collaboration lesson in this whole project. A few
things specifically:

1. **Claude's first attempt at a problem can be confidently wrong.** The
   `.sharedBackgroundVisibility(.hidden)` suggestion was the clearest
   example — confident, well-explained, completely fictional API.

2. **Multiple rejections drive a real abstraction shift.** After three
   "doesn't work" responses, Claude finally questioned whether the
   abstraction itself (SwiftUI's auto-keyboard-avoidance) was the wrong
   tool. If I'd accepted any of the intermediate "good enough" results,
   we'd have shipped with a buggy layout.

3. **The boring solution often wins.** `NotificationCenter` keyboard
   observation has been the standard pattern since 2009. The new SwiftUI
   tools are nice when they work, but when they don't, knowing the
   underlying UIKit foundation is what unblocks you.

---

## Patterns in how I worked with Claude

Things I noticed about the process that might matter for the evaluator:

1. **I made Claude propose options with trade-offs before recommending.**
   Multiple times in this project (polymorphic modeling, state storage,
   max_length enforcement, panel architecture), Claude laid out 2-3
   alternatives with the downside of each before giving its pick. That
   format let me evaluate the reasoning, not just the recommendation.

2. **I scrutinized output before approving the next step.** I caught issues
   in dropdowns, asterisk alignment, link tap conflicts, etc. by reading
   what Claude produced rather than treating it as a black box.

3. **I overrode Claude's recommendation when I had a stronger product
   intuition.** The max_length case is the clearest example. I also pushed
   back on validation timing and on the multi-select dropdown UX.

4. **I asked for verification, not just generation.** The Python parsing
   simulation against both JSON payloads was a good example.

5. **I rejected results that weren't right, even multiple times.** The
   keyboard saga is the clearest case. I rebuilt and reported actual
   observed behavior at each step.

6. **I gave specific feedback, not vague "this isn't working."** Telling
   Claude exactly what I saw ("save button on top of done button" not "the
   keyboard is weird") let it diagnose the problem precisely.

---

## Session 9 — Showcase schema, regex enhancement, and the bug tests uncovered

This session knocked out the remaining optional enhancements (regex
validation, unit tests) and produced the JSON payload I'd use for the demo
video. Worth recording in detail because writing the tests genuinely found
a latent bug in the decoder.

### Building the showcase schema

I asked Claude for a JSON payload covering every field type and subtype so
the demo could exercise the full feature surface in one screen. Claude
produced an 11-field "Create New Campaign" schema:

- TEXT × all 5 subtypes (PLAIN, MULTILINE, NUMBER, URI, SECURE)
- DROPDOWN single-select with a default
- DROPDOWN multi-select with 8 options (enough to trigger scroll + chip
  overflow) and 2 defaults
- TOGGLE on, TOGGLE off
- CHECKBOX with two metadata links + custom link color
- CHECKBOX plain (no links)

It also picked a dark theme palette (`#0F172A` background, `#F1F5F9` text,
`#38BDF8` link, `#FB7185` error) and showed me a quick SVG preview before I
committed to it. Claude ran a Python coverage check to confirm every field
type and subtype was represented before handing it back.

### The regex enhancement and a JSON-escaping gotcha

The spec lists regex validation as an optional enhancement, and the code
plumbing was already in place from session 1 (`regex: String?` decoded in
`TextFieldConfig`, validated in `FormViewModel`). But none of our JSON
files actually used it, so it was invisible in the demo.

I asked Claude to add a URL regex to the `destination_url` field. The
first version it wrote into the JSON via `str_replace` came out with the
wrong number of backslashes — `str_replace` interpreted my escape
sequences and wrote `\\\\w` (four backslashes) into the file when I
needed `\\w` (two, which JSON decodes to `\w`, which is what
`NSRegularExpression` actually wants).

Claude caught this itself when verifying via Python:

> *"The `repr` shows `\\\\w` which means JSON decoded to `\\w` (two
> actual backslashes in the Swift string). That's wrong — I want ONE
> backslash so the regex engine sees `\w`."*

It then rewrote the file using `json.dump` from Python (which handles
escape encoding correctly) and verified with functional tests against
real URLs:

```
[OK] 'https://example.com'                     -> match (expected match)
[OK] 'http://example.com/landing'              -> match
[OK] 'https://sub.domain.example.co.uk/page'   -> match
[OK] 'example.com'                             -> no-match (no scheme)
[OK] 'ftp://example.com'                       -> no-match (wrong scheme)
[OK] 'https://localhost'                       -> no-match (no TLD)
[OK] 'just text'                               -> no-match
```

**Why I'm noting this:** the failure mode (wrong backslash count) was
silent — the JSON parsed fine, the regex compiled fine, it just never
matched anything. Claude only caught it because it explicitly tested the
decoded pattern against known-good and known-bad URLs. Without that
verification step, the bug would have shipped as "URL validation
sometimes lets garbage through."

### Unit tests — and the bug they exposed

For unit tests I told Claude to write **exactly what the spec asks for**:

> "Unit Tests for Polymorphic Parsing: Write a few XCTest cases verifying
> that your JSON decoder correctly maps the different types and handles
> malformed data without crashing."

Nothing fancier. Claude wrote 15 focused tests in two groups:

1. **Type mapping** (6 tests): each `type` string decodes to the correct
   enum case; all 5 text subtypes map; dropdown options decode with
   defaults; toggle, checkbox metadata links.
2. **Resilience** (9 tests): unknown type → `.unknown` filtered, missing
   subtype → PLAIN fallback, unknown subtype → PLAIN fallback, missing
   arrays default to empty, missing `required` flag defaults to false,
   out-of-order fields sort by `order`, missing theme falls back, empty
   fields array decodes, and — crucially — a malformed field (missing
   `id`) is dropped while the rest of the form survives.

### The bug

While writing that last test (malformed field dropped), Claude paused
and re-read the existing `FormSchema` decoder. The original code did:

```swift
if let field = try? fieldsContainer.decode(FormField.self) {
    decoded.append(field)
} else {
    // Skip past the bad element so we don't infinite-loop
    _ = try? fieldsContainer.decode(AnyDecodable.self)
}
```

Where `AnyDecodable` was defined as:

```swift
private struct AnyDecodable: Decodable {}
```

Claude flagged the problem:

> *"`private struct AnyDecodable: Decodable {}` with an empty body — this
> is a problem. An empty `Decodable` struct's synthesized init does
> nothing and doesn't consume the container element. So in the failure
> path, decoding `AnyDecodable` from the unkeyed container may not
> advance the cursor past the bad element, risking either an infinite
> loop or incorrect behavior."*

This was a real latent bug in code from much earlier in the project. The
happy-path demo would never have exposed it — all my test payloads
happened to be well-formed. Only an honest "what if a field is genuinely
broken" test forced it into the open.

### The fix (and a process detail worth noting)

Claude's first attempt at fixing it was to introduce a heavyweight
`AnyJSON` type that captured arbitrary JSON values via re-serialization.
After writing it, Claude paused and called itself out:

> *"This is getting complex for what should be a simple 'skip a bad
> element' operation. ... Am I over-engineering again — the same pattern
> I flagged earlier in the dropdown layout?"*

It backed out and landed on a much cleaner fix: **make `FormField`
decoding total.** Instead of letting a malformed known-type field throw
and trying to skip past it, the typed sub-decode (`TextFieldConfig`,
etc.) now falls back to `.unknown(rawType:)` if it throws. So
`FormField.init` never throws as long as `type` is a string. The whole
fields array decodes in one line:

```swift
let allFields = (try? c.decode([FormField].self, forKey: .fields)) ?? []
let usableFields = allFields.filter { ... not .unknown ... }
```

No container-skipping needed, no infinite-loop risk, fewer lines of
code. **Simpler AND more correct.**

### What I take from this

This was the most useful test-writing session I've had in a while.
Specifically:

1. **Writing tests for "what if this is broken?" cases found a real bug.**
   The original decoder shipped to me with a latent infinite-loop risk
   that no demo would have caught. The malformed-field test was what
   exposed it.

2. **Claude's first fix was over-engineered.** Same pattern I logged in
   Session 6 (the dropdown chip-overflow Layout). The AI's instinct
   toward more abstraction is real and I have to watch for it.

3. **Claude caught its own over-engineering this time.** Without a
   prompt from me, it stopped, named the pattern, and backed out. That's
   the kind of self-correction I want to see — and it suggests the
   earlier pattern recognition (from logging it in Session 6) actually
   stuck.

### Test target setup gotcha

After writing the tests Claude initially placed them in the project
without flagging that `XCTest` and `@testable import` require their own
target. I pushed back:

> "You have forgot XCTest don't run on project target"

Claude added a `SETUP.md` with the steps to add a Unit Testing Bundle in
Xcode. That's the kind of "obvious to humans, easy for AI to miss"
detail worth catching.

### One more thing — the Swift 6 isolation error

After setting up the test target I hit:

> "Main actor-isolated conformance of 'FormField' to 'Decodable' cannot
> be used in nonisolated context"

This is a Swift 6 concurrency issue. The project's build settings use
`-default-isolation MainActor` (modern SwiftUI default), so every type
including `FormField` is implicitly `@MainActor`. The test methods were
nonisolated, so they couldn't call the MainActor-isolated decoder.

Claude offered two paths and flagged the trade-off:

> *"**Option A:** Mark the test `@MainActor`. Simple, test-only change.
> **Option B:** Make the model layer's `Decodable` conformances
> `nonisolated`. Decoding is pure data with no UI dependency, so
> arguably more correct long-term — would let parsing move off the main
> thread for large payloads. For this take-home, Option A is the right
> call (tiny payloads, no real benefit from off-main parsing). But if
> asked in the interview, the honest answer is 'I'd make the model
> conformances nonisolated for a production app.'"*

I took option A. The class-level `@MainActor` annotation resolved it.
But the trade-off note is the kind of thing I'd reference if the
reviewer asks.
