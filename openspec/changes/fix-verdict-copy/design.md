# Design

## D1 — The copy is a spec, not a screen's business

`verdict_copy.dart` sits beside `verdict.dart` in the pure spec folder, so both screens read the
same two strings and a test can compare them without pumping anything.

That is what makes the failure impossible rather than unlikely. The legend and the verdict
screen were each internally consistent and disagreed with one another, which no test could see
while the strings were literals in two widgets.

## D2 — The caption describes the outline, not the colour

BRD-1 says success and error must be distinguishable by shape. The legend exists to *teach* that
shape, so a caption naming the hue would be the one sentence on the screen that undoes the
invariant. `línea continua` and `línea punteada` are the two words a player needs, and the test
checks each against the outline its verdict actually declares — not merely that the sentences
differ.

## D3 — "Casi" rather than a word for failure

`req-diagnosis-copy` already forbids "incorrecto", "error", "fallaste" and "mal" in the rendered
tree. *Casi* — *almost* — says something about the attempt without saying anything about the
player, and it is the word `04 Error` was already using.

## D4 — Dropping "Mira cómo va."

It was a promise the screen could not keep when it was written: there was nothing to look at.
Now there is — the diagnosis steps sit directly beneath the headline and say what to try. Two
sentences where the second announces the third is one too many.
