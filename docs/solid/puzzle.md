# `app/lib/features/puzzle/` — a design audit

Read against `main` at `653a17b`. Ten files, 1 809 lines: four pure policies and six widgets.
Audited against `CLAUDE.md`, `.claude/conventions/craftsmanship.md`, SOLID, Martin's component
principles, Beck/Fowler's simple design and Ousterhout.

## Verdict

This module is in good shape. The pure/adapter split is real rather than nominal — a tap, a digit,
a claimed word and a pause summary are all decided in `policy/` and tested with no widget pumped —
the sealed model has already paid off one documented LSP debt, and the two screens carry more
recorded rationale per line than anything else in `features/`. **The single most expensive thing in
it is that `PuzzleScreen` reconstructs which format it is drawing from four wildcard `switch` arms
and one empty-list test, so the shape that let `is! KenKenPuzzle` hide four formats behind a green
suite still exists here — inverted.** Adding a sixth board format breaks three switches in this
repository and none of the two that decide what the board shows: the compiler will make you name
the format and draw its diagrams, and will say nothing at all about the fact that its constraints
are invisible. Everything else below is cheaper than that, and two of the items are gaps in the
evidence rather than in the code.

## Findings, most expensive first

### 1. The board's format is inferred from wildcards and empty lists, not carried by the type — OCP

`app/lib/features/puzzle/ui/puzzle_screen.dart:171-186` builds `PuzzleBoardView` from four
`switch` expressions, each ending in `_ => const <…>[]`:

- `cages:` `CagedPuzzle` → its cages, otherwise empty
- `rowTargets:` / `columnTargets:` `MagicSquarePuzzle` → its targets, otherwise empty
- `runs:` `KakuroPuzzle` → its runs, otherwise empty

`app/lib/features/puzzle/ui/puzzle_board_view.dart:53` then decides whether the board draws a
target margin at all by asking `rowTargets.isEmpty && columnTargets.isEmpty`. Format identity is
reconstructed downstream from the emptiness of four lists.

A wildcard arm is not an exhaustive switch, and this is the one place in the module where the
language is switched off. Contrast: `puzzleFormatName`
(`app/lib/features/puzzle/policy/reference_card.dart:206`), `_diagramsFor`
(`.../reference_card.dart:159`) and `puzzleName` (`app/lib/features/home/policy/puzzle_menu.dart:12`)
all enumerate leaf types and go red the moment a sixth format lands.
`app/lib/features/home/ui/home_route.dart:695-711` switches `WordSearchPuzzle()` against
`BoardPuzzle()`, so a new board subtype is routed to `PuzzleScreen` and *opens*.

**Cost.** A sixth board format compiles once you have named it and given it three diagrams, opens
from the home, passes `home_route_test.dart`'s *5 shipped → 5 kinds reachable* gate — it opens its
screen and comes back — and draws a grid with none of its constraints on it. That is exactly the
class of defect the reachability gate was written for after `pack.puzzles.first` sat behind
`is! KenKenPuzzle`: the brief asks whether that shape still exists here, and the answer is yes with
the sign flipped. It is not a type test standing in for a decision any more; it is *data emptiness*
standing in for one, which is harder to grep for. The unknown unknown is precise: nothing in
`PuzzleScreen` tells the next author that adding a board kind means editing a constructor argument
list in a second file.

And the cost is not only hypothetical. *"The formats are frozen, so there is no sixth"* is the
obvious objection, and it answers half of it: a sixth format also costs a `packages/contract`
change, so it is not a Tuesday afternoon's work. What the same structure costs **today** is
cognitive load on every change to how an existing board draws — the wiring for a Kakuro's runs and
a magic square's targets lives in a constructor argument list in `puzzle_screen.dart`, one file
away from the `PuzzleBoardView` that consumes it and two from the model that owns it, and a reader
changing any of the three has to hold all four wildcard arms in their head to know what else looks
at them.

**Direction.** The seam is a pure function in `features/puzzle/policy/` — one exhaustive `switch`
over `BoardPuzzle` returning a small value type (`cages`, `rowTargets`, `columnTargets`, `runs`, or
whatever the sixth format adds), consumed by `PuzzleBoardView`. The decision moves under
`pure_boundary_test`, `PuzzleScreen` goes back to composing, and silent degradation becomes a
compile error. The model stays data, which is the split `content/model/puzzle.dart` already argues
for.

