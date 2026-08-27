## Context

See `proposal.md` — Why. What matters here is the shape of what is on disk, verified by reading it:

- `app/lib/design/tokens/brand_colors.dart` imports `dart:ui show Color` and nothing else. 14
  colours, 9 `BrandColorRole` members.
- `app/lib/design/tokens/brand_shape.dart` imports `dart:ui show Offset`. 4 radii, 2 border widths
  (`borderWidth 3`, `iconBorderWidth 7`), 4 shadow offsets, a 7-step spacing scale (4/8/12/18/22/32/44).
- `app/lib/design/tokens/brand_typography.dart` imports `package:flutter/painting.dart`. Nine
  styles, of which five are fixed at one size.
- `app/lib/design/tokens/tokens.dart` is three `export` directives and no import.
- Tests today: `brand_colors_test.dart` (5 tests). **Nothing tests `BrandShape` or `BrandText`.**
- `grep -rn "Color(0x" app/lib` → 14 hits, all in `brand_colors.dart`. `grep -rn "Offset(" app/lib`
  outside `design/brand/spec/` → 2 hits: `speech_bubble.dart:43` and `app_icon.dart:74`.

Two constraints shape every decision below. **BRD-2b** — no colour literal outside `tokens/`, which
is what makes the palette a blocker rather than a convenience. **§2.2's import ceiling** — a
`policy/` module may import `brand_colors.dart` and `brand_shape.dart` directly and may never import
the barrel, because the barrel re-exports `brand_typography.dart`, which pulls in Flutter.

## Goals / Non-Goals

**Goals**

- Every token the F0 fan needs exists before any of the five dependent changes starts, so none of
  them widens the scale as a side effect.
- The two BRD-2b clauses that are `grep`s today become red builds, and neither gate can be
  vacuously green.
- `brand_colors.dart` and `brand_shape.dart` stay importable from `policy/` — no new symbol may
  drag Flutter in.

**Non-Goals** (design level; `proposal.md` holds the scope-level list)

- No new module. This change adds constants, parameters and tests; it creates no class and no
  widget.
- No renames and no removals in `BrandShape` or `BrandColors`. `radiusPill`, `radiusCard`,
  `radiusIconTile`, `radiusScreen`, `shadowPill`, `shadowTile`, `shadowCard`, `shadowIcon` and the
  spacing scale are untouched, so `candy_surface.dart` and the character sheet do not move.
- No spacing-scale entries. See D5.

## Decisions

### Which side of the PURE boundary each file sits on

No new module is created, so the question is whether the additions move an existing file across the
line. They must not.

| File | Side | Why, and what this change may add to it |
|---|---|---|
| `brand_colors.dart` | **PURE** (`dart:ui show Color`) | The 3 new colours are `Color` constants. Stays importable from `policy/` and `design/**/spec/`. |
| `brand_shape.dart` | **PURE** (`dart:ui show Offset`) | The 12 new constants are `double` and `Offset`. Same. |
| `brand_typography.dart` | **adapter** (`package:flutter/painting.dart`) | Returns `TextStyle`, which is a Flutter type. It is on the adapter side today and stays there; the parameter additions change nothing about that. |
| `tokens.dart` (barrel) | **adapter, by transitive closure** | Unchanged. Still forbidden from `policy/` (§2.2). |
| The two `app/test/architecture/` gates | tests | They read `app/lib/` from disk with `dart:io`. Tests are allowed IO; PURE-1 governs `lib/`. |

The honest caveat from §3 travels with this: `brand_shape.dart` opens with `import 'dart:ui'`, so
these files are pure in the PURE-1 sense and run under `flutter test`, but they are **not** portable
to a bare `dart test`. Do not describe them as running without Flutter.

### D1 · Eight radii, not six — the plan contradicts itself and the enumeration wins

`docs/IMPLEMENTATION-PLAN.md` §5.3 D2 tallies "ten names (6 radii + 2 border widths + 2 shadows)".
§3.1 and §3.2 both say "8 radii, 2 border widths, 2 shadows", and §3.2 **names all twelve with their
values**. Taken: the enumeration.

Rationale: D2's substance is *micro-geometry stays out of `BrandShape`*, and that substance is
unaffected by the tally — the parenthetical is a count, not a decision. The enumeration is
name-level and was written against `components.md`'s merged inventory, which is the later document.
Alternative considered: drop two radii to hit six. Rejected because there is no principled pair to
drop — each of the eight is a distinct surface radius named by a screen, and a dropped one comes
back as a literal in the change that needs it, which is the exact failure this change exists to
prevent.

