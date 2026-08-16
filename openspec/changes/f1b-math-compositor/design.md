# Design — the math compositor

## D1 · Spike B runs before anything is designed further

R1 says every estimate here is roughly half of the truth, and the reason is visual, not algorithmic:
a 3 px outline on a thin glyph at 76 px is a week of fitting, and nobody schedules it.

**Spike B's exit criterion is already written and is not restated here loosely:** *the ugliest
expression in v1, with the 3 px outline applied, legible, in two days.* Not a clean `1/2` — the
worst case the corpus contains.

The spike is throwaway code and is **not** the implementation. What it produces is a number: whether
the outline fits, and if it does not, which of numeral size, bar thickness or outline width gives
first. **Everything below is provisional on it.** If Spike B fails its criterion, the correct
response is to change the design, not to extend the spike — and that is a conversation, not a task.

## D2 · 76 px, and why the documents disagree

Three source documents state three different largest-numeral sizes:

| Source | Size | What it is |
|---|---|---|
| `0.3` | 84 px | A *teaching* item — it has no dot strip, so it has more room |
| `02`, `0.5` | **76 px** | The two documents that show a real solve screen |
| `Reactivo aritmética` | 70 px | A later revision of the same screen |

**Decision: 76.** It is what both documents showing the actual playing screen use; 84 buys its size
with space no real item has, and 70 is one revision of one screen.

**The compositor takes the size as a parameter**, so this fixes a default and not a capability. That
is what makes it cheap to revisit after Spike B.

## D3 · Metrics are injected, which is what makes the layout pure

Fraction geometry hangs off the font's x-height, and reading x-height means reading a font — IO. So
the module does not read it. The caller passes it:

```
Darumadrop   OS/2.sxHeight = 435/1000
Plus Jakarta OS/2.sxHeight = 536/1000
```

The adapter resolves the real metrics; the spec receives numbers. This is the whole PURE-1 split, and
it is what makes `math_node_test.dart` run with no fake canvas and no golden image — the test passes
literal metrics and asserts on returned boxes.

The bar table the spec asserts:

| Numeral | Bar thickness | Bar minimum width |
|---|---|---|
| 76 | 6 | 58 |
| 46 | 4 | 36 |
| 22 | 3 | 26 |

Stated as three concrete rows rather than as a formula on purpose. A formula asserted against itself
cannot go red; three measured pairs can.

## D4 · Operator styling is per-token (D7)

The sources contradict each other outright. Deck slide 04 says operators are *always* Plus Jakarta;
every phone mock breaks that rule; and the two screen documents disagree with **each other** about
`=` — Darumadrop in `02 Reto activo`, Plus Jakarta 800 at 42 px in `Reactivo aritmética`. Under the
plan's precedence rule the deck ranks last.

**Making the face a property of the token defuses the conflict at the API instead of adjudicating
it.** `OperatorNode(face:, tone:)` lets a screen say what it draws, and the default — operators
Darumadrop, `=` Plus Jakarta 800 — encodes the majority reading without forbidding the minority one.

A global setting would have forced a choice between two documents that are both authoritative for
their own screen.

## D5 · `EsMxNumber`, not `NumberFormat`

`NumberFormat` is `intl`'s class name. `intl` is a plausible future dependency in a Spanish-language
app, and a collision that only appears the day someone adds a package is exactly the kind of trap
NAM-1 exists to prevent.

Home is `design/math/spec/`. **Recorded smell:** `settings` will import `design/math/spec/` to render
`19:30`, which reads oddly — a settings screen reaching into the math layer. If it grates, the module
moves; nothing about a caller's semantics changes when it does.

**U+202F for thousands, not U+0020** (D8). Verified against the source: `1 230` uses a plain ASCII
space, which can wrap to `1` / `230` inside a 48 px pill at a larger text scale — and the app is
already gated at `textScaler` 1.3. es-MX convention allows either form; only the no-break one is
safe.

**U+2212 for minus, never U+002D.** `deltaParts` returns the sign and the digits as separate runs
precisely so that no call site ever concatenates a hyphen by hand. The requirement is asserted across
every entry point, not just the delta one, because one unguarded path is all it takes.

## D6 · `MathLayout` is deferred, and the deferral is the design

The inventory names a general box-layout engine with arbitrary nesting. **It is not built here.**

No document in the entire corpus draws a radical, a real superscript, or a fraction nested more than
one level. `x²` is a character append. Building a general engine for a corpus that needs a stacked
fraction and nothing else is speculative generality, and it is the single largest way this change
could overrun the estimate R1 already warns about.

`MathNode` handles nesting because the spec asserts a fraction inside a fraction — that much is real.
Beyond it, the names stay in the inventory and the capability is **Spike B's exit criterion to
earn**. Reversible in one move if the spike says otherwise.

## D7 · No solidus, enforced by absence

`req-fraction-stacked` has two scenarios and the second is the one that matters: the API exposes no
inline variant *to call*. A rule that says "do not render `1/2` inline" is a rule someone breaks
under deadline; an API with no such parameter is not.

This mirrors how `packages/contract` made the answer-never-travels invariant true — the sync endpoint
does not accept an `ok` field, so the invariant holds by construction rather than by discipline.

## Alternatives rejected

- **A LaTeX renderer.** Forbidden by `CLAUDE.md`'s Never list, and correctly: every option pulls a
  parser and a font stack, none matches the brand's glyphs, and the audience constraint makes a
  large third-party surface a liability rather than a convenience.
- **Flutter's `RichText` with baseline offsets.** It cannot stack a fraction bar with the geometry the
  design specifies, and the moment it half-works the layout decisions scatter across widget code
  where no pure test can reach them.
- **Reading font metrics inside the spec module.** Faster to write, and it puts a file read inside the
  one module whose whole value is that it needs no fakes. Rejected on PURE-1.
- **A golden-image test instead of box assertions.** Goldens go red on a font bump and tell you
  nothing about which number moved. The boxes are asserted numerically; goldens, if they arrive, are
  Tier 1b evidence and not the specification.