**Addressed 2026-08-29, `fix-the-puzzle-gates-can-fail`.** `features/puzzle/policy/board_constraints.dart`
is that function, switched over the four leaves rather than over `CagedPuzzle`, returning a
`BoardConstraints` with three named constructors and **no empty one**; `PuzzleBoardView` takes it as
one argument and asks it `hasLineTargets` instead of asking two lists whether they are empty.
Measured rather than asserted: a sixth `BoardPuzzle` leaf produced **four** non-exhaustive-switch
errors before the change and **five** after, the fifth at `board_constraints.dart`. One limit stays
and is written into the type's doc comment — a sixth format bringing a *new kind* of constraint gets
an arm and a field, and the view could still ignore that field silently. The sweep in
`board_constraints_test.dart` covers the other half: no format shows nothing.

### 2. The two puzzle screens duplicate a shell that was planned to be extracted, and it has already drifted — CCP

`app/lib/features/puzzle/ui/puzzle_screen.dart:128-166` and
`app/lib/features/puzzle/ui/word_search_screen.dart:86-151` are the same widget tree: cream
`Scaffold`, `SafeArea`, `EdgeInsets.symmetric(horizontal: space4, vertical: space3)`, a stretched
`Column`, `_header()`, `space3`, `Expanded(_rulesOpen ? ReferenceCard : Center(child))`, `space3`,
and a footer hidden while the sheet is open. `_header()`
(`puzzle_screen.dart:191-244` / `word_search_screen.dart:119-151`) is the same row of a labelled
`Salir` tile, an ellipsised `puzzleFormatName` inside an `Expanded`, and a `Cómo se juega` toggle —
differing only in the pause control the sopa does not have.

This is not a DRY complaint about two files that happen to look alike; the copies demonstrably
change together, and `openspec/changes/f6-word-search/design.md` D1 said so in advance: *"the shared
parts — the header, the rules toggle, the way out — are small enough to extract."* They were not
extracted, and the record of what that cost is in one pull request, `d95941d`:

- *"The sopa de letras is not wired to the card yet and still shows the old inline list"* — the
  reference card landed on one screen and then had to land again on the other.
- *"The sopa already hid its word list for the same reason; the two screens agree now"* — the live
  keypad under the open sheet was a real defect on `PuzzleScreen`, found because the other copy
  had it right.
- Pause landed in that same pull request on `PuzzleScreen` alone. Today a player can pause a
  Kakuro and cannot pause a sopa, and no document in the repository decides that.

**Cost.** Change amplification with a measured history: every change to the puzzle chrome is two
edits, and the second one is discovered rather than required. There is no type expressing *a puzzle
session screen*, so nothing holds `{puzzle, onClose, onSolved, onPractised}` in step between the
two — which is why the fourth control drifted rather than failing to compile.

**Direction.** The seam is a `PuzzleChrome` widget taking a title, a rules `Widget`, an optional
pause callback and a footer slot — the chrome, not the format. It costs one file and deletes the
question "did I change both". Note explicitly what this is *not*: it is not a reason to merge the
two screens. See the note on the four-share-one-screen decision below.

### 3. An assertion in `puzzle_screen_test.dart` cannot fail — PROC-11

`app/test/features/puzzle/ui/puzzle_screen_test.dart:38-56` defines
`Future<int> _pump(...)` which declares `int solved = 0`, wires `onSolved: () => solved++`, pumps,
and returns `solved` — an `int` snapshot taken before any interaction, always `0`. At line 357-368
the test *"and a key pressed while it is open does nothing, because there is no key"* writes
`int solved = 0; solved = await _pump(tester);` and finishes with `expect(solved, 0)`. The callback
increments `_pump`'s local; the test's variable is a copy of zero. The assertion is `expect(0, 0)`,
the local initialiser on the line above is dead, and the test never presses a key.

The right pattern is in the same directory:
`app/test/features/puzzle/ui/word_search_screen_test.dart:45-61` returns
`int Function()` — a closure over the counter — precisely so the count can be read after the fact.

