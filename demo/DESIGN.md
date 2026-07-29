---
name: Simple Transfer — LLM vs Compiled Law
description: Light SaaS comparison canon — neutral LLM card vs blue-tinted compiled-law card, played straight and live
colors:
  bg: "#fbfcfe"
  card: "#ffffff"
  ink: "#0e1420"
  ink-2: "#475467"
  ink-3: "#98a2b3"
  line: "#e9edf3"
  line-soft: "#f1f4f8"
  blue: "#3b82f6"
  blue-ink: "#1d4ed8"
  blue-tint-1: "#eaf3ff"
  blue-tint-2: "#f6faff"
  green: "#16a34a"
  green-tint: "#e9f7ee"
  amber: "#b45309"
  amber-tint: "#fdf3e4"
  slate: "#64748b"
  red: "#dc2626"
  red-tint: "#fdecec"
typography:
  display:
    fontFamily: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "clamp(2.1rem, 4.6vw, 3.35rem)"
    fontWeight: 800
    lineHeight: 1.08
    letterSpacing: "-0.025em"
  title:
    fontFamily: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "1.02rem"
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "0.9rem"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif"
    fontSize: "0.74rem"
    fontWeight: 600
    letterSpacing: "0.05em"
  mono:
    fontFamily: "ui-monospace, SF Mono, Menlo, Consolas, monospace"
    fontSize: "0.78rem"
    lineHeight: 1.55
rounded:
  row: "8px"
  select: "10px"
  inset: "12px"
  panel: "16px"
  card: "24px"
  pill: "999px"
spacing:
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "16px"
  xl: "20px"
  card-pad: "26px"
  grid-gap: "28px"
components:
  button-dark:
    backgroundColor: "{colors.ink}"
    textColor: "#ffffff"
    rounded: "{rounded.pill}"
    padding: "11px 22px"
  button-dark-hover:
    backgroundColor: "#232c3d"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.ink-2}"
    rounded: "{rounded.pill}"
    padding: "9px 18px"
  button-ghost-hover:
    backgroundColor: "{colors.line-soft}"
  chip-green:
    backgroundColor: "{colors.green-tint}"
    textColor: "#15683c"
    rounded: "{rounded.pill}"
    padding: "5px 11px"
  chip-amber:
    backgroundColor: "{colors.amber-tint}"
    textColor: "{colors.amber}"
    rounded: "{rounded.pill}"
    padding: "5px 11px"
  chip-blue:
    backgroundColor: "#e7f0fe"
    textColor: "{colors.blue-ink}"
    rounded: "{rounded.pill}"
    padding: "5px 11px"
  pill-badge:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink-2}"
    rounded: "{rounded.pill}"
    padding: "7px 16px"
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.card}"
    padding: "26px 26px 22px"
  card-panel:
    backgroundColor: "rgba(255, 255, 255, 0.86)"
    rounded: "{rounded.panel}"
    padding: "14px 16px 6px"
---

# Design System: Simple Transfer — LLM vs Compiled Law

## Overview

**Creative North Star: "The Comparison Section, Played Straight"**

This is the light SaaS comparison-section convention (per the user-pinned Dribbble
reference: Abu Fahim, "Crypto Market Problems vs Smart Solutions") executed at full
craft fidelity, with no irony — but wired live. The page reads like a marketing
section: near-white canvas, centered pill badge, huge tight Inter heading, gray
subtext, two big rounded comparison cards. Every number on it, however, comes from a
real run: elapsed timers tick, verdicts recolor, the compiled card re-answers as a
slider moves. The aesthetic promises polish; the content delivers evidence.

The world is airy and low-contrast at the surface level (hairline borders, soft
diffuse shadows, pale tints) with contrast concentrated where it argues: near-black
ink for headings and CTAs, saturated status hues only inside their pale tint fields.
The neutral card carries the LLM; the blue-gradient "solution" card carries the
compiled Lean engine — the tint itself is the thesis.