**This dispute never reaches the delta spec.** The scenarios pin only `shadowButton (4, 6)` and
`radiusPanel 24`; the other ten constants are `tasks.md`. The count discrepancy is in `notes`
for Ervin.

### D2 · `hairline` is `Color(0x2E1C1A2E)`, and it gets the scenario the plan's block forgot

§3.2 lands `+hairline` (ink at 18%) in this change and D3 explains why it is a second token rather
than a second alpha on `rule`: `rule` at 16% is card dividers, `hairline` at 18% is the 100+ board
hairlines, and both are used in the same file. But the plan's spec block has no scenario for it,
which would ship a token with a task and no acceptance criterion — against `openspec/config.yaml`'s
*"if you cannot name the test, the scenario is not a requirement yet."*

Taken: `hairline = Color(0x2E1C1A2E)`, and a fourth scenario under `req-palette-coverage`.

The alpha byte follows `rule`'s own convention, which is round-to-nearest on 255: `rule` is `0x29`
= 41/255 = 16.08%, so 18% is `0x2E` = 46/255 = 18.04%. Note the coincidence that trips a reader —
`0x2E` is also the ink's blue byte — and it is the reason the test asserts the alpha numerically
rather than by eye.

### D3 · `BrandColorRole.focus → pink` is added, and the invariant wording is narrowed in the same session

Verified by reading `app/test/design/tokens/brand_colors_test.dart`: the test asserts pink is not
`error.color`, not `success.color` and not `action.color`. It does **not** assert that no role
resolves to pink. Adding `focus(BrandColors.pink)` passes today, unchanged — as D18 predicted and
`primera-vez-cuenta.md` §7.2 claimed. The fifth test, *every role resolves to a fully opaque brand
colour*, also passes: pink is `0xFFE85E92`.

What does go stale is prose. `CLAUDE.md`'s invariant says "pink never carries state" and
`craftsmanship.md` BRD-1 says "pink is the accent and never carries state". Focus is a transient
input affordance, not a verdict, and both sentences must be narrowed to verdicts in this change
(PROC-6, and `CLAUDE.md` wins so the rulebook is the one corrected to match). Alternative
considered: add the role and leave the prose. Rejected — that is precisely the R5 erosion this
phase exists to stop, and it would leave the next reviewer citing BRD-1 against a role the plan
approved.

### D4 · The splash's `width: 4` reverts to 3

`req-splash-measurements`' second scenario is disjunctive — a one-line reason, **or** 3. Taken: 3
(`BrandShape.borderWidth`).

Only that branch is assertable by a widget test, which is what the scenario names as its check; a
justifying comment is a reviewer's read, not a red build. It is also the branch BRD-2c points at —
the rulebook says outright that this border "is *not* justified and is not pre-blessed", while the
same tile's 60 px radius **is** justified in its doc comment and stays. So the file ends with
exactly one deliberate departure, and it is the one that has a reason.

Consequence: BRD-2c's example sentence becomes false the moment this lands and is corrected in the
same session (PROC-6). The 260 px tile size and the 232 px face stay as they are — no document
measures the green variant, and D19 only re-measures `0.1`.

### D5 · The uniform 26 is one named constant in the splash, not a spacing token

The design's three gaps are 26/26/26. The scale is 4/8/12/18/22/32/44 and the file currently reaches
28 and 36 by arithmetic (`space6 - space1`, `space7 - space2`).

Taken: one private `_gap` constant in `splash_screen.dart` with a one-line reason, replacing all
three expressions.

Alternatives: (a) add `BrandShape.space` entry for 26 — rejected, §3.3's rule is that `BrandShape`
governs recurring widget surfaces and a one-screen gap is not a scale entry; the same logic that
keeps cage corners out keeps this out. (b) `BrandShape.space5 + BrandShape.space1` — rejected, it
matches the file's existing idiom but a reader has to compute 22 + 4 to see 26, and the point of the
change is that the measurement is *uniform*. One constant makes the uniformity structural instead of
coincidental, and BRD-2c's "deliberate departure with a one-line reason" clause is the rule that
allows it.

### D6 · Letter spacing is requested in em

`BrandText.eyebrow(size: 10, letterSpacing: 0.06)` returns 0.6 px of tracking, so the parameter is
em and is resolved against the style's own size. This is not an invention: `descriptor` already does
`letterSpacing: size * 0.22`, and the design documents state tracking in em (.06/.08/.1). Taking it
in px instead would make every call site do the multiplication and would silently break when a size
changes.