**Cost.** The hazard being claimed is real and specific: `_apply` (`puzzle_screen.dart:80-96`)
would fire `onPractised` and `onSolved` from behind the reference card if a key reached it. The
test's sibling assertion — no `KeypadKeyView` exists — covers today's implementation. What the
vacuous line does is advertise the *behavioural* half as covered, so the day someone keeps the pad
mounted and merely disables it, this test stays green and the name still says it was checked. Two
of PROC-11's five recorded shapes in one test: an assertion that holds for any input, and a name
that claims more than the body checks.

**Direction.** Return `int Function()` from `_pump` the way the sopa's test does, then press a
digit with the sheet open and assert the counters did not move. The falsification is stated in
PROC-5 tier 1b: remove the `if (!_rulesOpen)` guard around the `Keypad` and watch that specific
test go red.

**Addressed 2026-08-29, `fix-the-puzzle-gates-can-fail`, with one claim above corrected.** The
Cost paragraph's *"the day someone keeps the pad mounted and merely disables it, this test stays
green"* is **false**: a disabled key is still a `KeypadKeyView`, so the sibling
`findsNothing` assertion goes red for a mounted pad whatever state its keys are in — which
*"a 3x3 offers three digits"* proves by reading `.available` off one. The Direction is
unachievable for the same reason the case's name was a lie: with nothing mounted there is nothing
to tap, and a tap-if-present helper would be PROC-11's first bullet in a new shape. What landed
instead: `_pump` returns `int Function()`, the two `finishing` cases that had hand-rolled a pump
apiece because it could not now route through it, and the case is renamed *"and with a cell
selected, opening it leaves no key at all"* — what its body checks. The guard-removal
falsification was run and that case is one of the two named in the red.

### 4. The reference sheet's line-to-picture pairing is a cross-stack positional contract with no seam

`app/lib/features/puzzle/policy/reference_card.dart:188-197` pairs `puzzle.referenceSheet[line]`
with `_diagramsFor(puzzle)[line]` **by index**, and the file says so
(`.../reference_card.dart:11-14`). The pictures assume the order *objective, vocabulary,
constraints*; the words that order is true of are produced by `referenceSheetFor` in
`packages/core/src/adapters/build-puzzles.ts:116-160` and shipped inside
`app/assets/packs/starter.json`.

Nothing connects the two. `packages/core/test/reference-sheet.test.ts` holds the generator and the
shipped pack to the same *strings*, which is what stops the copy drifting — it says nothing about
which rule sits at which index. On the Dart side,
`app/test/features/puzzle/policy/reference_card_test.dart:101-129` checks that every format has a
diagram for every line, which is the PROC-10 half; no test can check that diagram *k* is about rule
*k*, because the policy has no idea what rule *k* says.

**Cost.** A copy editor reordering two lines in a TypeScript file puts the dashed-cage picture next
to *"fill every cell"* on a player's screen, and both suites stay green in both languages. This is
a Feathers case in its pure form: **there is no seam** — no point at which the pairing can be made
wrong-on-purpose and observed.

**Direction.** The cheapest honest seam is a role per line in the pack — `objective`,
`vocabulary`, `constraint` — which is text, not geometry, so it does not violate the reason
diagrams stay out of the pack. It is not free: the pack schema is frozen and this is a
`packages/contract` change with an `allow-breaking-contract` conversation attached. The cheaper
half-measure, worth doing either way, is a golden test that pins the *first word* of each shipped
sheet line beside the diagram the Dart side pairs it with, so the pairing becomes falsifiable in
one language instead of zero.

### 5. A format's player-facing name has two owners in two components, and they already differ — CCP

`puzzleFormatName` (`app/lib/features/puzzle/policy/reference_card.dart:206`) names each format for
the board header, the sopa's header and the reference card's title. `puzzleName`
(`app/lib/features/home/policy/puzzle_menu.dart:12`) names each format for the home's cards and,
through `home_route.dart:750`, for `PuzzleSolvedScreen`. Killer is `SUMAS` in the first and
`Suma con jaulas` in the second, and the two are not a case transform of each other.

Two facts decide this, and both are no:

- **Nothing holds the spellings in step.**
  `app/test/features/puzzle/policy/reference_card_test.dart:139-160` pins that
  `puzzleFormatName`'s five results are distinct; `app/test/features/home/policy/puzzle_menu_test.dart:83-102`
  pins `puzzleName`'s five exact strings. Neither crosses. Both switches are exhaustive over the
  sealed type, so *adding* a format forces both authors to act and *renaming* one forces neither.