**Key Characteristics:**
- White-on-white layering: `#fbfcfe` page, `#ffffff` surfaces, separated by 1px hairlines and two soft shadows, never heavy strokes.
- Single family: Inter at weights 400–800 does all prose work; a system mono stack appears only for code and JSON.
- Pill geometry for everything interactive; large radii (16–24px) for surfaces.
- Status quartet (green / amber / slate / red) always rendered as deep-hue text on a pale tint, never solid saturated fills.
- Blue is identity, not action: it tints the solution card, links, chips, focus rings, and the slider — the CTA is dark ink.

## Colors

A near-white neutral ramp carries the page; one blue owns the solution identity; three status hues appear only in tinted pairs.

### Primary
- **Signal Blue** (`--blue`, #3b82f6): focus rings, slider accent, spinner head. The functional blue.
- **Deep Link Blue** (`--blue-ink`, #1d4ed8): link-style toggles, blue chip text, blue verdict text, the Lean icon tile glyph.
- **Solution Tints** (`--blue-tint-1` #eaf3ff, `--blue-tint-2` #f6faff): the Lean card's layered gradient (a radial `rgba(147,197,253,0.5)` glow at top-right over a 165deg linear fade to white), with border `#d8e6fa`.

### Neutral
- **Page** (`--bg`, #fbfcfe): the only page background.
- **Surface White** (`--card`, #ffffff): cards, toolbar, selects, editor, pills.
- **Ink** (`--ink`, #0e1420): headings, metric values, primary button fill, active tab fill.
- **Ink 2** (`--ink-2`, #475467): subtext, taglines, route details, ghost button text.
- **Ink 3** (`--ink-3`, #98a2b3): labels, citations, footnotes, empty states.
- **Hairline** (`--line`, #e9edf3): all component borders (always 1px).
- **Hairline Soft** (`--line-soft`, #f1f4f8): row dividers, hover washes, inline-code and empty-state backgrounds.

### Tertiary (status hues, always with their tint)
- **Confirm Green** (`--green` #16a34a / `--green-tint` #e9f7ee): qualifying routes, ELIGIBLE verdicts, valid-JSON dot, verification chips.
- **Caution Amber** (`--amber` #b45309 / `--amber-tint` #fdf3e4): needs-info states, INCOMPLETE verdicts, stale chip, accuracy chip.
- **Ruled-Out Slate** (`--slate`, #64748b): the neutral "does not qualify" glyph — a non-alarming no.
- **Error Red** (`--red` #dc2626 / `--red-tint` #fdecec): typed errors and unavailability only. Never decorative.

### Named Rules
**The Solution Tint Rule.** The blue gradient belongs to the compiled-law card alone. No other surface on the page may take a blue background wash; elsewhere blue appears only as focus ring, link text, chip, or slider accent.

**The Tint Pair Rule.** Status hues never appear as saturated solid fills behind text. A verdict or chip is always deep-hue text (e.g. #14532d, #7c3f06) on the hue's pale tint, bounded at most by a slightly deeper 1px tinted border.

## Typography

**Display/Body Font:** Inter (with -apple-system, Segoe UI fallback) — loaded at 400/500/600/700/800. Binding brand commitment; single family.
**Mono Font:** system mono stack (ui-monospace, SF Mono, Menlo, Consolas) — code, JSON, source tabs only.

**Character:** Confident modern SaaS: heavy tight-tracked headings against relaxed gray body text. Hierarchy is built entirely from weight, size, and letter-spacing within one family.

### Hierarchy
- **Display** (800, clamp(2.1rem, 4.6vw, 3.35rem), 1.08, -0.025em, `text-wrap: balance`): the single centered page heading.
- **Title** (700, 1.5rem, 1.15, -0.02em): card headings ("Ask an LLM Every Time.").
- **Body** (400, 1.02rem, gray `--ink-2`, max 56ch): intro subtext. Secondary body runs 0.87–0.93rem for taglines, blurbs, route names, reasoning (max 72ch).
- **Label** (600, 0.72–0.74rem, 0.05em, UPPERCASE for control labels): control labels, metric labels, citations.
- **Numerals**: metrics, timers, and slider values always use `font-variant-numeric: tabular-nums` at weight 600–700.
- **Mono** (0.72–0.8rem, 1.55): JSON editor, Lean source, inline `code`, source tabs.

### Named Rules
**The One Family Rule.** Inter carries every piece of prose at weights 400–800. The only second voice is the system mono stack, and it is reserved for literal code and data.

**The Tight-Heavy Rule.** As weight goes up, tracking goes down: 800 at -0.025em, 700 at -0.02em, body at normal, small labels positive-tracked and uppercase.

## Layout

Single centered column, `max-width: 1120px`, page padding `72px 24px 64px` (44/16/48 under 640px). Vertical flow: centered intro → toolbar panel → optional JSON drawer → two-card grid → centered footnote.

The comparison grid is `1fr 1fr` with a 28px gap, items top-aligned. Below 980px it stacks to one column and the Lean (solution) card reorders to the top — the answer leads on mobile. Below 640px the toolbar stacks vertically, selects go full-width, and the card CTA becomes a full-width pill.

Spacing rhythm is a loose 4-based scale observed as 6 / 10 / 14 / 16 / 20 / 26 / 28: 26px card padding (20/18 narrow), 14–16px between card zones, 10–11px inside rows and pills. Toolbar and card internals use flex with `gap`, wrapping freely; right-aligned elements (CTA, elapsed timer, stale chip, statuses) use `margin-left: auto`, not absolute positioning.

## Elevation & Depth

Soft ambient layering, never structural. Two shadows exist: a large diffuse card shadow and a whisper for small controls. Depth is otherwise conveyed by background steps (page → white surface → translucent inner panel `rgba(255,255,255,0.86)` → tint field) and 1px hairlines. Hover states change background color or lift 1px; they do not add shadow.

### Shadow Vocabulary
- **Card** (`box-shadow: 0 1px 2px rgba(16,24,40,0.04), 0 12px 32px rgba(16,24,40,0.07)`): the two comparison cards only.
- **Soft** (`box-shadow: 0 1px 2px rgba(16,24,40,0.05)`): pill badge, toolbar, selects, icon tiles, editor.

### Named Rules
**The Two-Shadow Rule.** Only these two shadows exist. Nothing glows, nothing drops harder than `rgba(16,24,40,0.07)`.

## Shapes

Radius encodes role, descending with nesting: 24px comparison cards → 16px panels (toolbar, inner card panel, editor) → 12px insets (verdict banner, code viewer) → 10px selects → 8px row hover wash → full pill (999px) for every freestanding control. Borders are always 1px — `--line` on neutral surfaces, a tinted 1px on colored chips and the Lean card. No sharp corners exist anywhere; no border is ever thicker than 1px.

Icon tiles are 54px squares at 16px radius holding a 26px stroke/duotone SVG on a subtle two-stop linear gradient (neutral `#f4f7fb→#e8edf5` for LLM, blue `#dbeafe→#eff6ff` for Lean). Status glyphs are 16–17px SVG circles at 12–14% opacity fill with a 1.6–1.9px stroked mark in the full-strength hue.

### Named Rules
**The Pill Rule.** Buttons, chips, badges, tabs, and the stale marker are full pills (999px). Rounded rectangles are for surfaces and fields, never for standalone controls.

## Components

### Buttons
- **Shape:** full pill (999px).
- **Primary (`.btn-dark`):** white 600-weight text on Ink (#0e1420), `11px 22px`. Hover: lightens to #232c3d and lifts 1px (140ms; transform on a `cubic-bezier(0.16,1,0.3,1)` ease-out). Disabled: 45% opacity. Full-width below 640px.
- **Ghost (`.btn-ghost`):** transparent with 1px `--line` border, `--ink-2` text, `9px 18px`. Hover: `--line-soft` wash.
- **Link toggle (`.link-toggle`):** bare 600-weight `--blue-ink` text, underline on hover; used for progressive disclosure (reasoning, Lean source).
- **Focus (all interactive elements):** `outline: 2px solid var(--blue); outline-offset: 2px`.

### Chips
- **Style:** pill, 600 weight, 0.7–0.76rem; deep-hue text on tint background with a slightly deeper 1px tinted border (green `#cdebd8`, amber `#f3ddb8`, blue `#cfe0fa`).
- **Variants:** green (theorem/sample-contract claims), amber (accuracy caveats, "outdated" stale chip on white), blue (capability notes). Chips state evidence; they are not interactive.

### Cards / Containers
- **Corner Style:** 24px.
- **Background:** white for the neutral (LLM) card; the layered blue gradient for the Lean card (see Colors).
- **Shadow:** Card shadow; **Border:** 1px `--line` (blue-tinted `#d8e6fa` on Lean).
- **Anatomy (both cards, strictly parallel):** head (icon tile + title/tagline) → controls row (chips/select) → translucent inner panel at 16px radius holding verdict banner + route checklist → foot (metrics + CTA) → hairline-topped extra zone (reasoning / source viewer).
- **Verdict banner:** 12px radius, 600-weight deep-hue text on tint; pending state shows spinner + live tabular-nums elapsed timer; stale results get the amber "outdated" pill.
- **Metrics:** uppercase-adjacent 0.72rem gray label over 700-weight tabular-nums value.

### Inputs / Fields
- **Selects:** white, 1px `--line`, 10px radius, `9px 12px`, 500 weight, soft shadow.
- **Range slider:** native input with `accent-color: var(--blue)`; value readout right-aligned in tabular-nums.
- **JSON editor:** mono 0.8rem textarea, 16px radius, white, hairline border; validity shown by an 8px green/amber dot plus label, and a disabled-until-valid dark CTA.

### Navigation
None. Single-viewport page; the toolbar (white 16px-radius panel with labeled controls) is the only control strip.

### Route Checklist (signature)
Six full-width rows separated by 1px `--line-soft` hairlines (no divider above the first). Each row: status glyph (green check / amber info / slate cross / pulsing empty circle while pending) + 500-weight route name + tiny gray citation (`§13100`) + right-aligned 600-weight status word in the matching hue. Rows with detail are buttons that hover-wash `--line-soft` and expand an indented gray detail block with mono `code` chips. Pending runs render skeleton rows at 45% opacity with a 1.1s pulse.

### Code Viewer (signature)
The page's sole dark surface: `#0f1522` block, `#d5dce8` mono text at 0.74rem, 12px radius, max-height 320px scroll. Tabbed by pill-shaped mono source tabs whose active state inverts to Ink. Reads as a terminal window embedded in the light page.

## Do's and Don'ts

### Do:
- **Do** keep the two comparison cards structurally parallel — same anatomy, same order — so the only asymmetry is the Lean card's blue tint and its evidence chips.
- **Do** render every metric, timer, and money value in tabular-nums, and every status as deep-hue text on its pale tint.
- **Do** separate list rows with 1px `--line-soft` hairlines instead of boxing them.
- **Do** use progressive disclosure via `--blue-ink` link toggles (reasoning, source, JSON drawer) rather than adding permanent chrome.
- **Do** honor `prefers-reduced-motion` (spinner and skeleton pulse stop; button transitions off) and keep the 2px blue focus outline on everything focusable.

### Don't:
- **Don't** introduce a second prose typeface; Inter is a binding brand commitment (mono is for literal code only).
- **Don't** give any surface other than the Lean card a blue background wash, and don't use blue as a button fill — primary actions are ink pills.
- **Don't** exceed 1px borders or the two established shadows; contrast comes from ink and tint, not strokes and glow.
- **Don't** add dark surfaces beyond the established ink pills, active source tabs, and the code viewer.
- **Don't** stage numbers — metrics render "—" until a real run supplies them, and superseded results must carry the stale "outdated" chip rather than being silently kept.
