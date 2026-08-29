# SOLID audit — `app/lib/design/**`

53 Dart files, read at `653a17b`. Documentation only; no production code was changed.

## Verdict

**The module is in good shape.** The one structural pattern this repository commits to — pure
policy separated from the IO adapter — is not merely followed here, it was *invented* here, and
`design/brand/` and `design/math/` are the reference implementations the rest of the repo is
measured against. The pure boundary is a red build (`app/test/architecture/pure_boundary_test.dart`),
the palette boundary is a red build (`no_color_literal_test.dart`), the shadow and hue rules are red
builds, and where a rule is only a reviewer's read the file usually says so in its own doc comment.
Four findings below, and it took real looking to get to four.

> **Findings 1 and 4 are fixed** on `fix-a-killer-cage-draws-its-own-dash` (2026-08-29). They are
> kept below as written, because the record of what was wrong is what makes the fix reviewable, and
> each carries a resolution note at its end. Findings 2 and 3 stand. **Read finding 1's present
> tense as the state it audited, not as today's**: a document asserting a live defect that is no
> longer live is the same defect as a comment claiming behaviour the code does not have (CMT-2).

**The single most expensive thing in the module is that a puzzle cage's appearance has no owner.**
It is decided in four files across four directories — three of them named for something other than
puzzles — and the file that was written to be the one place it is decided
(`design/painting/spec/cage_outline.dart`) has **zero production callers**. The consequence is not
theoretical: the Killer board draws the KenKen dash today, because the two widgets that actually
paint a cage hard-code `DashSpec.kenKenCage` and never read the spec. Its test is green.

---

## Findings, highest cost first

### 1. A puzzle cage's look is decided in four directories, and the file that owns it is orphaned

**Principle:** SRP, in the *who asks for the change* sense. One person — the designer of
`reactivos-puzzles.md`, cited by name in all four files — owns "what a cage looks like". Their
decision is currently recorded in one place and applied in two others that never read it.

**Where the pieces are:**

| Fact | File |
|---|---|
| A cage's dash, stroke, radius, inset | `app/lib/design/painting/spec/cage_outline.dart:35-47` |
| A cage's edge set, from cell membership | `app/lib/design/puzzle/spec/board_geometry.dart:42-109` |
| The painter that strokes those edges | `app/lib/design/painting/cage_edge_painter.dart:25-105` |
| A cage cell's fill | `app/lib/design/widgets/spec/puzzle_cell_visual.dart:44-78` |

`design/puzzle/` itself holds two geometry files and **no adapter at all**, while
`design/painting/cage_edge_painter.dart:5` reads

```dart
import '../puzzle/spec/board_geometry.dart' show CageEdges;
```

— so the generic painting layer depends on the puzzle layer, which is the wrong direction for a
directory whose other inhabitant (`dashed_border_painter.dart`) is a generic widget-surface
primitive.

**The cost, and it is live.** `CageOutline.kenKen` and `CageOutline.killer` are referenced by no
production file. The only two sites that paint a cage —
`app/lib/features/puzzle/ui/puzzle_board_view.dart:300-305` and
`app/lib/features/puzzle/ui/reference_card.dart:236-241` — each name the pattern and the stroke
themselves:

```dart
CageEdgePainter(
  edges: outline,
  dash: DashSpec.kenKenCage,
  color: BrandColors.pink,
  strokeWidth: BrandShape.borderWidthCage,
)
```

`DashSpec.killerCage` — the round-capped `2 / 5` pattern the design specifies for Killer, and the
reason `DashCap.round` exists at `dash_spec.dart:19` — reaches no screen in `app/lib`. Killer
routes through the same widget as KenKen (`features/puzzle/policy/reference_card.dart:165` picks
its diagrams and the board view draws them), so **a Killer cage renders with the KenKen dash**.
Meanwhile `app/test/design/painting/dashed_border_test.dart:99-101` asserts
`CageOutline.killer.dash.cap == DashCap.round` and passes — a test certifying a figure nothing
draws. Edit `CageOutline` today and nothing on a device moves.