- **Nothing records that they are deliberately two.** A grep across `openspec/changes/` and `docs/`
  for `puzzleFormatName`, `puzzleName` and `SUMAS` returns nothing, and `puzzleFormatName`'s own
  doc comment makes the don't-write-it-three-times argument about the three surfaces inside
  `features/puzzle/` while never mentioning that a second function serves two more — including
  `PuzzleSolvedScreen`, which prints the home's spelling for the board whose header, one tap
  earlier, printed the policy's.

**Cost.** One ordinary copy edit — renaming a format for players — produces two visible spellings
with every suite green, and a newcomer editing either function cannot discover from the file in
front of them that a second owner exists. Adjacent in cost to finding 4: a likelier trigger, milder
harm. It is a component-cohesion question rather than an SRP one — the same actor, whoever writes
player-facing es-MX copy, has to find two files in two features to make one decision.

**Direction.** One function, in one place, returning both spellings a format needs — a small value
type (`card`, `eyebrow`) or two functions beside each other in `features/puzzle/policy/`, with the
home importing it. If the design genuinely draws two names, that is still where the pair belongs,
and the record of *why* they differ goes with it. This audit could not open
`AkiMath Reactivos y Puzzles.dc.html` to check which case it is; the finding stands either way,
because what is missing is the link and the record, not a particular spelling.

### 6. `cageOutline` returns the wrong shape for both of its callers, and the module works around it twice — the seam with `design/puzzle/spec/`

`app/lib/design/puzzle/spec/board_geometry.dart:89-109` returns `List<CageEdges>`. Both callers
want a lookup by cell, and each invents a different workaround:

- `app/lib/features/puzzle/ui/puzzle_board_view.dart:224-241` — `_edgesFor` rebuilds the cage's
  `Set<GridCell>` and re-runs `cageOutline` **for every cell of the board**, then scans the result
  linearly for one cell; `_isAnchor` re-runs `cageLabelAnchor` per cell the same way. On a 6×6
  KenKen that is ~36 rebuilds and ~36 reductions per frame, and the whole board rebuilds on every
  keystroke.
- `app/lib/features/puzzle/ui/reference_card.dart:151-152, 186-193` — computes the outline and the
  anchor **once** and then scans linearly per cell in `_edgesAt`.

The same missing abstraction, solved two ways, in one directory.

**Cost.** Two copies of a per-cell lookup that change together: any change to how an outline is
represented is an edit in both, and the two callers already disagree about where the work belongs,
so a reader cannot tell which is the intended pattern. This is the seam question the puzzle audit
and the design audit can each half-see — the defect is not in either file, it is in the shape the
boundary hands across.

**Direction.** Have the spec answer the question its callers actually ask:
`Map<GridCell, CageEdges> cageOutline(...)`, or a `boardOutline(Iterable<Set<GridCell>>)` returning
one map for a whole board. Both loops disappear, `design/puzzle/spec/` stays pure and stays tested
without a widget, and the recomputation goes with them. *(Observation, not part of the finding: the
`Cell` ↔ `GridCell` conversion the feature performs at four sites is deliberate and documented at
`board_geometry.dart:16-18` — geometry does not know about packs. A map-shaped return would absorb
most of the conversion noise as a side effect.)*

### 7. The store gate forbids two class names, and its test claims more than that — PROC-11

`app/test/architecture/no_store_in_a_puzzle_screen_test.dart` is a good gate: it unit-tests its own
scanner, excludes the round screen by root, and reports the file count so it cannot go vacuously
green (PROC-10). What it actually forbids is two identifiers — `storePatterns` in
`app/test/architecture/literal_scan.dart:301-307` lists `DayLogStore` and `SeriesCursorStore`. The
test that runs it over the tree is named *"no puzzle screen holds a store today"*.

**Cost.** The invariant the module is built on — *the screen reports, the route records*, stated in
`puzzle_screen.dart:59-61`, `word_search_screen.dart:42-43` and design D3 — is enforced against the
two store classes that existed when it was written. A `PuzzleProgressStore`, a
`SharedPreferencesAsync` handle, or any future store walks straight past it with the gate reporting
success, and the test's name retires the question for whoever reads it next. Lower cost than the
findings above because the shape is right and the fix is one line; listed because a gate that is
narrower than its name is the failure this repository has written down five times.

