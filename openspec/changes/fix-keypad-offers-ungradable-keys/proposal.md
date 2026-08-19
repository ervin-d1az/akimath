# A keypad that only offers answers the game can accept

## Why

Found by running the round on the simulator and reading the pad against the grader.

**Two of its sixteen keys guarantee a wrong verdict.** `ANSWER_SHAPES` is frozen at `integer`
and `fraction`; neither admits a decimal point or a power. `canonicalise('3,5')` and
`canonicalise('5²')` both come back `non_numeric`. So the decimal comma and the square key
cannot appear in *any* answer the grader accepts — pressing either loses the item, whatever it
had asked, and nothing on the screen says so.

**And the square key reads as a digit.** The code drew a bare `²`; in the brand's numeral face
that sits in the fourth column looking like another `2`, one row above the real one. The design
labels it `x²` — the `x` is what says "this does something to your number" rather than "this is
a number".

**And the operator strip is in the wrong order.** `TecladoReactivo` runs `a/b`, `−x`, `x²` top
to bottom; the code ran `−x`, `x²`, `a/b` — which put the only one of the three a player can
currently use at the bottom, under both dead keys.

## What changes

- The decimal and square keys are drawn **unavailable**, the same treatment a puzzle board
  already gives a digit above its ceiling.
- The two operator faces become `−x` and `x²`, as the design draws them.
- The operator strip returns to the design's order.
- A gate: every live key must be able to appear in some answer the grader accepts.

## Out of scope

Growing `ANSWER_SHAPES`. If decimals ever become an answer shape, the key comes back — the gate
is written so that it *fails* in that case, telling whoever grows the contract to take the key
off the list.