The two costs compound, and the second explains the first: the spec and its call sites never met
*because* they live in directories named for different things.

**Direction.** Move `cage_outline.dart` and `cage_edge_painter.dart` under `design/puzzle/` as
`spec/` and adapter — the split this repo already has a precedent and a gate for — and have the two
widgets take a `CageOutline` chosen by puzzle kind rather than naming a `DashSpec` and a stroke
width each. `painting/` keeps `dash_spec.dart` and `dashed_border_painter.dart`, which are genuinely
generic and have callers all over `features/`.

**Resolved (2026-08-29), broadly as directed.** Both files moved under `design/puzzle/` as `spec/`
and adapter, so the generic painting layer no longer imports the puzzle layer, and the geometry
gate's roots followed the painter — a file that walks out of a root is a file the gate stops
seeing. `CageOutline` gained the colour and the stroke and became the one owner; `CageEdgePainter`
takes an outline and names no appearance of its own.

**Where the fix departed from the direction.** The direction says *"take a `CageOutline` chosen by
puzzle kind"*, and the choosing did **not** get its own function. `boardConstraints` in
`features/puzzle/policy/board_constraints.dart` was already an exhaustive switch over the same
sealed type deciding what a board shows; a second one deciding how its cages look would be two
functions a sixth format has to be added to with no compiler saying so. The outline is a field on
`BoardConstraints`, set by `BoardConstraints.cages`, whose initializing formal narrows it to a
**non-null** `CageOutline` — so *a cage without its outline* is unconstructible rather than
asserted, and one switch produces both facts. Measured: with a sixth caged leaf on the hierarchy,
naming it and forgetting the outline is
`2 positional arguments expected by 'cages', but 1 found`.

Two smaller departures: `board_geometry`'s `cageOutline` **function** was renamed `cageEdges`,
because one word for both the edge set and the appearance is how the two came to be decided in
different directories; and `radius`/`inset` were **dropped** rather than moved, along with the
archived spec's *"neither overlaps the 1.5 px hairline"* assertion, which was arithmetic on them
and is false of the per-edge model that shipped. Both are written down in the new file's doc
comment and in `docs/IMPLEMENTATION-PLAN.md`.

The defect was confirmed at the screen before the fix and after it: a `PuzzleScreen` holding a
`KillerPuzzle` reported `6.0 on / 4.0 off, butt cap`, and reports `2.0 on / 5.0 off, round cap`
now, with the sibling KenKen assertion passing in both runs. On an iPhone 17 the two boards read as
long dashes and as dots, and the Killer reference card's *"borde punteado"* is finally a true
caption.

---

### 2. `BrandColorRole` is three vocabularies in one enum, and it is incomplete for all three

**Principle:** ISP first, then DIP. `BrandColorRole` (`app/lib/design/tokens/brand_colors.dart:84-119`)
is a single flat enum serving three unrelated clients:

- **surfaces** — `ink`, `canvas`, `surface`
- **state** — `action`, `success`, `error`
- **emphasis and affordance** — `accent`, `focus`, `highlight`, `secondaryText`

No client wants all ten, and — the part that does the damage — **no arm exists for the fills the
design actually assigns by role elsewhere**. The keypad's four `KeyRole` values each carry a fill
the design chose deliberately (`keypad_layout.dart:68-82`), and `BrandColorRole` can express one of
them. So `app/lib/design/widgets/keypad.dart:47-52` resolves three arms from raw hues and the
fourth from a role, inside a single switch:

```dart
Color get _fill => switch (data.role) {
      KeyRole.digit => BrandColors.surface,
      KeyRole.operator => BrandColors.pinkSoft,
      KeyRole.erase => BrandColors.quiet,
      KeyRole.commit => BrandColorRole.action.color,
    };
```

