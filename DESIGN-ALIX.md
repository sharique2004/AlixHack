# DESIGN — Alix design language (extracted from meetalix.com, 2026-08-12)

Binding for everything in `demo/frontend/src/atlas/**`. Extracted live from the
production site via computed styles, not guessed. Where Alix uses a proprietary
webfont we substitute the closest free equivalent and say so.

---

## 1. Type

| Role | Alix uses | We use | Spec |
|---|---|---|---|
| Display | **Make** (MakeWay Web, Times-revival serif) | **Instrument Serif** 400 (Google Fonts) | 36–60px, weight 400, `letter-spacing: -0.04em`, `line-height: 1.0–1.06`, sentence case |
| Body/UI | **Beausite Classic** (neo-grotesque) | **Instrument Sans** 400/500/600 | 18px/1.24 for prose, 13–15px for UI, `-0.011em` |
| Mono | — | system mono | code, statute ids, fact paths |

Substitution rationale: Instrument Sans is a slightly condensed neo-grotesque
that tracks Beausite Classic's proportions, and it is the designed sibling of
Instrument Serif, so the pairing is coherent. Deliberately **not Inter** — it is
the default face of nearly every AI-generated interface and reads as templated.

Rules: **sentence case everywhere. Never ALL CAPS for headings.** Headings are
serif; every piece of UI chrome, label, table, and button is sans. Do not mix
serif into small text. Alix's voice is plain declarative sentences ("Alix does
everything for you.") — headings read as sentences and end with a period.

## 2. Color

```
--ink:        #11100D   /* warm near-black: primary text AND primary dark surface */
--paper:      #FFFFFF
--bone:       #E8E5E1   /* warm light surface */
--sand:       #DED6C6   /* warmer accent surface */
--lavender:   #B6ABFD   /* PRIMARY ACTION — buttons, active state, key accent */
--lavender-2: #E2DEFE   /* soft lavender surface */
--navy:       #0C2553   /* deep secondary surface */
--blue:       #043CA5   /* links, active */
--cyan:       #BCE5EA   /* pale accent surface */
```

Discipline: **lavender means action.** Never decorative. Dark surfaces are `ink`
or `navy` only. Status colors are the minimum needed for a legal tool and must
sit as deep text on a pale tint of the same hue, never as saturated fills:
- qualifies / satisfied → deep green on pale green
- needs information → deep amber on pale amber (this is the *neutral* state, not an error)
- ruled out → `ink` at 70% on `bone`
- critical flag → deep red on pale red, used sparingly

## 3. Surface & shape

- **Zero box-shadows.** Alix uses `box-shadow: none` on every element. Depth
  comes from solid color blocks and radius, never elevation. This is the single
  easiest way to look like them and the easiest to get wrong.
- Radii: `16px` full-bleed section cards · `14px` outer card · `12px` panel ·
  `10px` inner card · `8px` small control · full pill for buttons/chips.
- **Signature pattern — the framed card:** a white card at `r:14` with `6px`
  padding wrapping an inner solid-color card at `r:10` (`navy` / `bone` /
  `lavender-2` / `cyan`, rotating). Use for testimonial-shaped content, and here
  for asset cards and route cards.
- **Section = big rounded block.** Major sections are one solid rounded rectangle
  (`ink` or `navy` or `bone`) on a white page, with generous vertical gaps
  (48–72px). Not full-bleed edge-to-edge stripes.
- Borders: hairline `rgba(17,16,13,0.10)` only where a card sits on white and
  needs definition. Prefer color contrast over borders.

## 4. Controls

- Primary button: `lavender` fill, `ink` text, full pill, medium weight, with the
  Alix trailing dot — `Label ·` — rendered as a small circle after the label.
- Secondary: transparent with hairline `ink` border, pill.
- Nav: white pill bar floating on the dark hero.
- Inputs: `bone` fill, no border, `r:8`, `ink` text; focus = 2px `lavender` ring.
- Chips: pill, pale tint fill, deep text, 12px medium.

## 5. Motion

Restrained. 160–220ms `cubic-bezier(0.2,0,0,1)` on state change; no bounce, no
parallax. Verdict changes may cross-fade. Honor `prefers-reduced-motion`.

## 6. Non-negotiables for this project

1. **Attribution footer on every page:**
   "Independent prototype by Sharique Khatri. Not affiliated with, endorsed by,
   or connected to Alix. Design language referenced for evaluation purposes."
   The product must never present itself as a shipped Alix product.
2. **Not legal advice.** The existing boundary language survives: the engine
   proves consequences of supplied facts, not their truth.
3. **Unknown is a first-class state**, styled as neutral amber — never as an
   error, never silently defaulted to false. This is the product's whole thesis
   and the UI must make it feel deliberate and calm.
4. Every legal claim on screen carries its statute citation inline.