Defaults preserve today's rendering exactly — `eyebrow()` is 12 px at 1.2 px tracking today, which
is 0.1em, so `eyebrow({double size = 12, double letterSpacing = 0.1})` returns a byte-identical
style. The same rule governs `cardTitle({size = 20})`, `body({height = 1.5})` and
`caption({size = 13, height = 1.5})`: **every new parameter defaults to the value on disk**, so the
34 committed tests stay green for the right reason.

### D7 · `numeral(size)` is added; `sectionTitle` stays

`numeral` takes its size positionally (`BrandText.numeral(29)`), matching `wordmark(size, color)`
and within FUN-1's three-positional ceiling. `sectionTitle({size})` is not renamed and not removed —
it has call sites, and the scenario's complaint is that a keypad digit should not *reach for* it,
not that section headers should stop existing. The two return the same `TextStyle` shape today; they
diverge the day a section header gains tracking, and the name is what makes that possible.

`BrandFonts.display`'s doc comment — *"Wordmark and section headers only"* — is what makes `numeral`
look like a violation, so it is rewritten in this change (§3.2, PROC-6). Darumadrop is the face for
every keypad digit, numeral, board digit, stat value and OTP digit.

### D8 · The colour gate matches Dart colour constructors, never hex text

`app/lib/features/character_sheet/character_sheet_screen.dart:118–121` contains the strings
`'CUERPO #F7DFB6'`, `'HOCICO #4A4060'`, `'OREJAS #332B44'` and `'COLLAR #E85E92'` — four brand hexes
printed as **labels on the character sheet**, which is a screen whose job is to display them. A gate
that scanned for `#RRGGBB` would go red on day one against correct code.

Taken: `no_color_literal_test.dart` matches `Color(0x`, `Color.fromARGB(`, `Color.fromRGBO(` and
`Colors.` under `app/lib/`, excluding `app/lib/design/tokens/`, with comments stripped first.
`Colors.transparent` is carved out by name — four uses in `theme.dart:37,42,48,53`, verbatim in both
`CLAUDE.md` and BRD-2b. Derived colours are out of scope by construction: `withValues(alpha:)` at
`brand_drawing_painter.dart:91` takes a token and adjusts it, which is what tokens are for.

**The `Colors.` pattern MUST be matched on a word boundary, and this is not a detail.** `Colors.`
is a **substring of `BrandColors.`**, which is the correct, mandated way every widget in this
repository names a hue. Measured on the tree as it stands:
`grep -rn "Colors\." app/lib/` returns **115 lines**; the same scan excluding
`app/lib/design/tokens/` and excluding word-boundary matches returns **94 false positives across 12
files** — every one of them correct code doing exactly what BRD-2b requires. A naive substring gate
is red on day one against `BrandColors.ink`, and the engineer who meets that either deletes the
`Colors.` arm or narrows the root until it passes, which is how a gate becomes vacuous.

The match is therefore `(?<![A-Za-z0-9_$])Colors\.` — a negative lookbehind, not a substring. On the
current tree that returns exactly the four `Colors.transparent` uses in `theme.dart`, i.e. exactly
the carve-out and nothing else, which is the check that proves the pattern is right before the
carve-out is applied. This is the same failure mode as the `#RRGGBB` trap above, on the other
pattern: **a colour gate's hard problem is its false positives, not its recall.**

Stated limit, so it is not discovered as a bug later: a text scan cannot see a colour assembled at
runtime from ints. The gate raises the floor; it does not replace the reviewer.

### D9 · The geometry gate is `Offset(` only, rooted at widget surfaces

`aki_spec.dart` holds 95 `Offset(` literals and `app_icon.dart:74` holds one more
(`Offset(size * 6 / 240, size * 8 / 240)`, a proportional scale, not a constant). None of them is a
defect: §3.3 is explicit that micro-geometry belongs to the spec module that draws it, and
`BrandShape` governs widget surfaces.

Taken: `no_geometry_literal_test.dart` scans `app/lib/design/widgets/` and `app/lib/features/` for
`Offset(`, comments stripped. `app/lib/design/brand/` is out of scope — it is the artwork layer,
where geometry *is* the content.

Radii and border widths are **not** scanned. A bare `24` is not greppable without parsing, and a
gate that pretends to cover them would be a false claim in the rulebook. BRD-2c stays a SHOULD the
reviewer reads for on those two, and the spec says so rather than implying more coverage than
exists.

### D10 · Neither gate may be vacuously green