A call site that wants to ask for a role *cannot*, so it reaches past the abstraction for the
concretion. Two more inside the module, both in files whose own doc comments cite BRD-1:
`app/lib/design/widgets/spec/day_mark_visual.dart:35` states "this day was played" as
`BrandColors.green`, and `app/lib/design/widgets/spec/nav_tab_visual.dart:44` states "this tab is
selected" the same way.

**The cost.** BRD-1's promise is that "remapping is a brand decision made in one place"
(`brand_colors.dart:81-83`). Measured across `app/lib`, it is not: `BrandColors.green` appears **12**
times against **10** uses of `BrandColorRole.action` and `.success` combined, and `BrandColors.coral`
**6** times against **4** of `.error`. Moving success off green is therefore a dozen-site edit and a
grep, not an enum edit — and none of those sites is visible to a gate. `no_color_literal_test`
scans for `Color(0x` and `Colors.`, so a named token is invisible to it by construction;
`verdict_is_not_a_colour_test` only fires on a file naming both `Verdict.correct|wrong` and
`BrandColorRole.success|error`, so the keypad case (which names `KeyRole`) is out of its scope.
The role layer is advisory precisely where it matters most.

**Direction.** Give `BrandColorRole` the arms the design already names — an operator fill and a
quiet fill are two lines — so a call site that wants a role can ask for one; then the remaining
`BrandColors.` reaches for state are a reviewable list rather than the norm. If the enum is going
to keep serving three clients, splitting the state arms into their own type is what would let a gate
say "a widget may not name a state hue" without also banning `BrandColors.ink` for text.

---

### 3. Three widgets in one directory each re-declare the candy surface

**Principle:** SRP. "What a surface looks like" — ink border, hard shadow, radius, padding, an
optional height floor — has six owners in `app/lib`, five of them inside `design/`.

`app/lib/design/widgets/candy_surface.dart:147-161`,
`app/lib/design/widgets/pressable_surface.dart:113-131` and
`app/lib/design/widgets/stat_tile.dart:88-103` each build the same `BoxDecoration` by hand;
`stat_pill.dart`, `speech_bubble.dart` and `brand/app_icon.dart` add three more `blurRadius: 0`
sites (7 in `app/lib` in total, 6 of them under `design/`). `CandySurface`'s own doc comment at
lines 9-11 claims that "routing every surface through this widget is what makes that checkable",
and five siblings in its own directory do not route through it.

**The cost is maintenance, not correctness, and the divergence has already happened.** The no-blur
invariant is separately guarded — `no_blurred_shadow_test.dart` walks every registered screen — so
nothing here can ship a blur. What has drifted is capability: `CandySurface` grew `borderColor` and
`borderDash` when the verdict ring needed a dashed outline, while `PressableSurface:118` hard-codes
`BrandColors.ink` and has no dash at all. BRD-1's shape channel on a *pressable* control — a dashed
retry chip, a dashed key — therefore means writing the dashed-border plumbing a second time, in a
second file, and keeping the two in step afterwards.

**Direction.** `PressableSurface` and `StatTile` compose a `CandySurface` for their decoration
instead of restating it; the press travel, the gesture and the 48 px hit box stay where they are.

---

### 4. One design fact, two tokens, and the tested one is dead

**Principle:** SRP, smallest possible instance. `BrandColors.hairline` (`brand_colors.dart:72`) and
`BrandColors.gridHairline` (`brand_colors.dart:64`) are both `Color(0x2E1C1A2E)` — byte-identical —
and their doc comments describe them as different things. `hairline` has **zero** production
callers; both board surfaces (`puzzle_board_view.dart:289` and `reference_card.dart:229`) draw
`gridHairline`.

**The cost.** `app/test/design/tokens/brand_colors_test.dart:61-78`, the test named *"the board
hairline and the card rule are two tokens, not one alpha"*, asserts against `hairline`. Change the
colour the board actually draws with and that test stays green — the gate reads the copy nobody
uses.

**Direction.** Delete one of the two and point the test at the survivor.

**Resolved (2026-08-29), as directed.** `hairline` is deleted and the test reads `gridHairline`.
The cost was measured rather than inferred first: with the old test in place, dropping the board's
own alpha to the card rule's `0x29` left all 3358 tests green, and the same mutation fails that
test by name now.