**Direction.** Either widen the pattern to `[A-Z]\w*Store` plus `SharedPreferences`, or rename the
test to what it checks. The first is better and costs one regex.

### 8. `PuzzleScreen` is the third place that knows the puzzle pad's digits are 1–9

`app/lib/features/puzzle/ui/puzzle_screen.dart:103-106` builds the unavailable-key set with
`for (int digit = widget.puzzle.board.highestValue + 1; digit <= 9; digit++)`. The same fact is
`KeypadLayout.puzzle`'s nine `TextFace` keys
(`app/lib/design/widgets/spec/keypad_layout.dart:194-216`) and `padHighestDigit`
(`app/lib/content/model/puzzle_reader.dart:227-236`), where it is stated beautifully — *"expressed
as a property of the input surface rather than as 'magic squares must be 3×3', so the rule keeps
working if the pad ever grows"*. The screen's bare `9` is the copy that does not keep working: grow
the pad and a 3×3 KenKen would offer 10, 11 and 12 as live keys.

Related, same line of sight: `_onKey` (`puzzle_screen.dart:108-117`) identifies the erase key by
`key.id == 'backspace'` when `KeypadKey` already carries `KeyRole.erase`. Branching on a string
where a closed enum exists is the shape FUN-2 argues against; the string is load-bearing only
because a test happens to press the same literal.

**Cost.** Small today and entirely latent — nothing is wrong on screen. It is here because the
brief asks about `highestValue` reaching from the board model into the keypad's layout, and the
answer is that the *reach* is right (one declared domain, one source, and the reader refuses a
board the pad cannot express) while the *translation* from that domain to key ids is an undeclared
decision living in a `State` getter, where it can only be tested by pumping a screen.

**Direction.** Derive the set from `KeypadLayout.puzzle.keys` — filter on `emits` parsing above
`highestValue` — or move the translation to `features/puzzle/policy/` where `pure_boundary_test`
covers it and a unit test can read it. Switch `_onKey` on `key.role`.

### 9. The class four formats share is documented as one of them — CMT-2

`app/lib/features/puzzle/ui/puzzle_screen.dart:17` opens the doc comment with *"A KenKen,
played."* The field below it is correct (`:39-41`, *"Any puzzle played on the shared square"*), and
the class draws KenKen, Killer, the magic square and Kakuro.

**Cost.** Discoverability only, but it is the summary line — the one line an IDE hover and a `grep`
for "where is a Kakuro drawn" both show. A newcomer looking for the magic square's screen has to
read past a sentence saying this is not it. Cheapest finding in the document and a one-word fix.

## What this module gets right, and why

**It paid an LSP debt in the type system and wrote down that it did.**
`app/lib/content/model/puzzle.dart:131-141`: *"`board` used to live on `Puzzle` with a word search
throwing from it — a supertype promising something one subtype cannot give, which the type system is
perfectly able to express instead."* That is the textbook violation the canon says to hunt, found
and removed before this audit ran, and `PuzzleScreen.puzzle` is typed `BoardPuzzle` so the mistake
cannot come back through the door it left by. `CagedPuzzle` is the same move one level down: the
screen asks for the capability it needs, not the concrete kind. Copy this.

**An invariant made structural instead of asserted.** `PauseSummary`
(`app/lib/features/puzzle/policy/pause.dart:21-42`) has four fields and nowhere to put a duration,
and the library comment says that is the whole shape of the type rather than an omission. *Nothing
watches you while you work* is therefore true of `3.6 Pausa` by construction — the screen cannot
print a clock it was never handed. Same family as the sync endpoint refusing an `ok` field.

**The pictures and the thing they teach share one source.** `resolvePuzzleCell` is used by both the
real board (`puzzle_board_view.dart:273`) and the reference diagram (`reference_card.dart:220`), so
a blocked cell in the miniature is the same colour as a blocked cell on the board. One
`ReferenceDiagram` value type configured nine ways rather than nine painters
(`policy/reference_card.dart:19-28`), and `allReferenceDiagrams` exists so a diagram no format
reaches is still swept (PROC-10).

**Deep policies, thin adapters.** `PuzzleEntry` is 98 lines holding every rule about what a tap and
a digit mean, with a simple four-method interface, and its 238-line test pumps nothing.
`WordSearchProgress.claim` reads a trace both ways in nine lines. Ousterhout's deep module, and the
reason the screens can be as declarative as they are.