Both tests enumerate their roots and **fail if a root that exists on disk yielded zero scanned
files**, and both report the count. This mirrors `f0-invariant-tests`' own *"The gate is not
vacuously green"* scenario and exists because a path typo turns either of these into a permanently
passing test — the failure mode `dart_code_linter` already demonstrates in this repo
(`craftsmanship.md` PROC-5: a check that can only ever be green is not evidence).

### D11 · `f0-invariant-tests` lands first, and this change reuses its tree walker

*(Rewritten at cross-review. The first draft read this as an unresolvable plan contradiction and
took "ordering preference, not a code dependency". The plan does resolve it, in a passage the draft
did not cite.)*

The apparent contradiction: the change block says **"Depends on: nothing"**; §4's preamble
(plan:666-668) says `app/test/architecture/` "does not exist on disk yet; `f0-invariant-tests`
creates it, and every scenario below that names a file under it inherits that ordering."

**`f0-invariant-tests`' own block settles it, verbatim (plan:1030-1031):** *"It also creates
`app/test/architecture/`, which several F0 scenarios above already name. It is not 'any time': it is
first."* That is a decision, not a preference, and "Depends on: nothing" is about **this** change's
inputs, not about sequencing the F0 fan. Two of this change's scenarios name files under
`app/test/architecture/`. So:

Taken: **`f0-invariant-tests` lands before this change.** Hard ordering.

That ordering also buys something concrete, which is the second reason to take it. `f0-invariant-tests`
builds `app/test/architecture/source_tree.dart` — the PURE-2 adapter that walks `app/lib/`, strips
comments and returns `Map<lib-relative-path, source>`, reporting an absent root as absent. That is
**exactly** what both gates here need, and both need comments stripped for the same reason. Writing
a second and third comment-stripping tree walker beside it would be three implementations of one
adapter, drifting independently on the one behaviour (comment stripping) that every one of these
gates' false-positive stories depends on — and `npm run dry` is TypeScript-only, so nothing in the
committed gate would report the duplication.

**Tasks 4.1 and 5.2 therefore consume `source_tree.dart` and add only their own pattern matching.**
Each gate stays a pure predicate over `Map<path, source>`, which keeps PURE-1 intact and means the
non-vacuity guard of D10 is inherited from one place rather than restated twice.

### D12 · Two radii share a value, and both keep their names

`radiusButton 20` and the existing `radiusIconTile 20` are the same number. They are kept as two
names because they are two roles — the app-icon tile is drawn at 240 px in the lockup, the button at
h60 in the flow — and the day one of them moves, a shared constant would move both. Equal values are
not a duplication; a shared name would be a coupling.

## Risks / Trade-offs

- **A gate scoped by a path string is one typo away from being permanently green** → D10: both gates
  report their scanned count and fail at zero for a root that exists.
- **The colour gate false-positives on the character sheet's own hex labels** → D8: the gate matches
  Dart colour constructors, never `#RRGGBB` text. Four real call sites would have gone red.
- **The splash re-measurement is the one visually observable change here** → Tier 2 evidence is
  required, not optional: the change ships with the app run on a simulator and the two splash
  variants looked at. A widget test proves `Aki.width == 210`; it does not prove the composition
  still reads.
- **Twelve new constants land with two of them pinned by a scenario** → the other ten are covered by
  a single `brand_shape_test.dart` that asserts each value, so a typo in a hex or an offset is
  caught by the suite rather than by a screen six changes later.
- **`borderWidthThin 2.5` is thicker than `borderWidthField 2`, which reads backwards** → settled,
  not deferred: the constant ships as `borderWidthSmallSurface`, named for the surface it outlines
  the way the radii are (NAM-1). A name ranking it against the other strokes would be false, and a
  developer reaching for the thinnest stroke would draw the thicker one. `proposal.md` and
  `tasks.md` still record the planned name, which is what was approved.
- **Tier 1b has no mutation harness on the Dart side** → the falsification step (PROC-5) targets the
  two gates, which are the only logic in this change: insert a `Color(0xFF000000)` into a widget
  file and an `Offset(1, 1)` into `speech_bubble.dart`, watch each named gate go red, then restore
  and prove it with `git diff --quiet` and a `flutter test` back to the recorded count. Asserting a
  constant equals itself is not falsifiable and no falsification is claimed for the twelve.

## Migration Plan

There is nothing to deploy. The only behavioural change visible to a running app is the splash's
geometry; every other edit is additive, and no existing constant is renamed or removed, so
`candy_surface.dart`, `loading_dots.dart`, `app_icon.dart` and the character sheet compile
untouched. Rollback is `git revert`.