---

## What was checked and found clean

Coverage, so the next reader knows where this audit looked rather than guessing.

- **`design/brand/` is the reference spec/adapter split and stays that way.** `brand_shapes.dart`
  is a sealed `BrandMark` hierarchy of pure value types, `aki_spec.dart` is coordinates, and
  `brand_drawing_painter.dart:34-47` walks the marks and holds no geometry. Its exhaustive switch
  over the sealed type is the language's answer, not an OCP violation.
- **`design/math/` is the same shape and is exemplary.** `MathNode.layout` takes an injected
  `GlyphMeasure` (`math_node.dart:37`) so the pure module never needs a font, and `MathView` owns
  the `TextPainter` and the `MathFace → BrandFonts` mapping. `MathTone` having one member is
  already accounted for in its own doc comment and by PROC-11.
- **`design/math/` and `design/puzzle/` do not know about each other**, in either direction —
  verified against the module's full internal import graph, not by absence of a grep hit.
- **The icon parser and the icon data are coupled in one direction only.** `svg_path.dart` names no
  glyph, no icon and no brand type; `icon_paths.dart:26` imports it. Adding a glyph touches
  `brand_glyph.dart` (the name) and `icon_paths.dart` (the geometry) and **never the parser** —
  which was the question, and the answer is clean. The `iconPaths[glyph]!` at `brand_icon.dart:46`
  is a map lookup rather than a compiler-checked switch, but the existing rule covers this:
  `app/test/design/icons/spec/icon_paths_test.dart:17` asserts the map is total over
  `BrandGlyph.values` and reports the count.
- **The `nav_glyph_spec.dart` fork CLAUDE.md still names is gone.** The file does not exist; all
  four bottom-bar marks are transcribed at `icon_paths.dart:161-191` and `brand_glyph.dart:41-47`
  records the retirement. CLAUDE.md's "still forked and still counted" line is stale.
- **`design/tokens/` is genuinely the only home of a colour literal**, enforced by
  `no_color_literal_test.dart`. Finding 2 is not about literals escaping; it is about the *role*
  layer above them being bypassable.
- **The pure boundary holds across every `design/**/spec/` file.** Run in this session,
  `pure_boundary_test.dart` reports `design/**/spec/ → 22 files` and no violation; CLAUDE.md's
  layout note still says 14, which is a count to reconcile in a change that may edit it.
  The four pure specs that need a colour — `day_mark_visual`, `nav_tab_visual`,
  `puzzle_cell_visual`, `term_visual` — each import
  `tokens/brand_colors.dart` directly rather than the barrel, and each says in a comment why —
  exactly the discipline the gate needs, since the gate catches the mistake but cannot explain it.

## Candidates discarded as taste

Six, listed so the absence is a decision rather than an oversight:

1. `BrandDrawingPainter._paintShape/_paintRect/_paintOval` hard-code `BrandColors.ink` for every
   outline — one decision in an adapter, but it is a brand invariant with no plausible second
   value, so the cost is zero.
2. `PressableSurface.outlined` and `CandySurface.clip` as booleans — FUN-2 territory, but these are
   properties of a surface, not selectors between two behaviours, and the project already has the
   rule.
3. `IconSpec.paths` (`icon_paths.dart:64`) re-parses every `d` string on every `paint` — a
   performance question, not a design one.
4. Long `paint` methods in the painters — `dart_code_linter` gates function length at thresholds set
   at what the code does today, and CLAUDE.md says explicitly that a long `paint` is idiomatic when
   the decisions it paints live in the spec.
5. Exhaustive switches over sealed hierarchies (`BrandMark`, `PathStep`, `KeyFace`, `MathNode`) — a
   new variant *should* break every switch.
6. `theme.dart` importing the whole `tokens.dart` barrel — it is a Flutter adapter, the barrel is
   what it is for, and the pure gate is what keeps the barrel out of the specs.