**Test comments that explain why a finder is scoped.** `puzzle_screen_test.dart:75-99` — *"The
pad's own faces are 1 to 9, so a bare `find.text('2')` matches a key and says nothing about the
grid… the first draft of this file was green for the wrong reason before that."* And
`screen_registry.dart:720-726`, which records that the `puzzle · kenken` label prefix is
load-bearing because `quiet_while_you_solve_test` selects on it, so a rename would drop a screen
out of two gates silently. Both are rationale a name cannot carry.

**The reachability gate asks the right question.**
`app/test/features/home/ui/home_route_test.dart:233-297` opens every format from the home for real
and comes back, reports a count and fails at zero — *"not 'does the screen render' but 'can a
player get to it'"*. Finding 1 is about the one question it cannot ask, not a complaint about the
gate.

## The four-share-one-screen decision

**The split is right, and the sopa is not being taxed.** Judge it by what the fifth format pays and
what the four gain. `PuzzleScreen` composes a board and a keypad and holds **no** per-format
branching in its chrome, its entry handling, its pause or its rules sheet — the only place a format
is named inside it is the `_board()` argument list, which is finding 1 and is a leak *out* of the
model, not a cost of sharing. `WordSearchScreen` avoids a keypad it has no use for, a `PuzzleEntry`
that cannot represent a claimed word, and a `PuzzleBoard` it does not have; D1's *"bending it to
draw letters with no pad would make every future change to either one a change to a single widget"*
holds, and `letterAt` resolving a drag for the whole grid rather than a detector per cell is
correct for the reason `letter_grid_geometry.dart:8-11` gives — a pan is delivered only to the
widget it went down on.

So: **good cohesion, one leak, and one unpaid promise.** The four share a screen because they share
a *substrate* (a square board and a digit domain), which is a real thing named in the model, not a
convenience. What is wrong is not the sharing but the two places it stops short — the format detail
that leaks into the shared screen as wildcards (finding 1), and the chrome D1 promised to extract
and did not (finding 2). Merging the two screens would be the wrong repair to either. The right
shape is one screen per input modality, one extracted chrome above both, and one exhaustive policy
under `PuzzleScreen`.

`docs/IMPLEMENTATION-PLAN.md:2344` says *"one shell, five renderers"*; the code is two shells and
one renderer configured four ways. The code is closer to right than the plan — but the plan is
where the extraction was promised, and nobody has updated either.

## Coverage

**Read in full:** all ten files in `app/lib/features/puzzle/`;
`app/lib/content/model/puzzle.dart`; `app/lib/design/puzzle/spec/board_geometry.dart` and
`letter_grid_geometry.dart`; `app/lib/features/home/policy/puzzle_menu.dart`;
`app/test/features/puzzle/ui/puzzle_screen_test.dart`;
`app/test/features/puzzle/ui/word_search_screen_test.dart`;
`app/test/architecture/no_store_in_a_puzzle_screen_test.dart`; `CLAUDE.md` and
`.claude/conventions/craftsmanship.md`; `openspec/changes/f6-word-search/design.md`.

