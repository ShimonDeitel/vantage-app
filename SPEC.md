# Vantage — Sketch Proportion Coach

Category: Art & Drawing · Platform: iOS 17+ · Bundle: `com.shimondeitel.vantage`

## Concept

A live camera overlay that turns an iPhone into a classical drawing aid — a proportion
grid plus a plumb line, held up alongside a subject or reference photo while the artist
sketches on real paper — combined with an AI critique step: photograph your finished
sketch next to (or after) the reference, and get specific, numeric proportion-error
feedback instead of vague "keep practicing" advice.

## Problem / evidence

Every serious drawing course still teaches sighting with a pencil held at arm's length
and a plumb line to check verticals — it works, but it takes years to internalize and
there is no feedback loop: a beginner cannot tell *how wrong* their proportions are
until a teacher points it out. Phones already have the sensors (camera + gyroscope) to
recreate the physical plumb-line/grid sighting tools artists use, and now have models
that can compare two images and describe concrete proportion differences.

## Free tier

- Live camera overlay only: proportion grid (2–6 divisions) + a true-vertical/true-
  horizontal plumb crosshair that reads the device's own tilt via CoreMotion and keeps
  itself level regardless of how the phone is held — exactly like a hand-held plumb
  bob, just electronic.
- No AI, no history, no ghost-limb overlay.

## Pro — $5.99/month (auto-renewable subscription, `com.shimondeitel.vantage.pro.monthly`)

- AI proportion comparison: photograph or pick a reference image and photograph your
  sketch; Vantage sends each photo to the shared vision proxy separately (it only
  accepts one image per call), asks for a structured set of proportion ratios for
  each, and computes the actual percentage differences client-side — e.g. "the
  forearm reads about 20% shorter than the reference" — rather than trusting the model
  to do the arithmetic in prose.
- Session history: every critique (reference thumbnail, sketch thumbnail, feedback
  list, timestamp) is saved on-device.
- Ghost-limb correction overlay (quirky feature): after critique, Vantage redraws the
  reference's correct proportions as faint translucent red-pencil tick-mark brackets
  directly on top of the photo of the user's own sketch, positioned at the actual
  corrected proportion lines — the fix is shown in place, not just described in text.

## Animation hook

1. **Live overlay:** plumb lines and grid cells are driven by `CMMotionManager`
   device-motion attitude. As the phone tilts, the overlay counter-rotates to stay
   world-true; when the phone holds steady (rotation rate under threshold), the lines
   spring (`interpolatingSpring`) into a crisp, brightened "locked" state with a
   selection haptic — a visible, physical snap, not a static ruler.
2. **Critique reveal:** after AI critique, the ghost-limb correction marks draw
   themselves onto the sketch photo stroke-by-stroke using a `Canvas` with an animated
   `trim(from:to:)` path per mark, staggered like a signature being drawn in red
   pencil, driven by a `TimelineView(.animation)`.

## AI feature (vision)

Two sequential calls to the shared no-key proxy's `/vision` route (it forwards only
the first `image_url` per call, so one image per request):

1. `describe(reference photo)` → asks the model to return a strict JSON object of
   named proportion ratios relative to overall height (head-to-height, shoulder-width-
   to-height, hip-width-to-height, arm-length-to-height, leg-length-to-height, torso-
   to-height, hand-length-to-height).
2. `describe(sketch photo)` → same schema.
3. `ProportionComparator.compare(reference:, sketch:)` (pure, unit-tested Swift) turns
   the two structured ratio sets into plain-English feedback strings with the real
   computed percentage delta and correct shorter/longer/wider/narrower wording per
   part.
4. If either vision call's JSON fails to parse, Vantage falls back to one `/text` call
   asking the model to phrase the discrepancies as a bullet list from its own two raw
   descriptions, parsed by `ProportionFeedbackParser` into the same feedback-string
   list — so a single malformed response never crashes or blanks the result screen.

## Design direction

Graphite grey + off-white paper-texture background; **one** vivid red-pencil accent
(`#E8362B`) reserved *only* for AI-generated feedback, ghost-limb correction marks, and
the Pro/AI call-to-action — never used for ordinary chrome. Shape language is entirely
linear and angular: crosshairs, plumb lines, corner tick marks, hairline rules, sharp
(0-radius) corners on every primary control. This is the deliberate opposite of the
rounded/organic apps elsewhere in this batch.

## Monetization

Monthly auto-renewable subscription, $5.99/mo, StoreKit 2 with a real
`Transaction.currentEntitlements` / `Transaction.updates` listener and a
`Vantage.storekit` local test configuration. Free tier is the live overlay only; Pro
gates AI critique, history, and the ghost-limb overlay.