**Read in part, by line range or by grep — enough for the claims made about them, not enough to
audit them:** `content/model/puzzle_reader.dart` (the magic-square and Kakuro halves, and
`padHighestDigit`); `home_route.dart:640-760`; `design/widgets/spec/keypad_layout.dart` (the
`puzzle` layout and the file's header); `app/test/features/puzzle/policy/reference_card_test.dart`
(lines 80-170); `app/test/features/puzzle/ui/puzzle_board_view_test.dart` (its group and test
names, not its bodies); `app/test/design/screen_registry.dart` (the puzzle entries);
`app/test/design/quiet_while_you_solve_test.dart` (its prefix list and its PROC-10 guard);
`app/test/features/home/ui/home_route_test.dart` (the reachability gate and the two day-recording
tests); `app/test/architecture/literal_scan.dart` (`storePatterns` and `storeFreeScreenRoots`);
`app/test/features/home/policy/puzzle_menu_test.dart` (the name assertions);
`packages/core/src/adapters/build-puzzles.ts` (`referenceSheetFor`).

**Not opened:** `app/test/features/puzzle/policy/pause_test.dart`, `puzzle_entry_test.dart`,
`word_search_test.dart`; `app/test/features/puzzle/ui/paused_board_test.dart`,
`puzzle_solved_screen_test.dart`, `reference_card_test.dart`;
`app/lib/design/widgets/spec/puzzle_cell_visual.dart` (its call sites and its size, not its body);
`app/test/design/puzzle/spec/*`; `integration_test/puzzle_tour_test.dart`.

**Checked and clean:**

- **ADP.** No cycles. `features/puzzle/` imports `content/model/`, `design/` and itself; the only
  inbound edge in `lib/` is `home_route.dart:25-27`. `design/` imports no feature.
- **LSP.** Hunted specifically, in the sealed pairs, and it is clean — because the debt was already
  paid: `board` no longer sits on `Puzzle` throwing for word search, and the model records the fix.
  No subtype in this module throws where a sibling returns, and no override strengthens a
  precondition.
- **DIP / PURE-1.** All four policies are import-clean and are inside `pure_boundary_test`'s
  `features/*/policy/` root. No screen holds a store or a clock — the route holds both, and both
  screens report through callbacks.
- **`PuzzleBoardView`'s never-draws-the-answer rule.** Swept by
  `puzzle_board_view_test.dart:157-188`, including the entered-value case.
- **The keypad's domain.** `padHighestDigit` in the reader refuses a magic square needing more than
  nine values, so the 6×6-magic-square-is-unplayable hypothesis I went looking for does not exist.

**Deliberately not reported, because a committed gate owns it:** the pure/IO boundary
(`pure_boundary_test`), colour and `Offset(` literals (`no_color_literal_test`,
`no_geometry_literal_test`), the 48 px floor (`touch_target_test`, and
`puzzle_board_view_test.dart:473-499` for a 6×6 specifically), overflow at both viewports
(`screen_overflow_test`), Aki-absence and no-clock on all five boards
(`quiet_while_you_solve_test`), hue-only verdicts, and cyclomatic complexity / nesting / function
length / parameter count (`dart_code_linter`). Long `build` methods and the length of
`word_search_screen.dart` are not findings for that reason.

**Could not judge:**

- **Whether the sopa should have a pause.** No design document in the repository says either way,
  and `3.6 Pausa` is only reachable through the Claude Design MCP, which this run did not open.
  Finding 2 reports the *drift*, not a verdict on the product question.
- **Whether the six unopened puzzle test files bite.** Six of the ten test files under
  `app/test/features/puzzle/` were not opened, so this audit makes no claim about them either way.
  Findings 3 and 7 both come from files read in full; no finding here rests on an unread file, and
  no *absence* of a finding about those six should be read as a clean bill.
- **Which spelling of a format's name the design draws.** Finding 5 stands either way — what is
  missing is the link between the two owners and the record of why they differ — but
  `AkiMath Reactivos y Puzzles.dc.html` would settle whether the difference was intended, and this
  run did not open the `claude_design` MCP.
- **Tier 2.** Nothing here was exercised on a simulator; `integration_test/puzzle_tour_test.dart`
  exists and was read, not run.

**Candidates discarded: eleven.** `pauseSummary` taking both a puzzle and an entry that already
carries the same board (harmless, one call site); `PuzzleEntry.isSolved` being vacuously true for a
board with no open cells (unreachable — no keystroke can fire it, and the reader will not produce
one); `select`'s bounds check running after its membership checks (same result, no cost); the
magic-square-above-nine hypothesis (refuted by `padHighestDigit`); the per-cell recomputation in
`_edgesFor` as a *performance* finding (folded into finding 5, where it is evidence rather than the
point); the `Cell`/`GridCell` duplication (documented decoupling, Observation); the four exhaustive
switches over the sealed hierarchy (idiomatic, and the compiler helping); `_Cell`'s long `build`
(the decisions it paints live in `design/puzzle/spec/` and `puzzle_cell_visual`, which is the
condition under which a long paint is fine); `ReferenceDiagram`'s nine module-level constants
(data, swept by a test); the volume of doc comments (Ousterhout, and this project sides with him);
and `PuzzleScreen` holding four booleans of `State` (`_reported`, `_practised`, `_rulesOpen`,
`_paused` — each latched by a different event, and collapsing them into an enum would model states
that can legitimately co-occur).
